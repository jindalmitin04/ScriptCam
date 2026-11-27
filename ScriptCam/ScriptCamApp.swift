import SwiftUI

@main
struct ScriptCamApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 1000, minHeight: 650)
        }
        .windowStyle(.titleBar)
    }
}
