import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: AuthSession
    @State private var isLoggingIn = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue, .orange)

            VStack(spacing: 8) {
                Text("Dual Weather")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Sign in to save and sync locations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                guard !isLoggingIn else { return }
                isLoggingIn = true
                Task {
                    await session.login()
                    isLoggingIn = false
                }
            } label: {
                HStack(spacing: 10) {
                    if isLoggingIn {
                        ProgressView().tint(.white)
                    }
                    Text(isLoggingIn ? "Signing in…" : "Continue")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoggingIn)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthSession())
}
