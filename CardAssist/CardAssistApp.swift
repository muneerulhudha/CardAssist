import SwiftUI
import ElevenLabs

@main
struct CardAssistApp: App {
    @StateObject private var model = AppModel()

    init() {
        ElevenLabs.configure(
            .init(
                logLevel: .debug,
                debugMode: true
            )
        )
        print("[Eleven] SDK debug logging enabled")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
