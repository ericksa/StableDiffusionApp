import SwiftUI
import StableDiffusion

@main
struct SDApp: App {
    var body: some Scene {
        WindowGroup {
            if #available(macOS 13.1, *) {
                ContentView()
            } else {
                Text("Requires macOS 13.1 or newer")
            }
        }
        .defaultSize(width: 800, height: 600)
    }
}
