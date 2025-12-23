import SwiftUI

/// Main content view - will contain the three-column layout (Sidebar, List, Detail)
struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            // Sidebar - Accounts and Folders
            SidebarView()
        } content: {
            // Message List
            MessageListView()
        } detail: {
            // Message Detail
            MessageDetailView()
        }
    }
}

// MARK: - Placeholder Views

struct SidebarView: View {
    var body: some View {
        List {
            Section("Folders") {
                Label("Inbox", systemImage: "tray.fill")
                Label("Sent", systemImage: "paperplane.fill")
                Label("Starred", systemImage: "star.fill")
            }
        }
        .navigationTitle("MailForge")
    }
}

struct MessageListView: View {
    var body: some View {
        VStack {
            Text("No messages")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Inbox")
    }
}

struct MessageDetailView: View {
    var body: some View {
        VStack {
            Text("Select a message")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
}
