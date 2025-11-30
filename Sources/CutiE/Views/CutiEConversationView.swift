import SwiftUI

#if os(iOS)
/// Detail view for a single conversation
@available(iOS 15.0, *)
public struct CutiEConversationView: View {
    let conversation: Conversation
    @StateObject private var viewModel: ConversationViewModel
    @FocusState private var isInputFocused: Bool

    public init(conversation: Conversation) {
        self.conversation = conversation
        self._viewModel = StateObject(wrappedValue: ConversationViewModel(conversationId: conversation.id))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input area
            if conversation.status != .closed && conversation.status != .resolved {
                inputArea
            } else {
                closedBanner
            }
        }
        .navigationTitle(conversation.title ?? "Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadMessages()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Type a message...", text: $viewModel.messageText)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($isInputFocused)

            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
            }
            .disabled(viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private var closedBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("This conversation has been \(conversation.status == .resolved ? "resolved" : "closed").")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }
}

// MARK: - Message Bubble

@available(iOS 15.0, *)
private struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.senderType == .user {
                Spacer(minLength: 60)
            } else if message.senderType == .admin {
                // Avatar for admin/mascot
                avatarView
            }

            VStack(alignment: message.senderType == .user ? .trailing : .leading, spacing: 4) {
                if message.senderType == .admin {
                    Text(message.senderName ?? "Support")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.pink)
                }

                Text(message.message)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(timeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.senderType != .user {
                Spacer(minLength: 60)
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatarUrl = message.senderAvatarUrl, let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                defaultAvatar
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
        } else {
            defaultAvatar
        }
    }

    private var defaultAvatar: some View {
        Circle()
            .fill(Color.pink.opacity(0.2))
            .frame(width: 32, height: 32)
            .overlay(
                Text(String((message.senderName ?? "S").prefix(1)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.pink)
            )
    }

    private var bubbleColor: Color {
        switch message.senderType {
        case .user:
            return .blue
        case .admin:
            return Color(.systemGray5)
        case .system:
            return Color(.systemGray6)
        }
    }

    private var textColor: Color {
        message.senderType == .user ? .white : .primary
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.createdDate)
    }
}

// MARK: - View Model

@available(iOS 15.0, *)
@MainActor
private class ConversationViewModel: ObservableObject {
    let conversationId: String
    @Published var messages: [Message] = []
    @Published var messageText = ""
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?

    init(conversationId: String) {
        self.conversationId = conversationId
    }

    func loadMessages() async {
        isLoading = true
        errorMessage = nil

        do {
            let conversation = try await CutiE.shared.getConversation(id: conversationId)
            messages = conversation.messages ?? []
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true
        errorMessage = nil
        let originalText = messageText
        messageText = ""

        do {
            let newMessage = try await CutiE.shared.sendMessage(
                conversationId: conversationId,
                message: text
            )
            messages.append(newMessage)
        } catch {
            messageText = originalText
            errorMessage = error.localizedDescription
        }

        isSending = false
    }
}
#endif
