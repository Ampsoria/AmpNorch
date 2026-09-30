import Foundation

@main
struct LockScreenTests {
    static func main() {
        for mask in 0..<32 {
            let state = LockScreenVisibility(enabled: mask & 1 != 0, locked: mask & 2 != 0,
                onConsole: mask & 4 != 0, displayAwake: mask & 8 != 0, hasTrack: mask & 16 != 0)
            precondition(state.shouldPresent == (mask == 31),
                         "Never show over an unlocked, sleeping or other user's session")
        }
        for size in [CGSize(width: 800, height: 600), CGSize(width: 1280, height: 800),
                     CGSize(width: 1512, height: 982), CGSize(width: 1920, height: 1080),
                     CGSize(width: 2560, height: 1440)] {
            let layout = LockScreenLayout(size: size)
            let screen = CGRect(origin: .zero, size: size)
            let signIn = CGRect(x: 0, y: 0, width: size.width, height: 180)
            let clock = CGRect(x: 0, y: size.height * 0.70, width: size.width, height: size.height * 0.3)
            for panel in [layout.music, layout.lyrics] {
                precondition(screen.contains(panel))
                precondition(!panel.intersects(signIn), "Keep the sign-in controls clear")
                precondition(!panel.intersects(clock), "Keep the native date and clock clear")
            }
            precondition(!layout.music.intersects(layout.lyrics))
            precondition(layout.music.maxX < size.width * 0.5, "Interactive panel stays left of authentication")
        }
        print("Lock Screen visibility and layout tests passed")
    }
}
