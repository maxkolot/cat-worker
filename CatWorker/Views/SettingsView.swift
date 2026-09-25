import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section("Серверы") {
                    ForEach(model.servers) { server in
                        Button {
                            model.selectServer(server.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "cat.fill")
                                    .foregroundStyle(server.id == model.server?.id ? Palette.accent : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(server.name).foregroundStyle(.primary)
                                    Text(server.url).font(.caption).foregroundStyle(.secondary)
                                    if let prefix = server.prefix, !prefix.isEmpty {
                                        Text(prefix).font(.caption2).foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                if server.id == model.server?.id {
                                    Image(systemName: "checkmark").foregroundStyle(Palette.accent)
                                }
                            }
                        }
                    }
                    .onDelete { model.removeServers(at: $0) }
                }

                AddServerSection()

                Section("О приложении") {
                    LabeledContent("Версия", value: appVersion)
                    LabeledContent("Ключи доски", value: "в Keychain")
                }
            }
            .navigationTitle("Настройки")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}

/// Paste a catworker://add?… link (the QR from the extension opens the app directly via the Camera)
struct AddServerSection: View {
    @Environment(AppModel.self) private var model
    @State private var link = ""
    @State private var failed = false

    var body: some View {
        Section {
            TextField("catworker://add?…", text: $link, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.callout.monospaced())
            Button("Добавить по ссылке") {
                let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = URL(string: trimmed), model.handleURL(url) {
                    link = ""
                    failed = false
                } else {
                    failed = true
                }
            }
            .disabled(link.isEmpty)
            if failed {
                Text("Это не ссылка Cat Worker").font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("Добавить сервер")
        } footer: {
            Text("Проще всего: в панели расширения на chatgpt.com открой ⚙ → «📱 QR для Cat Worker» и наведи камеру iPhone — приложение откроется и добавит сервер само.")
        }
    }
}

struct OnboardingView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Text("🐱")
                        .font(.system(size: 96))
                        .padding(.top, 40)
                    Text("Cat Worker")
                        .font(.largeTitle.weight(.heavy))
                    Text("Доска задач, боты-роли и их рабочие столы — с телефона.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        step(1, "На компе открой chatgpt.com — панель «Доска» расширения KOLOT Board.")
                        step(2, "Выбери сервер и нажми ⚙ → «📱 QR для Cat Worker».")
                        step(3, "Наведи камеру iPhone на QR и открой Cat Worker.")
                        step(4, "Повтори для второго котика.")
                    }
                    .padding(16)
                    .card()

                    List { AddServerSection() }
                        .frame(height: 260)
                        .scrollContentBackground(.hidden)
                }
                .padding()
            }
            .background(Palette.bg)
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.caption.weight(.heavy))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Palette.accent))
            Text(text).font(.subheadline)
        }
    }
}
