import Foundation

@testable import RemindCore

actor MockReminderStore: ReminderStoreProtocol {
  var storedLists: [ReminderList]
  var storedReminders: [ReminderItem]
  var defaultList: String?
  var accessGranted: Bool
  private var nextID: Int = 100

  init(
    lists: [ReminderList] = [],
    reminders: [ReminderItem] = [],
    defaultList: String? = "Home",
    accessGranted: Bool = true
  ) {
    self.storedLists = lists
    self.storedReminders = reminders
    self.defaultList = defaultList
    self.accessGranted = accessGranted
  }

  func requestAccess() async throws {
    if !accessGranted {
      throw RemindCoreError.accessDenied
    }
  }

  func lists() async -> [ReminderList] {
    storedLists
  }

  func defaultListName() -> String? {
    defaultList
  }

  func reminders(in listName: String?) async throws -> [ReminderItem] {
    if let listName {
      guard storedLists.contains(where: { $0.title == listName }) else {
        throw RemindCoreError.listNotFound(listName)
      }
      return storedReminders.filter { $0.listName == listName }
    }
    return storedReminders
  }

  func createList(name: String) async throws -> ReminderList {
    let list = ReminderList(id: "list-\(nextID)", title: name)
    nextID += 1
    storedLists.append(list)
    return list
  }

  func renameList(oldName: String, newName: String) async throws {
    guard let index = storedLists.firstIndex(where: { $0.title == oldName }) else {
      throw RemindCoreError.listNotFound(oldName)
    }
    storedLists[index] = ReminderList(id: storedLists[index].id, title: newName)
  }

  func deleteList(name: String) async throws {
    guard let index = storedLists.firstIndex(where: { $0.title == name }) else {
      throw RemindCoreError.listNotFound(name)
    }
    storedLists.remove(at: index)
  }

  func createReminder(_ draft: ReminderDraft, listName: String) async throws -> ReminderItem {
    guard storedLists.contains(where: { $0.title == listName }) else {
      throw RemindCoreError.listNotFound(listName)
    }
    let listID = storedLists.first(where: { $0.title == listName })!.id
    let item = ReminderItem(
      id: "reminder-\(nextID)",
      title: draft.title,
      notes: draft.notes,
      isCompleted: false,
      completionDate: nil,
      priority: draft.priority,
      dueDate: draft.dueDate,
      startDate: draft.startDate,
      timeZone: draft.timeZone,
      recurrence: draft.recurrence,
      listID: listID,
      listName: listName
    )
    nextID += 1
    storedReminders.append(item)
    return item
  }

  func updateReminder(id: String, update: ReminderUpdate) async throws -> ReminderItem {
    guard let index = storedReminders.firstIndex(where: { $0.id == id }) else {
      throw RemindCoreError.reminderNotFound(id)
    }
    let existing = storedReminders[index]

    let newDueDate: Date?
    if let dueDateUpdate = update.dueDate {
      newDueDate = dueDateUpdate
    } else {
      newDueDate = existing.dueDate
    }

    let newRecurrence: RecurrenceFrequency?
    if let recurrenceUpdate = update.recurrence {
      newRecurrence = recurrenceUpdate
    } else {
      newRecurrence = existing.recurrence
    }

    let newStartDate: Date?
    if let startDateUpdate = update.startDate {
      newStartDate = startDateUpdate
    } else {
      newStartDate = existing.startDate
    }

    let newTimeZone: String?
    if let timeZoneUpdate = update.timeZone {
      newTimeZone = timeZoneUpdate
    } else {
      newTimeZone = existing.timeZone
    }

    let newListName = update.listName ?? existing.listName
    let newListID: String
    if update.listName != nil {
      guard let list = storedLists.first(where: { $0.title == newListName }) else {
        throw RemindCoreError.listNotFound(newListName)
      }
      newListID = list.id
    } else {
      newListID = existing.listID
    }

    let updated = ReminderItem(
      id: existing.id,
      title: update.title ?? existing.title,
      notes: update.notes ?? existing.notes,
      isCompleted: update.isCompleted ?? existing.isCompleted,
      completionDate: existing.completionDate,
      priority: update.priority ?? existing.priority,
      dueDate: newDueDate,
      startDate: newStartDate,
      timeZone: newTimeZone,
      recurrence: newRecurrence,
      listID: newListID,
      listName: newListName
    )
    storedReminders[index] = updated
    return updated
  }

  func completeReminders(ids: [String]) async throws -> [ReminderItem] {
    var completed: [ReminderItem] = []
    for id in ids {
      guard let index = storedReminders.firstIndex(where: { $0.id == id }) else {
        throw RemindCoreError.reminderNotFound(id)
      }
      let existing = storedReminders[index]
      let updated = ReminderItem(
        id: existing.id,
        title: existing.title,
        notes: existing.notes,
        isCompleted: true,
        completionDate: Date(),
        priority: existing.priority,
        dueDate: existing.dueDate,
        startDate: existing.startDate,
        timeZone: existing.timeZone,
        recurrence: existing.recurrence,
        listID: existing.listID,
        listName: existing.listName
      )
      storedReminders[index] = updated
      completed.append(updated)
    }
    return completed
  }

  func deleteReminders(ids: [String]) async throws -> Int {
    var deleted = 0
    for id in ids {
      guard let index = storedReminders.firstIndex(where: { $0.id == id }) else {
        throw RemindCoreError.reminderNotFound(id)
      }
      storedReminders.remove(at: index)
      deleted += 1
    }
    return deleted
  }
}
