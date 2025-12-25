import SwiftUI

/// Legacy ContentView - No longer used (replaced by MainView)
/// Kept for reference only
struct ContentView: View {
    var body: some View {
        VStack {
            Text("This view is no longer used")
                .foregroundStyle(.secondary)
            Text("The app now uses MainView")
                .font(.caption)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
}
