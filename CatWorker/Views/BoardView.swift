import SwiftUI

/// Kanban: columns swipe sideways, cards are dragged between columns with a long press.
struct BoardView: View {
    @Environment(AppModel.self) private var model
    @State private var openedTask: BoardTask?
    @State private var showNewTask = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: 0) {
                FilterBar()
                if model.state == nil {
                    Spacer()
                    if model.loading { ProgressView() } else { Text("Нет данных").foregroundStyle(.secondary) }
                    Spacer()
                } else if model.project == nil {
                    ContentUnavailableView(
                        "Досок ещё нет",
                        systemImage: "cat",
                        description: Text("Попроси любой чат: «собери роли команды для проекта … и расставь задачи на доске».")
                    )
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(BoardColumn.allCases) { column in
                                ColumnView(column: column) { openedTask = $0 }
                                    .containerRelativeFrame(.horizontal, count: 10, span: 8, spacing: 12)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollIndicators(.hidden)
                }
            }
            .background(Palette.bg)
            .navigationTitle(model.project?.name ?? "Доска")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ServerSwitcher() }
                ToolbarItem(placement: .topBarTrailing) { ProjectMenu() }
            }
            .searchable(text: $model.search, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "T12, текст…")
            .overlay(alignment: .bottomTrailing) {
                if model.project != nil {
                    Button {
                        showNewTask = true
                    } label: {
                        Label("Новая задача", systemImage: "plus")
                            .font(.headline)
                            .padding(.horizontal, 18).padding(.vertical, 14)
                            .background(Capsule().fill(Palette.accent))
                            .foregroundStyle(.white)
                            .shadow(color: Palette.accent.opacity(0.45), radius: 12, y: 4)
                    }
                    .padding(20)
                }
            }
            .sheet(item: $openedTask) { task in
                TaskDetailView(taskID: task.id)
            }
            .sheet(isPresented: $showNewTask) {
                NewTaskView()
            }
        }
    }
}

struct FilterBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(model.roles) { role in
                    let hidden = model.hiddenRoles.contains(role.id)
                    Button {
                        if hidden { model.hiddenRoles.remove(role.id) } else { model.hiddenRoles.insert(role.id) }
                    } label: {
                        RoleChip(name: role.name, color: model.roleColor(role.id))
                            .opacity(hidden ? 0.3 : 1)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    model.hideDone.toggle()
                } label: {
                    Text(model.hideDone ? "✓ без готовых" : "скрыть готовые")
                        .font(.caption)
                        .foregroundStyle(model.hideDone ? .primary : .secondary)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .overlay(Capsule().stroke(Palette.line))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
}

struct ColumnView: View {
    @Environment(AppModel.self) private var model
    let column: BoardColumn
    let onOpen: (BoardTask) -> Void
    @State private var targeted = false

    var body: some View {
        let tasks = model.columnTasks(column)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(column.color).frame(width: 8, height: 8)
                Text(column.title.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .overlay(Capsule().stroke(Palette.line))
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tasks) { task in
                        TaskCard(task: task)
                            .onTapGesture { onOpen(task) }
                            .draggable(task.id) {
                                // drag previews render outside the environment — keep them self-contained
                                Text("\(task.id) · \(task.title)")
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                    .padding(12)
                                    .frame(width: 240, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
                            }
                    }
                    if tasks.isEmpty {
                        Text("пусто")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 96)
            }
            .refreshable { await model.refresh() }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.column))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(targeted ? column.color : Palette.line, lineWidth: targeted ? 2 : 1)
        )
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first, let task = model.task(id) else { return false }
            Task { await model.move(task, to: column) }
            return true
        } isTargeted: { targeted = $0 }
    }
}

struct TaskCard: View {
    @Environment(AppModel.self) private var model
    let task: BoardTask

    var body: some View {
        let color = model.roleColor(task.roleId)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(task.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if (task.testRound ?? 0) > 1 {
                    Text("тест \(task.testRound ?? 0)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BoardColumn.testing.color)
                }
                Spacer()
                StatusBadge(task: task)
            }
            Text(task.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
            HStack(spacing: 6) {
                RoleChip(name: model.role(task.roleId)?.name ?? task.roleId, color: color)
                Spacer(minLength: 4)
                Text(RelativeTime.string(task.updated))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let note = task.history?.last?.note, !note.isEmpty {
                Text("↳ " + note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.card))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4).padding(.vertical, 10)
        }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}
