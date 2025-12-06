import SwiftUI

/// SwiftUI view for submitting feedback
@available(iOS 15.0, *)
public struct CutiEFeedbackView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: ConversationCategory = .feedback
    @State private var title: String = ""
    @State private var message: String = ""
    @State private var userName: String = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let onSuccess: ((String) -> Void)?

    public init(onSuccess: ((String) -> Void)? = nil) {
        self.onSuccess = onSuccess
        // Initialize with any previously set user name
        _userName = State(initialValue: CutiE.shared.configuration?.userName ?? "")
    }

    public var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ConversationCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.sfSymbol)
                                .tag(category)
                        }
                    }
                }

                Section {
                    TextField("Title (optional)", text: $title)

                    TextEditor(text: $message)
                        .frame(minHeight: 150)
                        .overlay(
                            Group {
                                if message.isEmpty {
                                    Text("Describe your feedback...")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                } header: {
                    Text("Details")
                }

                Section {
                    TextField("Your name (optional)", text: $userName)
                } header: {
                    Text("Your Info")
                } footer: {
                    Text("Add your name if you'd like us to know who you are")
                }

                Section {
                    Button(action: submitFeedback) {
                        if isSubmitting {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Submit")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    }
                    .disabled(message.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Send Feedback")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func submitFeedback() {
        guard !message.isEmpty else { return }

        isSubmitting = true

        // Set user name if provided (persists for future feedback too)
        if !userName.isEmpty {
            CutiE.shared.setUserName(userName)
        }

        CutiE.shared.createConversation(
            category: selectedCategory,
            message: message,
            title: title.isEmpty ? nil : title
        ) { result in
            // v1.0.48 FIX: Re-add DispatchQueue.main.async for SwiftUI @State updates
            // Even though the SDK uses delegateQueue: .main, SwiftUI @State updates
            // require explicit main queue dispatch to trigger view re-rendering
            DispatchQueue.main.async {
                isSubmitting = false

                switch result {
                case .success(let conversationId):
                    onSuccess?(conversationId)
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true

                    // DEBUG: Write error to file for debugging
                    #if DEBUG
                    if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let debugFile = documentsPath.appendingPathComponent("feedback-error-debug.txt")
                        let debugInfo = """
                        === FEEDBACK SUBMISSION ERROR ===
                        Timestamp: \(Date())
                        Error: \(error)
                        Localized Description: \(error.localizedDescription)
                        ================================
                        """
                        try? debugInfo.write(to: debugFile, atomically: true, encoding: .utf8)
                        NSLog("🔥 [DEBUG] Error written to: \(debugFile.path)")
                        NSLog("🔥 [DEBUG] Error details: \(error)")
                    }
                    #endif
                }
            }
        }
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct CutiEFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        CutiEFeedbackView()
    }
}
