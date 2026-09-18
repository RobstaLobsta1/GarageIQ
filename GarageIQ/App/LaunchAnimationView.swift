import SwiftUI

/// The native storyboard remains static; this runs once when the app UI starts.
struct StartupView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingLaunch = true

    var body: some View {
        ZStack {
            MainTabView()
                .accessibilityHidden(showingLaunch)
                .allowsHitTesting(!showingLaunch)
            if showingLaunch {
                LaunchAnimationView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            if reduceMotion {
                showingLaunch = false
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(1800))
                withAnimation(.easeOut(duration: 0.25)) { showingLaunch = false }
            } catch {
                // Cancellation must not leave the startup overlay covering the app.
                showingLaunch = false
            }
        }
    }
}

struct LaunchAnimationView: View {
    @State private var revealed = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 49 / 255, green: 51 / 255, blue: 56 / 255)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ZStack {
                        Text("G")
                            .font(.system(size: 127, weight: .bold))
                            .foregroundStyle(Color(red: 165 / 255, green: 172 / 255, blue: 1))
                            .offset(x: revealed ? 0 : -geometry.size.width)
                            .position(x: 76, y: 100)
                            .animation(.spring(response: 0.45, dampingFraction: 0.6), value: revealed)
                        Text("Q")
                            .font(.system(size: 59, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: revealed ? 0 : geometry.size.width)
                            .position(x: 145, y: 124)
                            .animation(.easeOut(duration: 0.4).delay(0.25), value: revealed)
                        Text("I")
                            .font(.system(size: 59, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(y: revealed ? 0 : -geometry.size.height)
                            .position(x: 145, y: 72)
                            .animation(.spring(response: 0.5, dampingFraction: 0.42).delay(0.6), value: revealed)
                    }
                    .frame(width: 200, height: 200)
                    Text("GarageIQ")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Smarter care for your garage.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(red: 0.71, green: 0.729, blue: 0.757))
                }
                .padding(.horizontal, 24)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("GarageIQ")
        .task {
            do {
                // Allow the starting positions to render before animating.
                try await Task.sleep(for: .milliseconds(50))
                revealed = true
            } catch { }
        }
    }
}

#Preview {
    LaunchAnimationView()
}
