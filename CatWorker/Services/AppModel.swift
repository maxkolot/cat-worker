import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class AppModel {
    // servers
    var servers: [ServerConfig] = []
    var selectedServerID: String?

    // board of the selected server
    var state: BoardState?
    var projectID: String?
    var screens: [BotScreen] = []
    var maxScreens = 4
    var error: String?
    var loading = false

    // board filters
    var hiddenRoles: Set<String> = []
    var hideDone = false
    var search = ""

    // one-line confirmation ("Скопировано", "T12 → Готово")
    var toast: String?

    // navigation driven from outside (notification deep links)
    var tab: AppTab = .board
    var openTask: TaskRef?

    init() {
        if let data = Keychain.load(account: "servers"),
           let saved = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            servers = saved
        }
        let last = UserDefaults.standard.string(forKey: "selectedServer")
        selectedServerID = servers.contains { $0.id == last } ? last : servers.first?.id
    }

    // MARK: servers

    var server: ServerConfig? { servers.first { $0.id == selectedServerID } ?? servers.first }
    var api: APIClient? { server.map { APIClient(server: $0) } }

    private func saveServers() {
        if let data = try? JSONEncoder().encode(servers) { Keychain.save(data, account: "servers") }
    }

    func selectServer(_ id: String) {
        guard id != selectedServerID else { return }
        selectedServerID = id
        UserDefaults.standard.set(id, forKey: "selectedServer")
        state = nil
        screens = []
        projectID = nil
        hiddenRoles = []
        error = nil
        Task { await refresh() }
    }

    func addOrUpdate(_ config: ServerConfig) {
        if let i = servers.firstIndex(where: { $0.id == config.id || $0.url == config.url }) {
            servers[i] = config
        } else {
            servers.append(config)
        }
        saveServers()
        selectedServerID = nil
        selectServer(config.id)
        show("Сервер «\(config.name)» подключён")
    }

    func removeServers(at offsets: IndexSet) {
        servers.remove(atOffsets: offsets)
        saveServers()
        if !servers.contains(where: { $0.id == selectedServerID }), let first = servers.first {
            selectedServerID = nil
            selectServer(first.id)
        }
    }

    /// catworker://add?name=…&url=…&key=…&id=…&prefix=… (QR from the browser extension)
    /// catworker://task?server=<id>&task=<id>         (blocker notification from ntfy)
    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        guard url.scheme == "catworker",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        // URLSearchParams in the extension encodes spaces as "+"
        func value(_ name: String) -> String? {
            comps.queryItems?.first { $0.name == name }?.value?.replacingOccurrences(of: "+", with: " ")
        }
        if url.host == "task" {
            guard let taskID = value("task") else { return false }
            if let serverID = value("server"), servers.contains(where: { $0.id == serverID }) {
                selectServer(serverID)
            }
            tab = .board
            openTask = TaskRef(id: taskID)
            Task { await refresh() }
            return true
        }
        guard url.host == "add" else { return false }
        guard let serverURL = value("url"), let key = value("key"), !key.isEmpty else { return false }
        addOrUpdate(ServerConfig(
            id: value("id") ?? UUID().uuidString,
            name: value("name") ?? "Сервер",
            url: serverURL,
            key: key,
            prefix: value("prefix")
        ))
        return true
    }

    // MARK: loading

    func refresh() async {
        guard let api else { return }
        loading = true
        defer { loading = false }
        do {
            let fresh = try await api.state()
            state = fresh
            if projectID == nil || !fresh.projects.contains(where: { $0.id == projectID }) {
                projectID = fresh.projects.last?.id
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshScreens() async {
        guard let api else { return }
        if let r = try? await api.screens() {
            screens = r.screens
            maxScreens = r.max ?? 4
        }
    }

    // MARK: derived

    var project: Project? { state?.projects.first { $0.id == projectID } }
    var roles: [Role] { (state?.roles ?? []).filter { $0.projectId == projectID } }
    var tasks: [BoardTask] { (state?.tasks ?? []).filter { $0.projectId == projectID } }

    func role(_ id: String) -> Role? { state?.roles.first { $0.id == id } }
    func task(_ id: String) -> BoardTask? { state?.tasks.first { $0.id == id } }

    var filteredTasks: [BoardTask] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return tasks.filter { t in
            !hiddenRoles.contains(t.roleId)
                && !(hideDone && t.status == "done")
                && (q.isEmpty || "\(t.id) \(t.title) \(t.spec)".lowercased().contains(q))
        }
    }

    func columnTasks(_ column: BoardColumn) -> [BoardTask] {
        filteredTasks
            .filter { BoardColumn.of($0) == column }
            .sorted { ($0.updated ?? "") > ($1.updated ?? "") }
    }

    /// The server decides each role's color (same in the extension and dashboard); palette only for old data
    func roleColor(_ roleID: String) -> Color {
        let all = state?.roles ?? []
        guard let role = all.first(where: { $0.id == roleID }) else { return Palette.roles[0] }
        if let serverColor = Color(hexString: role.color) { return serverColor }
        let index = all.filter { $0.projectId == role.projectId }.firstIndex { $0.id == roleID } ?? 0
        return Palette.roles[index % Palette.roles.count]
    }

    func activeTask(of roleID: String) -> BoardTask? {
        tasks.first { $0.roleId == roleID && ["blocked", "development", "testing", "fixes"].contains($0.status) }
    }

    func nextTask(of roleID: String) -> BoardTask? {
        tasks
            .filter { $0.roleId == roleID && $0.status == "todo" && $0.dispatchedAt == nil }
            .sorted { (Int($0.id.dropFirst()) ?? 0) < (Int($1.id.dropFirst()) ?? 0) }
            .first
    }

    // MARK: actions

    func move(_ task: BoardTask, to column: BoardColumn) async {
        guard let api, BoardColumn.of(task) != column else { return }
        do {
            if column == .sent {
                if task.status != "todo" { try await api.setStatus(task.id, "todo") }
                try await api.dispatch(task.id)
            } else {
                try await api.setStatus(task.id, column.status)
            }
            show("\(task.id) → \(column.title)")
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addTask(roleID: String, spec: String) async -> Bool {
        guard let api else { return false }
        do {
            try await api.addTask(roleID: roleID, spec: spec)
            show("Задача добавлена")
            await refresh()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Text the way the extension sends it: server prefix line ("используй @УБУ"), empty line, prompt
    func withPrefix(_ text: String) -> String {
        guard let p = server?.prefix?.trimmingCharacters(in: .whitespaces), !p.isEmpty else { return text }
        return p + "\n\n" + text
    }

    /// Copy the task prompt, mark it as sent and open the role's ChatGPT chat — the user pastes and sends
    func sendToChat(_ task: BoardTask, open: (URL) -> Void) async {
        UIPasteboard.general.string = withPrefix(task.prompt ?? task.spec)
        if task.status == "todo", task.dispatchedAt == nil, let api {
            try? await api.dispatch(task.id)
            await refresh()
        }
        if let s = role(task.roleId)?.chatUrl, let url = URL(string: s) {
            show("Скопировано — вставь в чат")
            open(url)
        } else {
            show("Скопировано. Чат роли не привязан — открой его в ChatGPT вручную")
        }
    }

    /// Reply to a bot: queued on the server, the extension types it into the role's chat when it is free
    func reply(to task: BoardTask, text: String) async -> Bool {
        guard let api else { return false }
        do {
            try await api.sendMessage(roleID: task.roleId, taskID: task.id, text: text)
            show("Ответ уйдёт в чат роли, как только он освободится")
            await refresh()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func pendingReplies(for roleID: String) -> [BoardMessage] {
        (state?.messages ?? []).filter { $0.roleId == roleID }
    }

    var blockedCount: Int { tasks.filter { $0.status == "blocked" }.count }

    func copyRole(_ role: Role) {
        UIPasteboard.general.string = withPrefix(role.prompt ?? role.brief ?? role.name)
        show("Роль скопирована")
    }

    func show(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if toast == message { toast = nil }
        }
    }
}
