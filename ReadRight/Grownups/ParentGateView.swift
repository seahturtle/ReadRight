import SwiftUI

// TODO(team): Build the grown-up gate. It keeps young children out of the grown-up area.
//
// Spec (from the plan):
// - Ask a random multiplication problem written in WORDS, e.g. "What is seven times eight?",
//   so children who can't read yet can't guess it. Use numbers 3–9 for each side.
// - Show a number pad or a text field with `.keyboardType(.numberPad)`.
// - Right answer → call `onPass()`. Wrong answer → show a new problem. No lockouts or scolding.
// - It's a speed bump, not real security. The privacy screen should say that.
// - Then use it: in TemporaryHomeView (or your map), show this before GrownUpsView.
//   One way: a `@State var showGate = false` plus `.sheet(isPresented:)`, then push `Route.grownUps` in `onPass`.
// - Write a unit test for your number-to-words function in ReadRightTests.

struct ParentGateView: View {
    var onPass: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Grown-ups only")
                .font(.title.bold())
            Text("TODO(team): ask a multiplication question in words here.")
                .foregroundStyle(.secondary)
            Button("Continue (temporary)") { onPass() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
