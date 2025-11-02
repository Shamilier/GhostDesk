import Foundation
import Combine
import os.log

final class TranscriptionCoordinator: ObservableObject {
    @Published private(set) var overallPhase: OverlayModel.AudioChannelPhase = .idle
    @Published var isMicrophoneArmed = false

    private let overlay: OverlayModel
    private let systemTranscriber: SpeechTranscriber
    private let microphoneTranscriber: SpeechTranscriber
    private let recordingManager = RecordingManager.shared
    private let audioRecorder = AudioRecorder.shared
    private let outbox = OutboxService.shared
    private let logger = Logger(subsystem: "ai.ghost.recorder", category: "TranscriptionCoordinator")

    private var cancellables: Set<AnyCancellable> = []
    private var shouldResetMicrophoneAfterStop = false
    private var activeRecordingId: String?

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

    func startRecording() {
        startLocalRecording()
        systemTranscriber.start()
        if isMicrophoneArmed {
            microphoneTranscriber.start()
        }
    }

    func stopAll() {
        systemTranscriber.stop()
        microphoneTranscriber.stop()
        shouldResetMicrophoneAfterStop = true
        stopLocalRecording()
    }

    func setMicrophoneArmed(_ armed: Bool) {
        guard armed != isMicrophoneArmed else { return }
        isMicrophoneArmed = armed
        alignMicrophoneStateWithDesiredConfiguration()
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
                self.handlePhaseChange(for: source, phase: phase)
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

    private func handlePhaseChange(for source: OverlayModel.AudioSourceKind, phase _: SpeechTranscriber.Phase) {
        if source == .microphone {
            alignMicrophoneStateWithDesiredConfiguration()
        }

        if shouldResetMicrophoneAfterStop,
           systemTranscriber.phase == .idle,
           microphoneTranscriber.phase == .idle {
            shouldResetMicrophoneAfterStop = false
            if isMicrophoneArmed {
                isMicrophoneArmed = false
            }
        }
    }

    private func alignMicrophoneStateWithDesiredConfiguration() {
        let microphonePhase = microphoneTranscriber.phase
        if isMicrophoneArmed {
            guard overallPhase != .idle else { return }
            if microphonePhase == .idle {
                microphoneTranscriber.start()
            }
        } else {
            switch microphonePhase {
            case .running, .starting:
                microphoneTranscriber.stop()
            case .idle, .stopping:
                break
            }
        }
    }
}

// MARK: - Local recording lifecycle

private extension TranscriptionCoordinator {
    func startLocalRecording() {
        guard activeRecordingId == nil else { return }

        do {
            let session = try recordingManager.beginSession()
            do {
                try audioRecorder.start(at: session.fileURL)
                activeRecordingId = session.localId
                logger.log("Recording session started \(session.localId, privacy: .public)")
            } catch {
                try? recordingManager.removeSession(localId: session.localId)
                throw error
            }
        } catch {
            logger.error("Failed to start local recording: \(error.localizedDescription, privacy: .public)")
            activeRecordingId = nil
        }
    }

    func stopLocalRecording() {
        guard let localId = activeRecordingId else { return }
        activeRecordingId = nil

        Task {
            do {
                try await audioRecorder.stop()
                let result = try recordingManager.finalizeSession(localId: localId)
                outbox.enqueue(localId: localId)
                logger.log("Recording session finalized \(localId, privacy: .public) size=\(result.sizeBytes, privacy: .public)")
            } catch {
                logger.error("Failed to finalize recording \(localId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
