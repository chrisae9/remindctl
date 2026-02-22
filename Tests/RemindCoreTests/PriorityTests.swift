import Testing

@testable import RemindCore

@MainActor
struct PriorityTests {
  @Test("EventKit priority mapping")
  func mapping() {
    #expect(ReminderPriority(eventKitValue: 0) == .none)
    #expect(ReminderPriority(eventKitValue: 1) == .high)
    #expect(ReminderPriority(eventKitValue: 5) == .medium)
    #expect(ReminderPriority(eventKitValue: 9) == .low)
    #expect(ReminderPriority.high.eventKitValue == 1)
    #expect(ReminderPriority.medium.eventKitValue == 5)
    #expect(ReminderPriority.low.eventKitValue == 9)
  }

  @Test("RecurrenceFrequency cases")
  func recurrenceCases() {
    #expect(RecurrenceFrequency.allCases.count == 4)
    #expect(RecurrenceFrequency.daily.rawValue == "daily")
    #expect(RecurrenceFrequency.weekly.rawValue == "weekly")
    #expect(RecurrenceFrequency.monthly.rawValue == "monthly")
    #expect(RecurrenceFrequency.yearly.rawValue == "yearly")
  }

  @Test("ReminderItem includes recurrence in JSON")
  func recurrenceInItem() {
    let item = ReminderItem(
      id: "1",
      title: "Test",
      notes: nil,
      isCompleted: false,
      completionDate: nil,
      priority: .none,
      dueDate: nil,
      recurrence: .weekly,
      listID: "a",
      listName: "Home"
    )
    #expect(item.recurrence == .weekly)

    let noRecurrence = ReminderItem(
      id: "2",
      title: "Test2",
      notes: nil,
      isCompleted: false,
      completionDate: nil,
      priority: .none,
      dueDate: nil,
      listID: "a",
      listName: "Home"
    )
    #expect(noRecurrence.recurrence == nil)
  }
}
