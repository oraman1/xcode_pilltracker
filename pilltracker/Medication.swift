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
    var dosesAvailable: Int? = nil
    var notes: String = ""
    var photoFilename: String? = nil
    var completions: Set<Date> = []

    init(
        id: UUID = UUID(),
        name: String,
        daysOfWeek: Set<Int>,
        times: [TimeOfDay],
        dose: String = "",
        dosesAvailable: Int? = nil,
        notes: String = "",
        photoFilename: String? = nil,
        completions: Set<Date> = []
    ) {
        self.id = id
        self.name = name
        self.daysOfWeek = daysOfWeek
        self.times = times.sorted()
        self.dose = dose
        self.dosesAvailable = dosesAvailable
        self.notes = notes
        self.photoFilename = photoFilename
        self.completions = completions
    }

    enum CodingKeys: String, CodingKey {
        case id, name, daysOfWeek, times, dose, dosesAvailable, notes, photoFilename, completions
        case hour, minute  // legacy single-time fields
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        daysOfWeek = try c.decode(Set<Int>.self, forKey: .daysOfWeek)
        dose = try c.decodeIfPresent(String.self, forKey: .dose) ?? ""
        dosesAvailable = try c.decodeIfPresent(Int.self, forKey: .dosesAvailable)
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
        try c.encodeIfPresent(dosesAvailable, forKey: .dosesAvailable)
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

    enum DoseStatus {
        case completed
        case missed
        case pending
    }

    func doseStatus(time: TimeOfDay, on day: Date, now: Date = Date()) -> DoseStatus {
        let doseDate = time.date(on: day)
        if completions.contains(doseDate) { return .completed }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDoseDay = calendar.startOfDay(for: day)

        // Any uncompleted dose on a past day is missed — the day is over.
        if startOfDoseDay < startOfToday { return .missed }

        // For doses on today: missed once a later same-day dose has come due.
        if calendar.isDate(day, inSameDayAs: now) {
            for t in times.sorted() where t > time {
                if t.date(on: day) <= now { return .missed }
            }
        }

        return .pending
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

    /// Average doses per calendar day, factoring in scheduled days of the week.
    var averageDosesPerDay: Double {
        guard !daysOfWeek.isEmpty, !times.isEmpty else { return 0 }
        return Double(times.count) * Double(daysOfWeek.count) / 7.0
    }

    /// Days of medication remaining at the current schedule, if supply is being tracked.
    var daysRemaining: Double? {
        guard let supply = dosesAvailable else { return nil }
        guard averageDosesPerDay > 0 else { return nil }
        return Double(max(0, supply)) / averageDosesPerDay
    }

    /// Warning text shown when fewer than 5 days of medication remain.
    var lowSupplyMessage: String? {
        guard let days = daysRemaining else { return nil }
        guard days < 5 else { return nil }
        if (dosesAvailable ?? 0) <= 0 {
            return "Out of medication — order now"
        }
        let dayCount = Int(days.rounded(.down))
        if dayCount == 0 {
            return "Less than 1 day left — order now"
        }
        return "\(dayCount) day\(dayCount == 1 ? "" : "s") left — order more"
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
