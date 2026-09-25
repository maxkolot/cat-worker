import SwiftUI

/// Task card sheet: spec, stage, history, "copy and open the role's chat".
struct TaskDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let taskID: String

    var body: some View {
        NavigationStack {
            Group {
                if let task = model.task(taskID) {
                    content(task)
                } else {
                    ContentUnavailableView("Задача не найдена", systemImage: "questionmark.square.dashed")
                }
            }
            .background(Palette.bg)
            .navigationTitle(taskID)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func content(_ task: BoardTask) -> some View {
        let role = model.role(task.roleId)
        let color = model.roleColor(task.roleId)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    StatusBadge(task: task)
                    RoleChip(name: role?.name ?? task.roleId, color: color)
                    Spacer()
                    Text(RelativeTime.string(task.updated))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(task.title)
                    .font(.title3.weight(.bold))

                Menu {
                    ForEach(BoardColumn.allCases) { column in
                        Button {
                            Task { await model.move(task, to: column) }
                        } label: {
                            if column == BoardColumn.of(task) {
                                Label(column.title, systemImage: "checkmark")
                            } else {
                                Text(column.title)
                            }
                        }
                    }
                } label: {
                    Label("Этап: \(BoardColumn.of(task).title)", systemImage: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await model.sendToChat(task) { openURL($0) } }
                } label: {
                    Label(role?.chatUrl != nil ? "Скопировать и открыть чат роли" : "Скопировать задачу",
                          systemImage: "bubble.left.and.text.bubble.right.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)

                VStack(alignment: .leading, spacing: 8) {
                    Text("ТЗ").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Text(task.spec)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .card()

                if let history = task.history, !history.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("История").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        ForEach(Array(history.enumerated().reversed()), id: \.offset) { _, entry in
                            HistoryRow(entry: entry)
                        }
                    }
                    .padding(14)
                    .card()
                }
            }
            .padding()
        }
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        let label: String = {
            switch entry.status {
            case "development": return "разработка"
            case "testing": return (entry.round ?? 0) > 1 ? "тестирование \(entry.round ?? 0)" : "тестирование"
            case "fixes": return "фиксы"
            case "done": return "готово"
            default: return "создана"
            }
        }()
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Palette.accent.opacity(0.8)).frame(width: 7, height: 7).padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(label).font(.subheadline.weight(.semibold))
                    if entry.by == "user" { Text("· ты").font(.caption).foregroundStyle(.secondary) }
                    if entry.by == "autopilot" { Text("· автопилот").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Text(RelativeTime.short(entry.t)).font(.caption2).foregroundStyle(.tertiary)
                }
                if let note = entry.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct NewTaskView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var roleID = ""
    @State private var spec = ""
    @State private var sending = false
    @FocusState private var focused: Bool

    private var canSend: Bool {
        !roleID.isEmpty && !spec.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sending
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Роль") {
                    Picker("Роль", selection: $roleID) {
                        ForEach(model.roles) { role in
                            Text("\(role.id) · \(role.name)").tag(role.id)
                        }
                    }
                }
                Section {
                    TextEditor(text: $spec)
                        .frame(minHeight: 220)
                        .focused($focused)
                } header: {
                    Text("ТЗ")
                } footer: {
                    Text("Первая строка станет названием. ID присвоится автоматически. Можно надиктовать — микрофон на клавиатуре.")
                }
            }
            .navigationTitle("Новая задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        sending = true
                        Task {
                            let ok = await model.addTask(roleID: roleID, spec: spec)
                            sending = false
                            if ok { dismiss() }
                        }
                    }
                    .disabled(!canSend)
                }
            }
            .onAppear {
                if roleID.isEmpty { roleID = model.roles.first?.id ?? "" }
                focused = true
            }
        }
    }
}
