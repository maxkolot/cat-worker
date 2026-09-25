import SwiftUI

/// "Котик Клайла ▾" — switches the whole app to another server
struct ServerSwitcher: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            ForEach(model.servers) { s in
                Button {
                    model.selectServer(s.id)
                } label: {
                    if s.id == model.server?.id {
                        Label(s.name, systemImage: "checkmark")
                    } else {
                        Text(s.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cat.fill")
                    .foregroundStyle(Palette.accent)
                Text(model.server?.name ?? "Сервер")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Project picker of the current server
struct ProjectMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let projects = Array((model.state?.projects ?? []).reversed())
        if !projects.isEmpty {
            Menu {
                ForEach(projects) { p in
                    Button {
                        model.projectID = p.id
                        model.hiddenRoles = []
                    } label: {
                        if p.id == model.projectID {
                            Label(p.name, systemImage: "checkmark")
                        } else {
                            Text(p.name)
                        }
                    }
                }
            } label: {
                Image(systemName: "folder")
            }
        }
    }
}

struct RoleChip: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.16)))
            .overlay(Capsule().stroke(color.opacity(0.45), lineWidth: 1))
    }
}

struct StatusBadge: View {
    let task: BoardTask

    var body: some View {
        let column = BoardColumn.of(task)
        Text(task.statusLabel ?? column.title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5).fill(column.color))
    }
}

/// 16:10 frame (bot desktops are 1280×800) that clips whatever is inside
struct ScreenFrame<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Color.black
            .aspectRatio(1.6, contentMode: .fit)
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Palette.line, lineWidth: 1))
    }
}

extension View {
    func card(radius: CGFloat = 14) -> some View { modifier(CardBackground(radius: radius)) }
}
