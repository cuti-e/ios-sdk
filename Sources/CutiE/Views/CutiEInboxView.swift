import SwiftUI

#if os(iOS)
/// In-app inbox view showing user's feedback conversations
@available(iOS 15.0, *)
public struct CutiEInboxView: View {
    @StateObject private var viewModel: InboxViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFeedbackSheet = false

    /// Create an inbox view, optionally navigating directly to a conversation
    /// - Parameter conversationId: If provided, automatically navigates to this conversation on appear
    public init(conversationId: String? = nil) {
        self._viewModel = StateObject(wrappedValue: InboxViewModel(initialConversationId: conversationId))
    }

    public var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ProgressView("Loading...")
                } else if viewModel.conversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .navigationTitle("My Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            Task { await viewModel.loadConversations() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)

                        Button {
                            showFeedbackSheet = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            .background(
                NavigationLink(
                    isActive: $viewModel.isNavigatingToTarget,
                    destination: {
                        if let conversation = viewModel.navigationTarget {
                            CutiEConversationView(conversation: conversation)
                                .onDisappear {
                                    viewModel.navigationTarget = nil
                                    Task { await viewModel.loadConversations() }
                                }
                        }
                    },
                    label: { EmptyView() }
                )
                .hidden()
            )
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .sheet(isPresented: $showFeedbackSheet, onDismiss: {
            Task { await viewModel.loadConversations() }
        }) {
            CutiEFeedbackView()
        }
        .task {
            await viewModel.loadConversations()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Feedback Yet")
                .font(.headline)
            Text("Tap the compose button to send us your feedback.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showFeedbackSheet = true
            } label: {
                Text("Send Feedback")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var conversationList: some View {
        List(viewModel.conversations) { conversation in
            NavigationLink {
                CutiEConversationView(conversation: conversation)
                    .onDisappear {
                        // Refresh inbox when returning from conversation
                        Task { await viewModel.loadConversations() }
                    }
            } label: {
                ConversationRow(conversation: conversation)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.loadConversations()
        }
    }
}

// MARK: - Conversation Row

@available(iOS 15.0, *)
private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(conversation.title ?? categoryTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let lastMessage = conversation.messages?.last {
                HStack(spacing: 6) {
                    if lastMessage.senderType == .admin {
                        // Show small mascot indicator
                        Circle()
                            .fill(Color.pink.opacity(0.2))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text(String((lastMessage.senderName ?? "S").prefix(1)))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.pink)
                            )
                        Text(lastMessage.senderName ?? "Support")
                            .font(.caption)
                            .foregroundColor(.pink)
                            .fontWeight(.medium)
                    }
                    Text(lastMessage.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            HStack {
                statusBadge
                Spacer()
                // Show unread count badge if there are unread messages
                if let unread = conversation.unreadCount, unread > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.pink)
                            .frame(width: 8, height: 8)
                        Text("\(unread)")
                            .font(.caption.bold())
                            .foregroundColor(.pink)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.pink.opacity(0.15))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var categoryTitle: String {
        guard let category = conversation.category else {
            return "Conversation"
        }
        switch category {
        case .bug: return "Bug Report"
        case .feature: return "Feature Request"
        case .question: return "Question"
        case .feedback: return "Feedback"
        case .other: return "Other"
        }
    }

    private var timeAgo: String {
        let date = conversation.createdDate
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var statusBadge: some View {
        let (text, color) = statusInfo
        return Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private var statusInfo: (String, Color) {
        switch conversation.status {
        case .open: return ("Open", .blue)
        case .in_progress: return ("In Progress", .orange)
        case .waiting_user: return ("Needs Reply", .purple)
        case .waiting_admin: return ("Waiting", .gray)
        case .resolved: return ("Resolved", .green)
        case .closed: return ("Closed", .gray)
        }
    }

}

// MARK: - View Model

@available(iOS 15.0, *)
@MainActor
private class InboxViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isNavigatingToTarget = false
    @Published var navigationTarget: Conversation?

    private var initialConversationId: String?

    init(initialConversationId: String? = nil) {
        self.initialConversationId = initialConversationId
    }

    func loadConversations() async {
        isLoading = true
        errorMessage = nil

        do {
            conversations = try await CutiE.shared.getConversations()

            // Auto-navigate to target conversation if specified
            if let targetId = initialConversationId,
               let target = conversations.first(where: { $0.id == targetId }) {
                initialConversationId = nil
                navigationTarget = target
                isNavigatingToTarget = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
#endif
