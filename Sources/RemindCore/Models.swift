import Foundation

public enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
  case daily
  case weekly
  case monthly
  case yearly
}

public struct RecurrenceRule: Codable, Sendable, Equatable {
  public let frequency: RecurrenceFrequency
  public let interval: Int
  public let daysOfTheWeek: [Int]?
  public let daysOfTheMonth: [Int]?
  public let monthsOfTheYear: [Int]?
  public let weeksOfTheYear: [Int]?
  public let daysOfTheYear: [Int]?
  public let setPositions: [Int]?
  public let endDate: Date?
  public let endOccurrenceCount: Int?

  public init(
    frequency: RecurrenceFrequency,
    interval: Int = 1,
    daysOfTheWeek: [Int]? = nil,
    daysOfTheMonth: [Int]? = nil,
    monthsOfTheYear: [Int]? = nil,
    weeksOfTheYear: [Int]? = nil,
    daysOfTheYear: [Int]? = nil,
    setPositions: [Int]? = nil,
    endDate: Date? = nil,
    endOccurrenceCount: Int? = nil
  ) {
    self.frequency = frequency
    self.interval = interval
    self.daysOfTheWeek = daysOfTheWeek
    self.daysOfTheMonth = daysOfTheMonth
    self.monthsOfTheYear = monthsOfTheYear
    self.weeksOfTheYear = weeksOfTheYear
    self.daysOfTheYear = daysOfTheYear
    self.setPositions = setPositions
    self.endDate = endDate
    self.endOccurrenceCount = endOccurrenceCount
  }
}

public enum LocationProximity: String, Codable, Sendable, Equatable {
  case enter
  case leave
}

public struct LocationAlarm: Codable, Sendable, Equatable {
  public let title: String
  public let latitude: Double
  public let longitude: Double
  public let radius: Double
  public let proximity: LocationProximity

  public init(
    title: String, latitude: Double, longitude: Double,
    radius: Double = 100, proximity: LocationProximity = .enter
  ) {
    self.title = title
    self.latitude = latitude
    self.longitude = longitude
    self.radius = radius
    self.proximity = proximity
  }
}

public enum AlarmType: Codable, Sendable, Equatable {
  case absolute(Date)
  case relative(TimeInterval)
  case location(LocationAlarm)
}

public struct ReminderAlarm: Codable, Sendable, Equatable {
  public let type: AlarmType

  public init(type: AlarmType) {
    self.type = type
  }

  public init(absoluteDate: Date) {
    self.type = .absolute(absoluteDate)
  }

  public init(relativeOffset: TimeInterval) {
    self.type = .relative(relativeOffset)
  }

  public init(location: LocationAlarm) {
    self.type = .location(location)
  }
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
  public let recurrence: RecurrenceRule?
  public let alarms: [ReminderAlarm]
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
    recurrence: RecurrenceRule? = nil,
    alarms: [ReminderAlarm] = [],
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
    self.alarms = alarms
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
  public let recurrence: RecurrenceRule?
  public let alarms: [ReminderAlarm]

  public init(
    title: String,
    notes: String?,
    dueDate: Date?,
    startDate: Date? = nil,
    timeZone: String? = nil,
    priority: ReminderPriority,
    recurrence: RecurrenceRule? = nil,
    alarms: [ReminderAlarm] = []
  ) {
    self.title = title
    self.notes = notes
    self.dueDate = dueDate
    self.startDate = startDate
    self.timeZone = timeZone
    self.priority = priority
    self.recurrence = recurrence
    self.alarms = alarms
  }
}

public struct ReminderUpdate: Sendable {
  public let title: String?
  public let notes: String?
  public let dueDate: Date??
  public let startDate: Date??
  public let timeZone: String??
  public let priority: ReminderPriority?
  public let recurrence: RecurrenceRule??
  public let alarms: [ReminderAlarm]??
  public let listName: String?
  public let isCompleted: Bool?

  public init(
    title: String? = nil,
    notes: String? = nil,
    dueDate: Date?? = nil,
    startDate: Date?? = nil,
    timeZone: String?? = nil,
    priority: ReminderPriority? = nil,
    recurrence: RecurrenceRule?? = nil,
    alarms: [ReminderAlarm]?? = nil,
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
    self.alarms = alarms
    self.listName = listName
    self.isCompleted = isCompleted
  }
}
