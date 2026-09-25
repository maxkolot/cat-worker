import SwiftUI

/// One card per role: progress, what it is doing now, open its ChatGPT chat, send the next task.
struct BotsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(model.roles) { role in
                        BotCard(role: role)
                    }
                    if model.state != nil && model.roles.isEmpty {
                        ContentUnavailableView(
                            "Ролей нет",
                            systemImage: "cat",
                            description: Text("Попроси чат собрать роли команды на доске.")
                        )
                    }
                }
                .padding()
            }
            .background(Palette.bg)
            .refreshable { await model.refresh() }
            .navigationTitle(model.project?.name ?? "Боты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ServerSwitcher() }
                ToolbarItem(placement: .topBarTrailing) { ProjectMenu() }
            }
        }
    }
}

struct BotCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let role: Role

    var body: some View {
        let tasks = model.tasks.filter { $0.roleId == role.id }
        let done = tasks.filter { $0.status == "done" }.count
        let active = model.activeTask(of: role.id)
        let next = model.nextTask(of: role.id)
        let color = model.roleColor(role.id)
        let chatURL = role.chatUrl.flatMap { URL(string: $0) }

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(color.opacity(0.18))
                    Image(systemName: "cat.fill").font(.title3).foregroundStyle(color)
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(role.name).font(.headline).lineLimit(2)
                    Text("\(role.id) · готово \(done) из \(tasks.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusPill(blocked: active?.status == "blocked", active: active != nil, bound: chatURL != nil)
            }

            ProgressView(value: tasks.isEmpty ? 0 : Double(done) / Double(tasks.count))
                .tint(color)

            if let active {
                HStack(alignment: .top, spacing: 8) {
                    StatusBadge(task: active)
                    Text("\(active.id) · \(active.title)").font(.subheadline).lineLimit(2)
                }
                if active.status == "blocked" {
                    Button {
                        model.tab = .board
                        model.openTask = TaskRef(id: active.id)
                    } label: {
                        Label(active.blocker ?? "Нужна помощь — открыть и ответить", systemImage: "exclamationmark.octagon.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BoardColumn.blocked.color)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                }
            } else if let next {
                Text("Следующая: \(next.id) · \(next.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Button {
                    if let chatURL { openURL(chatURL) }
                } label: {
                    Label("Открыть в ChatGPT", systemImage: "bubble.left.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(color)
                .disabled(chatURL == nil)

                if let next, active == nil {
                    Button {
                        Task { await model.sendToChat(next) { openURL($0) } }
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Скопировать следующую задачу и открыть чат")
                }

                Button {
                    model.copyRole(role)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Скопировать описание роли")
            }

            if chatURL == nil {
                Text("Чат не привязан: возьми роль в ChatGPT через панель расширения — ссылка появится здесь.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .card(radius: 18)
    }

    private func statusPill(blocked: Bool, active: Bool, bound: Bool) -> some View {
        let (text, tint): (String, Color) = blocked
            ? ("блокер", BoardColumn.blocked.color)
            : active
                ? ("работает", BoardColumn.done.color)
                : bound ? ("ждёт", BoardColumn.testing.color) : ("не привязан", .gray)
        return Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.15)))
    }
}
