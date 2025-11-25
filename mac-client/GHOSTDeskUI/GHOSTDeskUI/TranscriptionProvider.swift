import Foundation
import AVFoundation
import CoreMedia

protocol TranscriptionProvider: AnyObject {
    var delegate: TranscriptionProviderDelegate? { get set }
    func start() throws
    func stop()
    func pushAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: CMTime, speaker: SpeakerRole)
}

protocol TranscriptionProviderDelegate: AnyObject {
    func provider(_ provider: TranscriptionProvider, didUpdatePartial text: String, speaker: SpeakerRole)
    func provider(_ provider: TranscriptionProvider, didFinishUtterance text: String, speaker: SpeakerRole)
}

enum SpeakerRole {
    case me
    case them
}

enum STTProviderKind {
    case deepgram
    case whisperLocal
}

struct TranscriptionConfig {
    var provider: STTProviderKind = .deepgram
}
