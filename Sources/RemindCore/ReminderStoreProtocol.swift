import Foundation

public protocol ReminderStoreProtocol: Actor {
  func requestAccess() async throws
  func lists() async -> [ReminderList]
  func defaultListName() -> String?
  func reminders(in listName: String?) async throws -> [ReminderItem]
  func createList(name: String) async throws -> ReminderList
  func renameList(oldName: String, newName: String) async throws
  func deleteList(name: String) async throws
  func createReminder(_ draft: ReminderDraft, listName: String) async throws -> ReminderItem
  func updateReminder(id: String, update: ReminderUpdate) async throws -> ReminderItem
  func completeReminders(ids: [String]) async throws -> [ReminderItem]
  func deleteReminders(ids: [String]) async throws -> Int
}

extension RemindersStore: ReminderStoreProtocol {}
