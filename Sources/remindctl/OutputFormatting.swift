import Foundation
import RemindCore

enum OutputFormat {
  case standard
  case plain
  case json
  case quiet
}

struct ListSummary: Codable, Sendable, Equatable {
  let id: String
  let title: String
  let reminderCount: Int
  let overdueCount: Int
}

struct AuthorizationSummary: Codable, Sendable, Equatable {
  let status: String
  let authorized: Bool
}

enum OutputRenderer {
  static func printReminders(_ reminders: [ReminderItem], format: OutputFormat) {
    switch format {
    case .standard:
      printRemindersStandard(reminders)
    case .plain:
      printRemindersPlain(reminders)
    case .json:
      printJSON(reminders)
    case .quiet:
      Swift.print(reminders.count)
    }
  }

  static func printLists(_ summaries: [ListSummary], format: OutputFormat) {
    switch format {
    case .standard:
      printListsStandard(summaries)
    case .plain:
      printListsPlain(summaries)
    case .json:
      printJSON(summaries)
    case .quiet:
      Swift.print(summaries.count)
    }
  }

  static func printReminder(_ reminder: ReminderItem, format: OutputFormat) {
    switch format {
    case .standard:
      let due = reminder.dueDate.map { DateParsing.formatDisplay($0) } ?? "no due date"
      let start = reminder.startDate.map { " start=\(DateParsing.formatDisplay($0))" } ?? ""
      let tz = reminder.timeZone.map { " tz=\($0)" } ?? ""
      let recurrence = reminder.recurrence.map { " repeats=\(formatRecurrence($0))" } ?? ""
      let alarms = reminder.alarms.isEmpty ? "" : " alarms=[\(reminder.alarms.map(formatAlarm).joined(separator: ", "))]"
      Swift.print("✓ \(reminder.title) [\(reminder.listName)] — \(due)\(start)\(tz)\(recurrence)\(alarms)")
    case .plain:
      Swift.print(plainLine(for: reminder))
    case .json:
      printJSON(reminder)
    case .quiet:
      break
    }
  }

  static func printDeleteResult(_ count: Int, format: OutputFormat) {
    switch format {
    case .standard:
      Swift.print("Deleted \(count) reminder(s)")
    case .plain:
      Swift.print("\(count)")
    case .json:
      let payload = ["deleted": count]
      printJSON(payload)
    case .quiet:
      break
    }
  }

  static func printAuthorizationStatus(_ status: RemindersAuthorizationStatus, format: OutputFormat) {
    switch format {
    case .standard:
      Swift.print("Reminders access: \(status.displayName)")
    case .plain:
      Swift.print(status.rawValue)
    case .json:
      printJSON(AuthorizationSummary(status: status.rawValue, authorized: status.isAuthorized))
    case .quiet:
      Swift.print(status.isAuthorized ? "1" : "0")
    }
  }

  private static func printRemindersStandard(_ reminders: [ReminderItem]) {
    let sorted = ReminderFiltering.sort(reminders)
    guard !sorted.isEmpty else {
      Swift.print("No reminders found")
      return
    }
    for (index, reminder) in sorted.enumerated() {
      let status = reminder.isCompleted ? "x" : " "
      let due = reminder.dueDate.map { DateParsing.formatDisplay($0) } ?? "no due date"
      let priority = reminder.priority == .none ? "" : " priority=\(reminder.priority.rawValue)"
      let start = reminder.startDate.map { " start=\(DateParsing.formatDisplay($0))" } ?? ""
      let tz = reminder.timeZone.map { " tz=\($0)" } ?? ""
      let recurrence = reminder.recurrence.map { " repeats=\(formatRecurrence($0))" } ?? ""
      let alarms = reminder.alarms.isEmpty ? "" : " alarms=[\(reminder.alarms.map(formatAlarm).joined(separator: ", "))]"
      Swift.print(
        "[\(index + 1)] [\(status)] \(reminder.title) [\(reminder.listName)] — \(due)\(priority)\(start)\(tz)\(recurrence)\(alarms)"
      )
    }
  }

  private static func printRemindersPlain(_ reminders: [ReminderItem]) {
    let sorted = ReminderFiltering.sort(reminders)
    for reminder in sorted {
      Swift.print(plainLine(for: reminder))
    }
  }

  private static func plainLine(for reminder: ReminderItem) -> String {
    let due = reminder.dueDate.map { isoFormatter().string(from: $0) } ?? ""
    return [
      reminder.id,
      reminder.listName,
      reminder.isCompleted ? "1" : "0",
      reminder.priority.rawValue,
      due,
      reminder.title,
    ].joined(separator: "\t")
  }

  private static func printListsStandard(_ summaries: [ListSummary]) {
    guard !summaries.isEmpty else {
      Swift.print("No reminder lists found")
      return
    }
    for summary in summaries.sorted(by: { $0.title < $1.title }) {
      let overdue = summary.overdueCount > 0 ? " (\(summary.overdueCount) overdue)" : ""
      Swift.print("\(summary.title) — \(summary.reminderCount) reminders\(overdue)")
    }
  }

  private static func printListsPlain(_ summaries: [ListSummary]) {
    for summary in summaries.sorted(by: { $0.title < $1.title }) {
      Swift.print("\(summary.title)\t\(summary.reminderCount)\t\(summary.overdueCount)")
    }
  }

  private static func printJSON<T: Encodable>(_ payload: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    encoder.dateEncodingStrategy = .iso8601
    do {
      let data = try encoder.encode(payload)
      if let json = String(data: data, encoding: .utf8) {
        Swift.print(json)
      }
    } catch {
      Swift.print("Failed to encode JSON: \(error)")
    }
  }

  private static func formatRecurrence(_ rule: RecurrenceRule) -> String {
    var desc = rule.interval > 1 ? "\(rule.interval)-\(rule.frequency.rawValue)" : rule.frequency.rawValue
    if let days = rule.daysOfTheWeek {
      let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
      desc += " on=" + days.map { $0 >= 1 && $0 <= 7 ? names[$0] : "\($0)" }.joined(separator: ",")
    }
    if let days = rule.daysOfTheMonth {
      desc += " days=" + days.map(String.init).joined(separator: ",")
    }
    if let months = rule.monthsOfTheYear {
      desc += " months=" + months.map(String.init).joined(separator: ",")
    }
    if let endDate = rule.endDate {
      desc += " until=\(DateParsing.formatDisplay(endDate))"
    }
    if let count = rule.endOccurrenceCount {
      desc += " \(count)x"
    }
    return desc
  }

  private static func formatAlarm(_ alarm: ReminderAlarm) -> String {
    switch alarm.type {
    case .absolute(let date):
      return DateParsing.formatDisplay(date)
    case .relative(let offset):
      let secs = Int(offset)
      if secs == 0 { return "0" }
      let absSecs = abs(secs)
      let sign = secs < 0 ? "-" : "+"
      if absSecs % 86400 == 0 { return "\(sign)\(absSecs / 86400)d" }
      if absSecs % 3600 == 0 { return "\(sign)\(absSecs / 3600)h" }
      return "\(sign)\(absSecs / 60)m"
    case .location(let loc):
      let proximity = loc.proximity == .enter ? "enter" : "leave"
      return "\(loc.title):\(loc.latitude),\(loc.longitude):\(Int(loc.radius)):\(proximity)"
    }
  }

  private static func isoFormatter() -> ISO8601DateFormatter {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }
}
