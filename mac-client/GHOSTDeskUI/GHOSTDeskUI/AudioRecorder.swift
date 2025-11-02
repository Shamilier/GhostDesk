import Foundation
import AVFoundation
import CoreMedia
import os.log

final class AudioRecorder {
    enum Source {
        case microphone
        case system
    }

    static let shared = AudioRecorder()

    private let engine = AVAudioEngine()
    private let recordingMixer = AVAudioMixerNode()
    private let outputFormat: AVAudioFormat

    private let microphoneSource: SourceContext
    private let systemSource: SourceContext

    private var assetWriter: AVAssetWriter?
    private var assetInput: AVAssetWriterInput?
    private var recordedFrames: AVAudioFramePosition = 0
    private var isRecording = false

    private let stateQueue = DispatchQueue(label: "ai.ghost.audio-recorder.state")
    private let logger = Logger(subsystem: "ai.ghost.recorder", category: "AudioRecorder")

    private init() {
        outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                     sampleRate: 48_000,
                                     channels: 1,
                                     interleaved: false)!

        microphoneSource = SourceContext(name: "microphone", gain: 0.78)
        systemSource = SourceContext(name: "system", gain: 0.78)

        engine.attach(recordingMixer)
        engine.attach(microphoneSource.node)
        engine.attach(systemSource.node)

        engine.connect(microphoneSource.node, to: recordingMixer, format: outputFormat)
        engine.connect(systemSource.node, to: recordingMixer, format: outputFormat)
        engine.connect(recordingMixer, to: engine.mainMixerNode, format: outputFormat)
        engine.mainMixerNode.outputVolume = 0
        recordingMixer.outputVolume = 1

        do {
            try engine.start()
        } catch {
            logger.error("Failed to start AVAudioEngine: \(error.localizedDescription, privacy: .public)")
        }
    }

    func start(at url: URL) throws {
        try stateQueue.sync {
            guard !isRecording else { return }

            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }

            let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
            if writer.canApply(outputSettings: nil, forMediaType: .audio) {
                writer.outputFileTypeProfile = .m4aAudioOnly
            }

            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: outputFormat.sampleRate,
                AVNumberOfChannelsKey: Int(outputFormat.channelCount),
                AVEncoderBitRateKey: 64_000,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
            input.expectsMediaDataInRealTime = true

            guard writer.canAdd(input) else {
                throw NSError(domain: "ai.ghost.recorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add audio input"])
            }
            writer.add(input)

            recordingMixer.removeTap(onBus: 0)
            recordingMixer.installTap(onBus: 0, bufferSize: 2048, format: outputFormat) { [weak self] buffer, _ in
                self?.handleTapBuffer(buffer)
            }

            guard writer.startWriting() else {
                recordingMixer.removeTap(onBus: 0)
                throw writer.error ?? NSError(domain: "ai.ghost.recorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to start writing"])
            }
            writer.startSession(atSourceTime: .zero)

            assetWriter = writer
            assetInput = input
            recordedFrames = 0
            microphoneSource.start()
            systemSource.start()
            isRecording = true
            logger.log("Started recording at \(url.path(percentEncoded: false), privacy: .public)")
        }
    }

    func stop() async throws {
        let writer: AVAssetWriter? = stateQueue.sync {
            guard isRecording else { return nil }
            isRecording = false
            recordingMixer.removeTap(onBus: 0)
            microphoneSource.stop()
            systemSource.stop()
            let currentWriter = assetWriter
            assetInput?.markAsFinished()
            assetWriter = nil
            assetInput = nil
            return currentWriter
        }

        guard let writer else { return }

        try await withCheckedThrowingContinuation { continuation in
            writer.finishWriting {
                if let error = writer.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        microphoneSource.reset()
        systemSource.reset()
        logger.log("Finished recording")
    }

    func append(samples: [Float], sampleRate: Double, from source: Source) {
        guard !samples.isEmpty else { return }
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: sampleRate,
                                   channels: 1,
                                   interleaved: false)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { pointer in
            if let channel = buffer.floatChannelData?[0], let base = pointer.baseAddress {
                channel.assign(from: base, count: samples.count)
            }
        }
        append(buffer: buffer, from: source)
    }

    func append(buffer: AVAudioPCMBuffer, from source: Source) {
        stateQueue.async { [weak self] in
            guard let self else { return }
            guard self.isRecording else { return }
            switch source {
            case .microphone:
                self.microphoneSource.enqueue(buffer: buffer, targetFormat: self.outputFormat, logger: self.logger)
            case .system:
                self.systemSource.enqueue(buffer: buffer, targetFormat: self.outputFormat, logger: self.logger)
            }
        }
    }

    private func handleTapBuffer(_ buffer: AVAudioPCMBuffer) {
        var context: (AVAssetWriterInput, CMTime)? = nil
        stateQueue.sync {
            guard isRecording, let input = assetInput else { return }
            let time = CMTime(value: recordedFrames, timescale: CMTimeScale(outputFormat.sampleRate))
            recordedFrames += AVAudioFramePosition(buffer.frameLength)
            context = (input, time)
        }

        guard let (input, time) = context else { return }
        if !input.append(buffer, withPresentationTime: time) {
            let message = input.error?.localizedDescription ?? "unknown"
            logger.error("Failed to append audio sample: \(message, privacy: .public)")
        }
    }
}

private final class SourceContext {
    let node: AVAudioSourceNode
    private let name: String
    private let gain: Float
    private let ringBuffer = AudioRingBuffer()
    private var converter: AVAudioConverter?
    private var didLogSilence = false

    init(name: String, gain: Float) {
        self.name = name
        self.gain = gain
        node = AVAudioSourceNode { [weak ringBuffer] isSilence, _, frameCount, audioBufferList in
            guard let ringBuffer else {
                SourceContext.fillSilence(audioBufferList, frameCount: frameCount)
                isSilence.pointee = true
                return noErr
            }
            let written = ringBuffer.read(into: audioBufferList, frameCount: Int(frameCount))
            if written < Int(frameCount) {
                SourceContext.fillSilence(audioBufferList, frameCount: frameCount, startFrame: written)
                isSilence.pointee = written == 0
            } else {
                isSilence.pointee = false
            }
            return noErr
        }
    }

    func start() {
        ringBuffer.reset()
        didLogSilence = false
    }

    func stop() {
        ringBuffer.reset()
    }

    func reset() {
        ringBuffer.reset()
    }

    func enqueue(buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat, logger: Logger) {
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: targetFormat)
        }
        guard let converter else {
            logger.error("Recorder converter missing for format \(buffer.format.debugDescription, privacy: .public)")
            return
        }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 32)
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var error: NSError?
        var consumed = false
        converter.convert(to: converted, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if let error {
            logger.error("Audio conversion failed (\(name, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            return
        }

        guard let channel = converted.floatChannelData?[0] else { return }
        let length = Int(converted.frameLength)
        if length == 0 {
            if !didLogSilence {
                logger.warning("Recorder source \(name, privacy: .public) produced empty buffer")
                didLogSilence = true
            }
            return
        }

        var samples = [Float](repeating: 0, count: length)
        channel.withMemoryRebound(to: Float.self, capacity: length) { pointer in
            for index in 0..<length {
                samples[index] = pointer[index] * gain
            }
        }
        ringBuffer.write(samples)
        didLogSilence = false
    }

    private static func fillSilence(_ list: UnsafeMutablePointer<AudioBufferList>, frameCount: AVAudioFrameCount, startFrame: Int = 0) {
        let totalFrames = Int(frameCount)
        for bufferIndex in 0..<Int(list.pointee.mNumberBuffers) {
            var buffer = list.pointee.mBuffers[bufferIndex]
            guard let data = buffer.mData else { continue }
            let ptr = data.assumingMemoryBound(to: Float.self)
            ptr.advanced(by: startFrame).initialize(repeating: 0, count: totalFrames - startFrame)
        }
    }
}

private final class AudioRingBuffer {
    private struct Pending {
        var samples: [Float]
        var offset: Int
    }

    private var queue: [Pending] = []
    private var head = 0
    private let lock = NSLock()

    func write(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        lock.lock()
        queue.append(Pending(samples: samples, offset: 0))
        lock.unlock()
    }

    func read(into audioBufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }

        var written = 0
        while written < frameCount {
            if head >= queue.count {
                break
            }
            if queue[head].offset >= queue[head].samples.count {
                head += 1
                continue
            }
            let available = queue[head].samples.count - queue[head].offset
            let toCopy = min(available, frameCount - written)

            queue[head].samples.withUnsafeBufferPointer { source in
                for bufferIndex in 0..<Int(audioBufferList.pointee.mNumberBuffers) {
                    var buffer = audioBufferList.pointee.mBuffers[bufferIndex]
                    guard let data = buffer.mData else { continue }
                    let ptr = data.assumingMemoryBound(to: Float.self)
                    ptr.advanced(by: written).assign(from: source.baseAddress! + queue[head].offset, count: toCopy)
                }
            }

            queue[head].offset += toCopy
            written += toCopy
            if queue[head].offset >= queue[head].samples.count {
                head += 1
            }
        }

        if head > 8 {
            queue.removeFirst(head)
            head = 0
        }
        return written
    }

    func reset() {
        lock.lock()
        queue.removeAll(keepingCapacity: false)
        head = 0
        lock.unlock()
    }
}
