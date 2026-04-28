import Foundation

struct TimeOfDay: Codable, Hashable, Identifiable, Comparable {
    var id: UUID = UUID()
    var hour: Int
    var minute: Int

    init(id: UUID = UUID(), hour: Int, minute: Int) {
        self.id = id
        self.hour = hour
        self.minute = minute
    }

    enum CodingKeys: String, CodingKey { case id, hour, minute }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        hour = try c.decode(Int.self, forKey: .hour)
        minute = try c.decode(Int.self, forKey: .minute)
    }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
        return lhs.minute < rhs.minute
    }

    func date(on day: Date) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Calendar.current.startOfDay(for: day)) ?? day
    }
}

struct Medication: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var daysOfWeek: Set<Int>
    var times: [TimeOfDay]
    var dose: String = ""
    var notes: String = ""
    var photoFilename: String? = nil
    var completions: Set<Date> = []

    init(
        id: UUID = UUID(),
        name: String,
        daysOfWeek: Set<Int>,
        times: [TimeOfDay],
        dose: String = "",
        notes: String = "",
        photoFilename: String? = nil,
        completions: Set<Date> = []
    ) {
        self.id = id
        self.name = name
        self.daysOfWeek = daysOfWeek
        self.times = times.sorted()
        self.dose = dose
        self.notes = notes
        self.photoFilename = photoFilename
        self.completions = completions
    }

    enum CodingKeys: String, CodingKey {
        case id, name, daysOfWeek, times, dose, notes, photoFilename, completions
        case hour, minute  // legacy single-time fields
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        daysOfWeek = try c.decode(Set<Int>.self, forKey: .daysOfWeek)
        dose = try c.decodeIfPresent(String.self, forKey: .dose) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        photoFilename = try c.decodeIfPresent(String.self, forKey: .photoFilename)

        if let times = try c.decodeIfPresent([TimeOfDay].self, forKey: .times) {
            self.times = times.sorted()
            self.completions = try c.decodeIfPresent(Set<Date>.self, forKey: .completions) ?? []
        } else {
            // Legacy: single hour/minute. Migrate completions (start-of-day → that single time).
            let h = try c.decodeIfPresent(Int.self, forKey: .hour) ?? 9
            let m = try c.decodeIfPresent(Int.self, forKey: .minute) ?? 0
            let migratedTime = TimeOfDay(hour: h, minute: m)
            self.times = [migratedTime]
            let oldCompletions = try c.decodeIfPresent(Set<Date>.self, forKey: .completions) ?? []
            self.completions = Set(oldCompletions.map { migratedTime.date(on: $0) })
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(daysOfWeek, forKey: .daysOfWeek)
        try c.encode(times, forKey: .times)
        try c.encode(dose, forKey: .dose)
        try c.encode(notes, forKey: .notes)
        try c.encodeIfPresent(photoFilename, forKey: .photoFilename)
        try c.encode(completions, forKey: .completions)
    }

    func isScheduledToday(now: Date = Date()) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: now)
        return daysOfWeek.contains(weekday)
    }

    func isCompleted(time: TimeOfDay, on day: Date) -> Bool {
        completions.contains(time.date(on: day))
    }

    func isFullyCompleted(on day: Date) -> Bool {
        guard !times.isEmpty else { return false }
        return times.allSatisfy { isCompleted(time: $0, on: day) }
    }

    /// The next scheduled dose at or after `now` that hasn't been completed yet.
    func nextDue(now: Date = Date()) -> (day: Date, time: TimeOfDay)? {
        guard !daysOfWeek.isEmpty, !times.isEmpty else { return nil }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let sortedTimes = times.sorted()

        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else { break }
            let weekday = calendar.component(.weekday, from: day)
            guard daysOfWeek.contains(weekday) else { continue }
            for time in sortedTimes {
                let doseDate = time.date(on: day)
                if completions.contains(doseDate) { continue }
                return (day, time)
            }
        }
        return nil
    }

    func currentStreak(now: Date = Date()) -> Int {
        guard !daysOfWeek.isEmpty, !times.isEmpty else { return 0 }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        var streak = 0
        var cursor = startOfToday
        var isToday = true

        for _ in 0..<(366 * 2) {
            let weekday = calendar.component(.weekday, from: cursor)
            if daysOfWeek.contains(weekday) {
                if isFullyCompleted(on: cursor) {
                    streak += 1
                } else if isToday {
                    // Today's doses might still be pending; don't break the streak.
                } else {
                    break
                }
            }
            isToday = false
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}

enum Weekday: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}
