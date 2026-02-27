import Foundation

/// A parsed date with metadata about whether the user supplied a time component.
public struct ParsedDate: Sendable {
  public let date: Date
  /// True when the input was date-only (no hour/minute), e.g. "2026-01-16", "today", "tomorrow".
  public let isDateOnly: Bool

  public init(date: Date, isDateOnly: Bool) {
    self.date = date
    self.isDateOnly = isDateOnly
  }
}

public enum DateParsing {
  // MARK: - Public parse API

  /// Parse a user-supplied date string and return the date along with whether it was date-only.
  public static func parseUserDateExtended(
    _ input: String,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> ParsedDate? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()

    // Relative keywords → date-only (no time component intended)
    if let date = parseRelativeDate(lower, now: now, calendar: calendar) {
      return ParsedDate(date: date, isDateOnly: true)
    }

    // Full ISO 8601 with time → timed
    if let iso = isoFormatterWithFraction.date(from: trimmed) ?? isoFormatterNoFraction.date(from: trimmed) {
      return ParsedDate(date: iso, isDateOnly: false)
    }

    // Named format strings
    for (formatter, isDateOnly) in cachedDateFormatterPairs {
      if let date = formatter.date(from: trimmed) {
        return ParsedDate(date: date, isDateOnly: isDateOnly)
      }
    }

    return nil
  }

  /// Parse a user-supplied date string, returning just the `Date` (drops isDateOnly metadata).
  public static func parseUserDate(
    _ input: String,
    now: Date = Date(),
    calendar: Calendar = .current
  ) -> Date? {
    parseUserDateExtended(input, now: now, calendar: calendar)?.date
  }

  // MARK: - Display formatting

  public static func formatDisplay(_ date: Date, calendar: Calendar = .current) -> String {
    displayFormatter.timeZone = calendar.timeZone
    return displayFormatter.string(from: date)
  }

  /// Format a date without a time component (for all-day reminders).
  public static func formatDateOnly(_ date: Date, calendar: Calendar = .current) -> String {
    dateOnlyFormatter.timeZone = calendar.timeZone
    return dateOnlyFormatter.string(from: date)
  }

  // MARK: - Private helpers

  private static func parseRelativeDate(_ input: String, now: Date, calendar: Calendar) -> Date? {
    switch input {
    case "today":
      return calendar.startOfDay(for: now)
    case "tomorrow":
      return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
    case "yesterday":
      return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
    case "now":
      return now
    default:
      return nil
    }
  }

  private nonisolated(unsafe) static let isoFormatterWithFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private nonisolated(unsafe) static let isoFormatterNoFraction: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  // Each tuple: (formatter, isDateOnly)
  private static let cachedDateFormatterPairs: [(DateFormatter, Bool)] = {
    let specs: [(String, Bool)] = [
      ("yyyy-MM-dd", true),
      ("yyyy-MM-dd HH:mm", false),
      ("yyyy-MM-dd HH:mm:ss", false),
      ("MM/dd/yyyy", true),
      ("MM/dd/yyyy HH:mm", false),
      ("dd-MM-yy", true),
      ("dd-MM-yyyy", true),
    ]
    return specs.map { format, isDateOnly in
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone.current
      formatter.dateFormat = format
      return (formatter, isDateOnly)
    }
  }()

  private static let displayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  private static let dateOnlyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }()
}
