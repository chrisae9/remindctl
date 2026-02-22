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
    let draft = ReminderDraft(
      title: "New task", notes: "some notes",
      dueDate: Date(), priority: .medium, recurrence: .weekly
    )
    let item = try await store.createReminder(draft, listName: "Home")
    #expect(item.title == "New task")
    #expect(item.notes == "some notes")
    #expect(item.priority == .medium)
    #expect(item.recurrence == .weekly)
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
    let update = ReminderUpdate(recurrence: .some(.daily))
    let updated = try await store.updateReminder(id: "r1", update: update)
    #expect(updated.recurrence == .daily)
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
}
