import Foundation
import RemindCore

enum CommandHelpers {
  static func parsePriority(_ value: String) throws -> ReminderPriority {
    switch value.lowercased() {
    case "none":
      return .none
    case "low":
      return .low
    case "medium", "med":
      return .medium
    case "high":
      return .high
    default:
      throw RemindCoreError.operationFailed("Invalid priority: \"\(value)\" (use none|low|medium|high)")
    }
  }

  static func parseRecurrence(_ value: String) throws -> RecurrenceRule {
    let lower = value.lowercased().trimmingCharacters(in: .whitespaces)

    // Simple frequency keywords
    if let freq = parseFrequencyKeyword(lower) {
      return RecurrenceRule(frequency: freq)
    }

    // "N-frequency" pattern: "2-weekly", "3-monthly"
    let parts = lower.split(separator: "-", maxSplits: 1)
    if parts.count == 2, let interval = Int(parts[0]), interval > 0,
      let freq = parseFrequencyKeyword(String(parts[1]))
    {
      return RecurrenceRule(frequency: freq, interval: interval)
    }

    // "every N frequency" pattern: "every 3 months"
    let words = lower.split(separator: " ")
    if words.count == 3, words[0] == "every", let interval = Int(words[1]),
      let freq = parseFrequencyKeyword(String(words[2]))
    {
      return RecurrenceRule(frequency: freq, interval: interval)
    }
    if words.count == 2, words[0] == "every", let freq = parseFrequencyKeyword(String(words[1])) {
      return RecurrenceRule(frequency: freq)
    }

    throw RemindCoreError.operationFailed(
      "Invalid recurrence: \"\(value)\" (use daily|weekly|monthly|yearly or 2-weekly, \"every 3 months\")")
  }

  private static func parseFrequencyKeyword(_ value: String) -> RecurrenceFrequency? {
    switch value {
    case "daily", "day", "d", "days": return .daily
    case "weekly", "week", "w", "weeks": return .weekly
    case "monthly", "month", "m", "months": return .monthly
    case "yearly", "year", "y", "years": return .yearly
    default: return nil
    }
  }

  static func parseDaysOfWeek(_ value: String) throws -> [Int] {
    let dayMap: [String: Int] = [
      "sun": 1, "sunday": 1,
      "mon": 2, "monday": 2,
      "tue": 3, "tuesday": 3,
      "wed": 4, "wednesday": 4,
      "thu": 5, "thursday": 5,
      "fri": 6, "friday": 6,
      "sat": 7, "saturday": 7,
    ]
    let parts = value.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    var days: [Int] = []
    for part in parts {
      guard let day = dayMap[part] else {
        throw RemindCoreError.operationFailed(
          "Invalid day: \"\(part)\" (use mon,tue,wed,thu,fri,sat,sun)")
      }
      days.append(day)
    }
    return days
  }

  static func parseDaysOfMonth(_ value: String) throws -> [Int] {
    let parts = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    var days: [Int] = []
    for part in parts {
      guard let day = Int(part), (day >= -31 && day <= 31 && day != 0) else {
        throw RemindCoreError.operationFailed(
          "Invalid day of month: \"\(part)\" (use 1-31 or -1 for last)")
      }
      days.append(day)
    }
    return days
  }

  static func parseMonthsOfYear(_ value: String) throws -> [Int] {
    let monthMap: [String: Int] = [
      "jan": 1, "january": 1,
      "feb": 2, "february": 2,
      "mar": 3, "march": 3,
      "apr": 4, "april": 4,
      "may": 5,
      "jun": 6, "june": 6,
      "jul": 7, "july": 7,
      "aug": 8, "august": 8,
      "sep": 9, "september": 9,
      "oct": 10, "october": 10,
      "nov": 11, "november": 11,
      "dec": 12, "december": 12,
    ]
    let parts = value.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    var months: [Int] = []
    for part in parts {
      if let num = Int(part), num >= 1 && num <= 12 {
        months.append(num)
      } else if let month = monthMap[part] {
        months.append(month)
      } else {
        throw RemindCoreError.operationFailed(
          "Invalid month: \"\(part)\" (use jan-dec or 1-12)")
      }
    }
    return months
  }

  static func parseRecurrenceEnd(_ value: String) throws -> (date: Date?, count: Int?) {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    // Count pattern: "10x"
    if trimmed.hasSuffix("x"), let count = Int(trimmed.dropLast()) {
      guard count > 0 else {
        throw RemindCoreError.operationFailed("Recurrence count must be positive")
      }
      return (date: nil, count: count)
    }
    // Date pattern
    if let date = DateParsing.parseUserDate(trimmed) {
      return (date: date, count: nil)
    }
    throw RemindCoreError.operationFailed(
      "Invalid recurrence end: \"\(value)\" (use a date or Nx for count, e.g. 10x)")
  }

  static func buildRecurrenceRule(
    base: RecurrenceRule,
    daysOfWeek: [Int]? = nil,
    daysOfMonth: [Int]? = nil,
    monthsOfYear: [Int]? = nil,
    endDate: Date? = nil,
    endCount: Int? = nil
  ) -> RecurrenceRule {
    RecurrenceRule(
      frequency: base.frequency,
      interval: base.interval,
      daysOfTheWeek: daysOfWeek ?? base.daysOfTheWeek,
      daysOfTheMonth: daysOfMonth ?? base.daysOfTheMonth,
      monthsOfTheYear: monthsOfYear ?? base.monthsOfTheYear,
      weeksOfTheYear: base.weeksOfTheYear,
      daysOfTheYear: base.daysOfTheYear,
      setPositions: base.setPositions,
      endDate: endDate ?? base.endDate,
      endOccurrenceCount: endCount ?? base.endOccurrenceCount
    )
  }

  static func parseDueDate(_ value: String) throws -> Date {
    guard let date = DateParsing.parseUserDate(value) else {
      throw RemindCoreError.invalidDate(value)
    }
    return date
  }

  static func parseTimeZone(_ value: String) throws -> String {
    guard TimeZone(identifier: value) != nil else {
      throw RemindCoreError.operationFailed(
        "Invalid timezone: \"\(value)\" (use IANA identifier, e.g. America/New_York)")
    }
    return value
  }

  static func parseAlarm(_ value: String) throws -> ReminderAlarm {
    let trimmed = value.trimmingCharacters(in: .whitespaces)

    // Relative offsets: -15m, -1h, -1d, 0
    if trimmed == "0" {
      return ReminderAlarm(relativeOffset: 0)
    }

    let lower = trimmed.lowercased()
    if lower.hasPrefix("-") || lower.hasPrefix("+") {
      let sign: Double = lower.hasPrefix("-") ? -1 : 1
      let numStr = String(lower.dropFirst())

      if numStr.hasSuffix("m"), let mins = Double(numStr.dropLast()) {
        return ReminderAlarm(relativeOffset: sign * mins * 60)
      }
      if numStr.hasSuffix("h"), let hrs = Double(numStr.dropLast()) {
        return ReminderAlarm(relativeOffset: sign * hrs * 3600)
      }
      if numStr.hasSuffix("d"), let days = Double(numStr.dropLast()) {
        return ReminderAlarm(relativeOffset: sign * days * 86400)
      }
    }

    // Absolute date
    if let date = DateParsing.parseUserDate(trimmed) {
      return ReminderAlarm(absoluteDate: date)
    }

    throw RemindCoreError.operationFailed(
      "Invalid alarm: \"\(value)\" (use -15m, -1h, -1d, 0, or a date)")
  }
}
