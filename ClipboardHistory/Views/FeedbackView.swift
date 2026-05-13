import SwiftUI

struct FeedbackView: View {
    @EnvironmentObject var locale: LocaleManager
    @State private var feedbackText: String = ""
    @State private var sent = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)

            Text(locale.tr("feedback.title"))
                .font(.system(size: 14, weight: .semibold))

            Text(locale.tr("feedback.subtitle"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            TextEditor(text: $feedbackText)
                .font(.system(size: 12))
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3))
                )
                .overlay(alignment: .topLeading) {
                    if feedbackText.isEmpty {
                        Text(locale.tr("feedback.hint"))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                if sent {
                    Text(locale.tr("feedback.sent"))
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                }
                Spacer()
                Button(locale.tr("feedback.send")) { send() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 340)
    }

    private func send() {
        let body = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let subject = "ClipX - Feedback"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:1455395994@qq.com?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
            sent = true
        }
    }
}
