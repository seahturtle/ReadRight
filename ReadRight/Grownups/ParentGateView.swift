import SwiftUI

/// The grown-up gate: a multiplication problem written in words ("What is seven times eight?"),
/// so children who can't read yet, or don't know their times tables, can't open the grown-up area.
///
/// It's a speed bump for young children, not real security, and the privacy page says so.
/// There's no lockout and no scolding: a wrong answer just brings a new problem.
struct ParentGateView: View {
    var onPass: () -> Void
    var onCancel: () -> Void

    @State private var problem = ParentGate.Problem.random()
    @State private var answer = ""
    @State private var tries = 0
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                VStack(alignment: .leading, spacing: 18) {
                    Eyebrow(text: "Grown-ups only")
                    Text("Answer this to open the grown-up area")
                        .themed(.display, 24)
                        .foregroundStyle(Theme.ink)
                    Text(problem.question)
                        .themed(.display, 28)
                        .foregroundStyle(Theme.earth)
                        .padding(.vertical, 4)
                        .accessibilityAddTraits(.isHeader)
                    TextField("Answer", text: $answer)
                        .themed(.display, 28)
                        .keyboardType(.numberPad)
                        .focused($focused)
                        .padding(14)
                        .frame(maxWidth: 180)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.ink, lineWidth: Theme.line))
                        .onSubmit(check)
                        .accessibilityLabel("Answer")
                    if tries > 0 {
                        Text("Not quite. Here's a new one.")
                            .themed(.body, 15)
                            .foregroundStyle(Theme.warnInk)
                    }
                    Button("Open") { check() }
                        .buttonStyle(ChunkyButtonStyle(fill: Theme.mint, size: 20))
                        .disabled(answer.isEmpty)
                    Text("This keeps young children out of the summary and settings. It's a speed bump, not a password.")
                        .themed(.body, 13)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back", action: onCancel)
                }
            }
        }
        .onAppear { focused = true }
    }

    private func check() {
        if problem.isAnswered(by: answer) {
            onPass()
        } else {
            tries += 1
            answer = ""
            problem = ParentGate.Problem.random(avoiding: problem)
        }
    }
}

enum ParentGate {
    struct Problem: Equatable {
        let left: Int
        let right: Int

        /// Numbers 3–9, so the answer is never a one-digit guess.
        static func random(avoiding previous: Problem? = nil) -> Problem {
            var next: Problem
            repeat {
                next = Problem(left: Int.random(in: 3...9), right: Int.random(in: 3...9))
            } while next == previous
            return next
        }

        var question: String {
            "What is \(ParentGate.word(for: left)) times \(ParentGate.word(for: right))?"
        }

        func isAnswered(by text: String) -> Bool {
            Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) == left * right
        }
    }

    /// Written-out numbers, so the problem can't be solved by matching digits.
    static func word(for number: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        return words.indices.contains(number) ? words[number] : String(number)
    }
}
