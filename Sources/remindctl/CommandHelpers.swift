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

  static func parseRecurrence(_ value: String) throws -> RecurrenceFrequency {
    switch value.lowercased() {
    case "daily", "day", "d":
      return .daily
    case "weekly", "week", "w":
      return .weekly
    case "monthly", "month", "m":
      return .monthly
    case "yearly", "year", "y":
      return .yearly
    default:
      throw RemindCoreError.operationFailed(
        "Invalid recurrence: \"\(value)\" (use daily|weekly|monthly|yearly)")
    }
  }

  static func parseDueDate(_ value: String) throws -> Date {
    guard let date = DateParsing.parseUserDate(value) else {
      throw RemindCoreError.invalidDate(value)
    }
    return date
  }
}
