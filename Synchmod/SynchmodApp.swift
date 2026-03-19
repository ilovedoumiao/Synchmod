import SwiftUI

@main
struct SynchmodApp: App {
	var body: some Scene {
		WindowGroup {
			ContentView()
				.frame(width: 480, height: 450)
				.fixedSize()
				.onAppear {
					if let window = NSApplication.shared.windows.first {
						window.styleMask.remove(.resizable)  // prevent resizing
						window.standardWindowButton(.zoomButton)?.isHidden =
							true  // hide maximize
					}
				}
		}
		.windowResizability(.contentSize)  // optional, reinforces fixed size
	}
}
