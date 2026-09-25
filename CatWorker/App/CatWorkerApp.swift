import SwiftUI

@main
struct CatWorkerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .onOpenURL { url in _ = model.handleURL(url) }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.servers.isEmpty {
                OnboardingView()
            } else {
                TabView {
                    BoardView()
                        .tabItem { Label("Доска", systemImage: "rectangle.split.3x1") }
                    BotsView()
                        .tabItem { Label("Боты", systemImage: "cat") }
                    ScreensView()
                        .tabItem { Label("Экраны", systemImage: "display.2") }
                    SettingsView()
                        .tabItem { Label("Настройки", systemImage: "gearshape") }
                }
            }
        }
        .tint(Palette.accent)
        // keep the board fresh while the app is open; restarts when the server changes
        .task(id: model.selectedServerID) {
            while !Task.isCancelled {
                await model.refresh()
                try? await Task.sleep(for: .seconds(6))
            }
        }
        .overlay(alignment: .top) { Banners() }
    }
}

/// Error and toast banners on top of every screen
struct Banners: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 6) {
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color(hex: 0x7F1D1D)))
                    .onTapGesture { model.error = nil }
            }
            if let toast = model.toast {
                Text(toast)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(.ultraThinMaterial))
            }
        }
        .padding(.top, 4)
        .animation(.spring(duration: 0.3), value: model.toast)
        .animation(.spring(duration: 0.3), value: model.error)
    }
}
