import AppKit

@main
enum DockSnapMain {
    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if let command = arguments.first, CLI.isHeadlessCommand(command) {
            exit(CLI.run(command))
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
