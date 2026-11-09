import AppKit

@MainActor final class CheckInSuccessSound {
    private var sound: NSSound?

    func play() {
        sound?.stop()
        let bundled = Bundle.main.url(forResource: "CheckInSuccess", withExtension: "wav")
        sound = bundled.flatMap { NSSound(contentsOf: $0, byReference: false) }
            ?? NSSound(contentsOf: URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff"), byReference: false)
        sound?.volume = 0.65
        sound?.play()
    }
    func stop() {
        sound?.stop(); sound = nil
    }
}
