import Foundation
import SwiftData

// MARK: - Child

@Model
final class Child {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "🧒"
    var birthDate: Date?
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \Episode.child)
    var episodes: [Episode] = []

    init(name: String, emoji: String = "🧒", birthDate: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.birthDate = birthDate
        self.createdAt = Date()
    }

    var activeEpisode: Episode? {
        episodes.first { $0.endedAt == nil }
    }

    var pastEpisodes: [Episode] {
        episodes.filter { $0.endedAt != nil }.sorted { $0.startedAt > $1.startedAt }
    }

    var ageDescription: String? {
        guard let birthDate else { return nil }
        let components = Calendar.current.dateComponents([.year, .month], from: birthDate, to: Date())
        let years = components.year ?? 0
        let months = components.month ?? 0
        if years <= 0 && months <= 0 { return "未满月" }
        if years <= 0 { return "\(months)个月" }
        if months == 0 { return "\(years)岁" }
        return "\(years)岁\(months)个月"
    }
}

// MARK: - Episode(一次病程)

@Model
final class Episode {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var note: String = ""
    var child: Child?
    @Relationship(deleteRule: .cascade, inverse: \CareEvent.episode)
    var events: [CareEvent] = []

    init(startedAt: Date = Date()) {
        self.id = UUID()
        self.startedAt = startedAt
    }

    var isActive: Bool { endedAt == nil }

    var sortedEvents: [CareEvent] {
        events.sorted { $0.timestamp < $1.timestamp }
    }

    var temperatureEvents: [CareEvent] {
        sortedEvents.filter { $0.kind == .temperature && $0.temperatureC != nil }
    }

    var medicationEvents: [CareEvent] {
        sortedEvents.filter { $0.kind == .medication }
    }

    var latestTemperatureEvent: CareEvent? { temperatureEvents.last }

    var maxTemperatureC: Double? {
        temperatureEvents.compactMap(\.temperatureC).max()
    }

    var lastMedicationEvent: CareEvent? { medicationEvents.last }

    /// 本次病程用过的药名,按最近使用排序、去重。
    var medicationNames: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for event in medicationEvents.reversed() {
            guard let name = event.medicationName, !name.isEmpty, !seen.contains(name) else { continue }
            seen.insert(name)
            names.append(name)
        }
        return names
    }

    /// 某个药名最近一次的用药记录(仅陈述事实,不做任何建议)。
    func lastDose(of medicationName: String) -> CareEvent? {
        medicationEvents.last { $0.medicationName == medicationName }
    }

    var durationDescription: String {
        let end = endedAt ?? Date()
        let hours = Int(end.timeIntervalSince(startedAt) / 3600)
        if hours < 1 { return "不足1小时" }
        if hours < 24 { return "\(hours)小时" }
        return "\(hours / 24)天\(hours % 24)小时"
    }
}

// MARK: - CareEvent(一条护理记录)

enum CareEventKind: String, Codable, CaseIterable {
    case temperature
    case medication
    case cooling
    case note

    var label: String {
        switch self {
        case .temperature: return "体温"
        case .medication: return "用药"
        case .cooling: return "物理降温"
        case .note: return "备注"
        }
    }

    var symbolName: String {
        switch self {
        case .temperature: return "thermometer.variable"
        case .medication: return "pills.fill"
        case .cooling: return "drop.fill"
        case .note: return "square.and.pencil"
        }
    }
}

@Model
final class CareEvent {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var kindRaw: String = CareEventKind.note.rawValue
    var temperatureC: Double?
    var medicationName: String?
    var note: String?
    var episode: Episode?

    init(kind: CareEventKind, timestamp: Date = Date(), temperatureC: Double? = nil, medicationName: String? = nil, note: String? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.kindRaw = kind.rawValue
        self.temperatureC = temperatureC
        self.medicationName = medicationName
        self.note = note
    }

    var kind: CareEventKind {
        get { CareEventKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }
}
