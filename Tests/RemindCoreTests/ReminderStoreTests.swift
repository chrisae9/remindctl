import Foundation
import Testing

@testable import RemindCore

@MainActor
struct ReminderStoreTests {
  private func sampleStore() -> MockReminderStore {
    let lists = [
      ReminderList(id: "list-1", title: "Home"),
      ReminderList(id: "list-2", title: "Work"),
    ]
    let reminders = [
      ReminderItem(
        id: "r1", title: "Buy milk", notes: "2% only",
        isCompleted: false, completionDate: nil, priority: .none,
        dueDate: Date(timeIntervalSince1970: 1_700_000_000),
        listID: "list-1", listName: "Home"
      ),
      ReminderItem(
        id: "r2", title: "Finish report", notes: nil,
        isCompleted: false, completionDate: nil, priority: .high,
        dueDate: nil, listID: "list-2", listName: "Work"
      ),
      ReminderItem(
        id: "r3", title: "Done task", notes: nil,
        isCompleted: true, completionDate: Date(),
        priority: .none, dueDate: nil,
        listID: "list-1", listName: "Home"
      ),
    ]
    return MockReminderStore(lists: lists, reminders: reminders)
  }

  // MARK: - Access

  @Test("Request access succeeds when granted")
  func accessGranted() async throws {
    let store = sampleStore()
    try await store.requestAccess()
  }

  @Test("Request access throws when denied")
  func accessDenied() async {
    let store = MockReminderStore(accessGranted: false)
    do {
      try await store.requestAccess()
      Issue.record("Expected access denied error")
    } catch {
      #expect(error is RemindCoreError)
    }
  }

  // MARK: - Lists

  @Test("Lists returns all lists")
  func listsAll() async {
    let store = sampleStore()
    let lists = await store.lists()
    #expect(lists.count == 2)
  }

  @Test("Default list name")
  func defaultList() async {
    let store = sampleStore()
    let name = await store.defaultListName()
    #expect(name == "Home")
  }

  @Test("Create list")
  func createList() async throws {
    let store = sampleStore()
    let list = try await store.createList(name: "Projects")
    #expect(list.title == "Projects")
    let allLists = await store.lists()
    #expect(allLists.count == 3)
  }

  @Test("Rename list")
  func renameList() async throws {
    let store = sampleStore()
    try await store.renameList(oldName: "Home", newName: "Personal")
    let lists = await store.lists()
    #expect(lists.contains(where: { $0.title == "Personal" }))
    #expect(!lists.contains(where: { $0.title == "Home" }))
  }

  @Test("Rename nonexistent list throws")
  func renameNonexistent() async {
    let store = sampleStore()
    do {
      try await store.renameList(oldName: "Missing", newName: "X")
      Issue.record("Expected error")
    } catch {
      #expect(error is RemindCoreError)
    }
  }

  @Test("Delete list")
  func deleteList() async throws {
    let store = sampleStore()
    try await store.deleteList(name: "Work")
    let lists = await store.lists()
    #expect(lists.count == 1)
    #expect(lists.first?.title == "Home")
  }

  // MARK: - Reminders

  @Test("Fetch all reminders")
  func fetchAll() async throws {
    let store = sampleStore()
    let reminders = try await store.reminders(in: nil)
    #expect(reminders.count == 3)
  }

  @Test("Fetch reminders in specific list")
  func fetchByList() async throws {
    let store = sampleStore()
    let home = try await store.reminders(in: "Home")
    #expect(home.count == 2)
    let work = try await store.reminders(in: "Work")
    #expect(work.count == 1)
  }

  @Test("Fetch reminders in nonexistent list throws")
  func fetchMissingList() async {
    let store = sampleStore()
    do {
      _ = try await store.reminders(in: "Missing")
      Issue.record("Expected error")
    } catch {
      #expect(error is RemindCoreError)
    }
  }

  @Test("Create reminder")
  func createReminder() async throws {
    let store = sampleStore()
    let weeklyRule = RecurrenceRule(frequency: .weekly)
    let draft = ReminderDraft(
      title: "New task", notes: "some notes",
      dueDate: Date(), priority: .medium, recurrence: weeklyRule
    )
    let item = try await store.createReminder(draft, listName: "Home")
    #expect(item.title == "New task")
    #expect(item.notes == "some notes")
    #expect(item.priority == .medium)
    #expect(item.recurrence == weeklyRule)
    #expect(item.listName == "Home")
    #expect(!item.isCompleted)

    let all = try await store.reminders(in: nil)
    #expect(all.count == 4)
  }

  @Test("Create reminder in nonexistent list throws")
  func createInMissingList() async {
    let store = sampleStore()
    let draft = ReminderDraft(title: "X", notes: nil, dueDate: nil, priority: .none)
    do {
      _ = try await store.createReminder(draft, listName: "Missing")
      Issue.record("Expected error")
    } catch {
      #expect(error is RemindCoreError)
    }
  }

  @Test("Update reminder title and priority")
  func updateReminder() async throws {
    let store = sampleStore()
    let update = ReminderUpdate(title: "Buy oat milk", priority: .low)
    let updated = try await store.updateReminder(id: "r1", update: update)
    #expect(updated.title == "Buy oat milk")
    #expect(updated.priority == .low)
    #expect(updated.notes == "2% only")
  }

  @Test("Update reminder due date to nil")
  func clearDueDate() async throws {
    let store = sampleStore()
    let update = ReminderUpdate(dueDate: .some(nil))
    let updated = try await store.updateReminder(id: "r1", update: update)
    #expect(updated.dueDate == nil)
  }

  @Test("Update reminder recurrence")
  func updateRecurrence() async throws {
    let store = sampleStore()
    let dailyRule = RecurrenceRule(frequency: .daily)
    let update = ReminderUpdate(recurrence: .some(dailyRule))
    let updated = try await store.updateReminder(id: "r1", update: update)
    #expect(updated.recurrence == dailyRule)
  }

  @Test("Update reminder move to different list")
  func moveToList() async throws {
    let store = sampleStore()
    let update = ReminderUpdate(listName: "Work")
    let updated = try await store.updateReminder(id: "r1", update: update)
    #expect(updated.listName == "Work")
    #expect(updated.listID == "list-2")
  }

  @Test("Update nonexistent reminder throws")
  func updateMissing() async {
    let store = sampleStore()
    let update = ReminderUpdate(title: "X")
    do {
      _ = try await store.updateReminder(id: "missing", update: update)
      Issue.record("Expected error")
    } catch {
      #expect(error is RemindCoreError)
    }
  }

  // MARK: - Complete

  @Test("Complete reminders")
  func completeReminders() async throws {
    let store = sampleStore()
    let completed = try await store.completeReminders(ids: ["r1", "r2"])
    #expect(completed.count == 2)
    #expect(completed.allSatisfy { $0.isCompleted })

    let all = try await store.reminders(in: nil)
    let incomplete = all.filter { !$0.isCompleted }
    #expect(incomplete.isEmpty)
  }

  @Test("Complete nonexistent reminder throws")
  func completeMissing() async {
    let store = sampleStore()
    do {
      _ = try await store.completeReminders(ids: ["missing"])
      Issue.record("Expected error")
    } catch {
      #expect(error is RemindCoreError)
    }
  }

  // MARK: - Delete

  @Test("Delete reminders")
  func deleteReminders() async throws {
    let store = sampleStore()
    let count = try await store.deleteReminders(ids: ["r1"])
    #expect(count == 1)
    let all = try await store.reminders(in: nil)
    #expect(all.count == 2)
    #expect(!all.contains(where: { $0.id == "r1" }))
  }

  @Test("Delete nonexistent reminder throws")
  func deleteMissing() async {
    let store = sampleStore()
    do {
      _ = try await store.deleteReminders(ids: ["missing"])
      Issue.record("Expected error")
    } catch {
      #expect(error is RemindCoreError)
    }
  }

  // MARK: - Start Date & Timezone

  @Test("Create reminder with start date")
  func createWithStartDate() async throws {
    let store = sampleStore()
    let startDate = Date(timeIntervalSince1970: 1_700_000_000)
    let draft = ReminderDraft(
      title: "With start", notes: nil, dueDate: nil,
      startDate: startDate, priority: .none
    )
    let item = try await store.createReminder(draft, listName: "Home")
    #expect(item.startDate == startDate)
  }

  @Test("Create reminder with timezone")
  func createWithTimezone() async throws {
    let store = sampleStore()
    let draft = ReminderDraft(
      title: "With tz", notes: nil, dueDate: Date(),
      timeZone: "America/New_York", priority: .none
    )
    let item = try await store.createReminder(draft, listName: "Home")
    #expect(item.timeZone == "America/New_York")
  }

  @Test("Update reminder start date")
  func updateStartDate() async throws {
    let store = sampleStore()
    let newStart = Date(timeIntervalSince1970: 1_800_000_000)
    let update = ReminderUpdate(startDate: .some(newStart))
    let updated = try await store.updateReminder(id: "r1", update: update)
    #expect(updated.startDate == newStart)
  }

  @Test("Clear reminder start date")
  func clearStartDate() async throws {
    let store = sampleStore()
    // First set a start date
    let setUpdate = ReminderUpdate(startDate: .some(Date()))
    _ = try await store.updateReminder(id: "r1", update: setUpdate)
    // Then clear it
    let clearUpdate = ReminderUpdate(startDate: .some(nil))
    let updated = try await store.updateReminder(id: "r1", update: clearUpdate)
    #expect(updated.startDate == nil)
  }

  @Test("Update reminder timezone")
  func updateTimezone() async throws {
    let store = sampleStore()
    let update = ReminderUpdate(timeZone: .some("Europe/London"))
    let updated = try await store.updateReminder(id: "r1", update: update)
    #expect(updated.timeZone == "Europe/London")
  }

  @Test("Clear reminder timezone")
  func clearTimezone() async throws {
    let store = sampleStore()
    let setUpdate = ReminderUpdate(timeZone: .some("US/Pacific"))
    _ = try await store.updateReminder(id: "r1", update: setUpdate)
    let clearUpdate = ReminderUpdate(timeZone: .some(nil))
    let updated = try await store.updateReminder(id: "r1", update: clearUpdate)
    #expect(updated.timeZone == nil)
  }

  // MARK: - Enhanced Recurrence

  @Test("Create reminder with recurrence rule interval")
  func createWithRecurrenceInterval() async throws {
    let store = sampleStore()
    let rule = RecurrenceRule(frequency: .weekly, interval: 2)
    let draft = ReminderDraft(
      title: "Biweekly", notes: nil, dueDate: Date(), priority: .none, recurrence: rule
    )
    let item = try await store.createReminder(draft, listName: "Home")
    #expect(item.recurrence?.frequency == .weekly)
    #expect(item.recurrence?.interval == 2)
  }

  @Test("Create reminder with days of week")
  func createWithDaysOfWeek() async throws {
    let store = sampleStore()
    let rule = RecurrenceRule(frequency: .weekly, daysOfTheWeek: [2, 4, 6])
    let draft = ReminderDraft(
      title: "MWF", notes: nil, dueDate: Date(), priority: .none, recurrence: rule
    )
    let item = try await store.createReminder(draft, listName: "Home")
    #expect(item.recurrence?.daysOfTheWeek == [2, 4, 6])
  }

  @Test("Create reminder with end occurrence count")
  func createWithEndCount() async throws {
    let store = sampleStore()
    let rule = RecurrenceRule(frequency: .daily, endOccurrenceCount: 10)
    let draft = ReminderDraft(
      title: "Limited", notes: nil, dueDate: Date(), priority: .none, recurrence: rule
    )
    let item = try await store.createReminder(draft, listName: "Home")
    #expect(item.recurrence?.endOccurrenceCount == 10)
  }

  @Test("Clear recurrence rule")
  func clearRecurrenceRule() async throws {
    let store = sampleStore()
    let setUpdate = ReminderUpdate(recurrence: .some(RecurrenceRule(frequency: .daily)))
    _ = try await store.updateReminder(id: "r1", update: setUpdate)
    let clearUpdate = ReminderUpdate(recurrence: .some(nil))
    let updated = try await store.updateReminder(id: "r1", update: clearUpdate)
    #expect(updated.recurrence == nil)
  }

  // MARK: - Alarms

  @Test("Create reminder with relative alarm")
  func createWithRelativeAlarm() async throws {
    let store = sampleStore()
    let alarms = [ReminderAlarm(relativeOffset: -900)]
    let draft = ReminderDraft(
      title: "Alarmed", notes: nil, dueDate: Date(), priority: .none, alarms: alarms
    )
    let item = try await store.createReminder(draft, listName: "Home")
    #expect(item.alarms.count == 1)
    #expect(item.alarms[0] == ReminderAlarm(relativeOffset: -900))
  }

  @Test("Create reminder with multiple alarms")
  func createWithMultipleAlarms() async throws {
    let store = sampleStore()
    let alarms = [
      ReminderAlarm(relativeOffset: -900),
      ReminderAlarm(relativeOffset: -3600),
    ]
    let draft = ReminderDraft(
      title: "Multi alarm", notes: nil, dueDate: Date(), priority: .none, alarms: alarms
    )
    let item = try await store.createReminder(draft, listName: "Home")
    #expect(item.alarms.count == 2)
  }

  @Test("Update reminder alarms")
  func updateAlarms() async throws {
    let store = sampleStore()
    let alarms = [ReminderAlarm(relativeOffset: -1800)]
    let update = ReminderUpdate(alarms: .some(alarms))
    let updated = try await store.updateReminder(id: "r1", update: update)
    #expect(updated.alarms.count == 1)
    #expect(updated.alarms[0] == ReminderAlarm(relativeOffset: -1800))
  }

  @Test("Clear reminder alarms")
  func clearAlarms() async throws {
    let store = sampleStore()
    let setUpdate = ReminderUpdate(alarms: .some([ReminderAlarm(relativeOffset: -900)]))
    _ = try await store.updateReminder(id: "r1", update: setUpdate)
    let clearUpdate = ReminderUpdate(alarms: .some(nil))
    let updated = try await store.updateReminder(id: "r1", update: clearUpdate)
    #expect(updated.alarms.isEmpty)
  }

  @Test("Create reminder with absolute alarm")
  func createWithAbsoluteAlarm() async throws {
    let store = sampleStore()
    let alarmDate = Date(timeIntervalSince1970: 1_700_000_000)
    let alarms = [ReminderAlarm(absoluteDate: alarmDate)]
    let draft = ReminderDraft(
      title: "Abs alarm", notes: nil, dueDate: nil, priority: .none, alarms: alarms
    )
    let item = try await store.createReminder(draft, listName: "Home")
    #expect(item.alarms.count == 1)
    #expect(item.alarms[0] == ReminderAlarm(absoluteDate: alarmDate))
  }

  // MARK: - Location Alarms

  @Test("Create reminder with location alarm")
  func createWithLocationAlarm() async throws {
    let store = sampleStore()
    let loc = LocationAlarm(
      title: "Home", latitude: 37.7749, longitude: -122.4194,
      radius: 100, proximity: .enter
    )
    let alarms = [ReminderAlarm(location: loc)]
    let draft = ReminderDraft(
      title: "Location", notes: nil, dueDate: nil, priority: .none, alarms: alarms
    )
    let item = try await store.createReminder(draft, listName: "Home")
    #expect(item.alarms.count == 1)
    #expect(item.alarms[0] == ReminderAlarm(location: loc))
  }

  @Test("Create reminder with mixed alarms")
  func createWithMixedAlarms() async throws {
    let store = sampleStore()
    let loc = LocationAlarm(
      title: "Office", latitude: 40.7128, longitude: -74.006,
      radius: 200, proximity: .leave
    )
    let alarms = [
      ReminderAlarm(relativeOffset: -900),
      ReminderAlarm(location: loc),
    ]
    let draft = ReminderDraft(
      title: "Mixed", notes: nil, dueDate: Date(), priority: .none, alarms: alarms
    )
    let item = try await store.createReminder(draft, listName: "Home")
    #expect(item.alarms.count == 2)
    #expect(item.alarms[0] == ReminderAlarm(relativeOffset: -900))
    #expect(item.alarms[1] == ReminderAlarm(location: loc))
  }

  @Test("Update reminder with location alarm")
  func updateWithLocationAlarm() async throws {
    let store = sampleStore()
    let loc = LocationAlarm(
      title: "Gym", latitude: 34.0522, longitude: -118.2437,
      radius: 150, proximity: .enter
    )
    let update = ReminderUpdate(alarms: .some([ReminderAlarm(location: loc)]))
    let updated = try await store.updateReminder(id: "r1", update: update)
    #expect(updated.alarms.count == 1)
    #expect(updated.alarms[0] == ReminderAlarm(location: loc))
  }
}
