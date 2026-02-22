import Foundation

public enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
  case daily
  case weekly
  case monthly
  case yearly
}

public enum ReminderPriority: String, Codable, CaseIterable, Sendable {
  case none
  case low
  case medium
  case high

  public init(eventKitValue: Int) {
    switch eventKitValue {
    case 1...4:
      self = .high
    case 5:
      self = .medium
    case 6...9:
      self = .low
    default:
      self = .none
    }
  }

  public var eventKitValue: Int {
    switch self {
    case .none:
      return 0
    case .high:
      return 1
    case .medium:
      return 5
    case .low:
      return 9
    }
  }
}

public struct ReminderList: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public let title: String

  public init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}

public struct ReminderItem: Identifiable, Codable, Sendable, Equatable {
  public let id: String
  public let title: String
  public let notes: String?
  public let isCompleted: Bool
  public let completionDate: Date?
  public let priority: ReminderPriority
  public let dueDate: Date?
  public let startDate: Date?
  public let timeZone: String?
  public let recurrence: RecurrenceFrequency?
  public let listID: String
  public let listName: String

  public init(
    id: String,
    title: String,
    notes: String?,
    isCompleted: Bool,
    completionDate: Date?,
    priority: ReminderPriority,
    dueDate: Date?,
    startDate: Date? = nil,
    timeZone: String? = nil,
    recurrence: RecurrenceFrequency? = nil,
    listID: String,
    listName: String
  ) {
    self.id = id
    self.title = title
    self.notes = notes
    self.isCompleted = isCompleted
    self.completionDate = completionDate
    self.priority = priority
    self.dueDate = dueDate
    self.startDate = startDate
    self.timeZone = timeZone
    self.recurrence = recurrence
    self.listID = listID
    self.listName = listName
  }
}

public struct ReminderDraft: Sendable {
  public let title: String
  public let notes: String?
  public let dueDate: Date?
  public let startDate: Date?
  public let timeZone: String?
  public let priority: ReminderPriority
  public let recurrence: RecurrenceFrequency?

  public init(
    title: String,
    notes: String?,
    dueDate: Date?,
    startDate: Date? = nil,
    timeZone: String? = nil,
    priority: ReminderPriority,
    recurrence: RecurrenceFrequency? = nil
  ) {
    self.title = title
    self.notes = notes
    self.dueDate = dueDate
    self.startDate = startDate
    self.timeZone = timeZone
    self.priority = priority
    self.recurrence = recurrence
  }
}

public struct ReminderUpdate: Sendable {
  public let title: String?
  public let notes: String?
  public let dueDate: Date??
  public let startDate: Date??
  public let timeZone: String??
  public let priority: ReminderPriority?
  public let recurrence: RecurrenceFrequency??
  public let listName: String?
  public let isCompleted: Bool?

  public init(
    title: String? = nil,
    notes: String? = nil,
    dueDate: Date?? = nil,
    startDate: Date?? = nil,
    timeZone: String?? = nil,
    priority: ReminderPriority? = nil,
    recurrence: RecurrenceFrequency?? = nil,
    listName: String? = nil,
    isCompleted: Bool? = nil
  ) {
    self.title = title
    self.notes = notes
    self.dueDate = dueDate
    self.startDate = startDate
    self.timeZone = timeZone
    self.priority = priority
    self.recurrence = recurrence
    self.listName = listName
    self.isCompleted = isCompleted
  }
}
