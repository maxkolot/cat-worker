import Foundation
import SwiftUI

// MARK: - Board API payloads (server-mcp /board/api, snake_case → camelCase)

struct BoardState: Decodable {
    var projects: [Project]
    var roles: [Role]
    var tasks: [BoardTask]
}

struct Project: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
}

struct Role: Decodable, Identifiable, Hashable {
    let id: String
    let projectId: String
    let name: String
    let brief: String?
    let claimed: Bool?
    /// ChatGPT conversation that plays this role (reported by the browser extension)
    let chatUrl: String?
    let prompt: String?
}

struct HistoryEntry: Decodable, Hashable {
    let t: String
    let status: String
    let round: Int?
    let note: String?
    let by: String?
}

/// "Task" would clash with Swift concurrency's Task
struct BoardTask: Decodable, Identifiable, Hashable {
    let id: String
    let projectId: String
    let roleId: String
    let title: String
    let spec: String
    let status: String
    let statusLabel: String?
    let testRound: Int?
    let dispatchedAt: String?
    let updated: String?
    let createdBy: String?
    let history: [HistoryEntry]?
    let prompt: String?
}

struct ScreensResponse: Decodable {
    let screens: [BotScreen]
    let max: Int?
}

struct BotScreen: Decodable, Identifiable, Hashable {
    let id: String
    let ageMin: Int?
    let idleMin: Int?
    let roleId: String?
    let taskId: String?
    let taskTitle: String?
}

// MARK: - Servers (kept in the Keychain — they carry the board key)

struct ServerConfig: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var url: String
    var key: String
    /// First line the extension puts before every prompt, e.g. "используй @УБУ"
    var prefix: String?
}

// MARK: - Kanban columns

enum BoardColumn: String, CaseIterable, Identifiable {
    case created, sent, inProgress, fixes, testing, done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .created: return "Создано"
        case .sent: return "Отправлено"
        case .inProgress: return "В работе"
        case .fixes: return "Фиксы"
        case .testing: return "Тестирование"
        case .done: return "Готово"
        }
    }

    /// Server status a task gets when dropped here (`sent` = todo + dispatched mark)
    var status: String {
        switch self {
        case .created, .sent: return "todo"
        case .inProgress: return "development"
        case .fixes: return "fixes"
        case .testing: return "testing"
        case .done: return "done"
        }
    }

    var color: Color {
        switch self {
        case .created: return Color(hex: 0x6B7280)
        case .sent: return Color(hex: 0x8B5CF6)
        case .inProgress: return Color(hex: 0x3B82F6)
        case .fixes: return Color(hex: 0xEF4444)
        case .testing: return Color(hex: 0xF59E0B)
        case .done: return Color(hex: 0x22C55E)
        }
    }

    static func of(_ task: BoardTask) -> BoardColumn {
        switch task.status {
        case "development": return .inProgress
        case "fixes": return .fixes
        case "testing": return .testing
        case "done": return .done
        default: return task.dispatchedAt == nil ? .created : .sent
        }
    }
}

// MARK: - Look

enum Palette {
    static let accent = Color(hex: 0xFF5A3C)
    static let bg = Color(hex: 0x0E0F12)
    static let column = Color(hex: 0x15171B)
    static let card = Color(hex: 0x1C1F24)
    static let line = Color(hex: 0x2A2E35)

    private static let roleHexes: [UInt32] = [
        0x60A5FA, 0xF472B6, 0x34D399, 0xFBBF24, 0xA78BFA,
        0xFB7185, 0x22D3EE, 0xFB923C, 0xA3E635, 0xE879F9,
        0x38BDF8, 0xF87171, 0x4ADE80, 0xFACC15, 0xC084FC,
    ]
    static let roles: [Color] = roleHexes.map { Color(hex: $0) }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum RelativeTime {
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso = ISO8601DateFormatter()
    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .short
        return f
    }()

    static func date(_ s: String) -> Date? { isoFractional.date(from: s) ?? iso.date(from: s) }

    static func string(_ s: String?) -> String {
        guard let s, let d = date(s) else { return "" }
        return relative.localizedString(for: d, relativeTo: Date())
    }

    static func short(_ s: String) -> String {
        guard let d = date(s) else { return s }
        return d.formatted(.dateTime.day().month(.twoDigits).hour().minute())
    }
}
