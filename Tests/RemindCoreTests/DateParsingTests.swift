import Foundation
import Testing

@testable import RemindCore

@MainActor
struct DateParsingTests {
  private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
  }()

  @Test("Relative date parsing")
  func relativeDates() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let today = DateParsing.parseUserDate("today", now: now, calendar: calendar)
    let tomorrow = DateParsing.parseUserDate("tomorrow", now: now, calendar: calendar)
    let yesterday = DateParsing.parseUserDate("yesterday", now: now, calendar: calendar)

    #expect(today == calendar.startOfDay(for: now))
    #expect(tomorrow == calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)))
    #expect(yesterday == calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)))
  }

  @Test("ISO 8601 parsing")
  func isoParsing() {
    let input = "2026-01-03T12:34:56Z"
    let parsed = DateParsing.parseUserDate(input)
    #expect(parsed != nil)
  }

  @Test("Formatted date parsing")
  func formattedParsing() {
    let input = "2026-01-03 10:30"
    let parsed = DateParsing.parseUserDate(input)
    #expect(parsed != nil)
  }

  @Test("Format display output")
  func displayFormatting() {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let output = DateParsing.formatDisplay(date, calendar: calendar)
    #expect(output.isEmpty == false)
  }

  // MARK: - ParsedDate / isDateOnly

  @Test("Date-only formats are marked isDateOnly=true")
  func dateOnlyFormats() {
    let dateOnly = ["2026-01-16", "01/16/2026", "16-01-2026", "16-01-26", "today", "tomorrow"]
    for input in dateOnly {
      let parsed = DateParsing.parseUserDateExtended(input)
      #expect(parsed != nil, "Expected '\(input)' to parse")
      #expect(parsed?.isDateOnly == true, "Expected '\(input)' to be date-only")
    }
  }

  @Test("Timed formats are marked isDateOnly=false")
  func timedFormats() {
    let timed = [
      "2026-01-16 09:00",
      "2026-01-16 09:00:00",
      "01/16/2026 09:00",
      "2026-01-03T12:34:56Z",
    ]
    for input in timed {
      let parsed = DateParsing.parseUserDateExtended(input)
      #expect(parsed != nil, "Expected '\(input)' to parse")
      #expect(parsed?.isDateOnly == false, "Expected '\(input)' to NOT be date-only")
    }
  }

  @Test("parseUserDate still works for backward compat")
  func backwardCompat() {
    let result = DateParsing.parseUserDate("2026-01-16")
    #expect(result != nil)
  }

  @Test("formatDateOnly omits time component")
  func formatDateOnlyOutput() {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let output = DateParsing.formatDateOnly(date, calendar: calendar)
    #expect(output.isEmpty == false)
    // Should not contain a colon (time separator)
    #expect(!output.contains(":"))
  }
}
