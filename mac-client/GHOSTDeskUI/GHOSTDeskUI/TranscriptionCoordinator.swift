import Foundation
import Combine

final class TranscriptionCoordinator: ObservableObject {
    @Published private(set) var overallPhase: OverlayModel.AudioChannelPhase = .idle

    private let overlay: OverlayModel
    private let systemTranscriber: SpeechTranscriber
    private let microphoneTranscriber: SpeechTranscriber
    private var cancellables: Set<AnyCancellable> = []

    init(overlay: OverlayModel = .shared) {
        self.overlay = overlay
        self.systemTranscriber = SpeechTranscriber(captureMode: .systemAudio)
        self.microphoneTranscriber = SpeechTranscriber(captureMode: .microphone)
        bind(transcriber: systemTranscriber, to: .system)
        bind(transcriber: microphoneTranscriber, to: .microphone)
        updateOverallPhase()
    }

    deinit {
        stopAll()
    }

    var isAnyTranscribing: Bool {
        overlay.anyChannelIsTranscribing
    }

    func startAll() {
        systemTranscriber.start()
        microphoneTranscriber.start()
    }

    func stopAll() {
        systemTranscriber.stop()
        microphoneTranscriber.stop()
    }

    @MainActor func clearLogs(for source: OverlayModel.AudioSourceKind) {
        switch source {
        case .system:
            systemTranscriber.clearLog()
        case .microphone:
            microphoneTranscriber.clearLog()
        }
        overlay.clearTranscription(for: source)
    }

    func transcriptTail(for source: OverlayModel.AudioSourceKind, maxChars: Int = 900) -> String {
        overlay.transcriptTail(for: source, maxChars: maxChars)
    }

    func combinedTranscript(includePartials: Bool = true) -> String {
        overlay.combinedTranscript(includePartials: includePartials)
    }

    private func bind(transcriber: SpeechTranscriber, to source: OverlayModel.AudioSourceKind) {
        transcriber.$transcriptLog
            .receive(on: DispatchQueue.main)
            .sink { [weak self] log in
                self?.overlay.updateTranscriptionState(for: source) { $0.transcriptLog = log }
            }
            .store(in: &cancellables)

        transcriber.$partialText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] partial in
                self?.overlay.updateTranscriptionState(for: source) { $0.partialText = partial }
            }
            .store(in: &cancellables)

        transcriber.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.overlay.updateTranscriptionState(for: source) { $0.lastError = error }
            }
            .store(in: &cancellables)

        transcriber.$isTranscribing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                self?.overlay.updateTranscriptionState(for: source) { $0.isTranscribing = isRunning }
                self?.updateOverallPhase()
            }
            .store(in: &cancellables)

        transcriber.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                guard let self else { return }
                self.overlay.updateTranscriptionState(for: source) { $0.phase = self.mapPhase(phase) }
                self.updateOverallPhase()
            }
            .store(in: &cancellables)
    }

    private func mapPhase(_ phase: SpeechTranscriber.Phase) -> OverlayModel.AudioChannelPhase {
        switch phase {
        case .idle: return .idle
        case .starting: return .starting
        case .running: return .running
        case .stopping: return .stopping
        }
    }

    private func updateOverallPhase() {
        let phases = [systemTranscriber.phase, microphoneTranscriber.phase]
        if phases.contains(.stopping) {
            overallPhase = .stopping
        } else if phases.contains(.starting) {
            overallPhase = .starting
        } else if phases.contains(.running) {
            overallPhase = .running
        } else {
            overallPhase = .idle
        }
    }
}
