import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: AuthSession
    @State private var isLoggingIn = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 44))
                .foregroundStyle(.primary)
                .frame(width: 96, height: 96)
                .glassSurface(cornerRadius: 48)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Dual Weather")
                    .font(AppFont.display())

                Text("Sign in to save and sync locations.")
                    .font(AppFont.body())
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
                        ProgressView()
                    }
                    Text(isLoggingIn ? "Signing in…" : "Continue")
                        .font(AppFont.headline())
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .glassSurface(cornerRadius: Radius.small)
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
