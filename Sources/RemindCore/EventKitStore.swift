import CoreLocation
import EventKit
import Foundation

public actor RemindersStore {
  private let eventStore = EKEventStore()
  private let calendar: Calendar

  public init(calendar: Calendar = .current) {
    self.calendar = calendar
  }

  public func requestAccess() async throws {
    let status = Self.authorizationStatus()
    switch status {
    case .notDetermined:
      let updated = try await requestAuthorization()
      if updated != .fullAccess {
        throw RemindCoreError.accessDenied
      }
    case .denied:
      throw RemindCoreError.accessDenied
    case .restricted:
      throw RemindCoreError.accessRestricted
    case .writeOnly:
      throw RemindCoreError.writeOnlyAccess
    case .fullAccess:
      break
    }
  }

  public static func authorizationStatus() -> RemindersAuthorizationStatus {
    RemindersAuthorizationStatus(eventKitStatus: EKEventStore.authorizationStatus(for: .reminder))
  }

  public func requestAuthorization() async throws -> RemindersAuthorizationStatus {
    let status = Self.authorizationStatus()
    switch status {
    case .notDetermined:
      let granted = try await requestFullAccess()
      return granted ? .fullAccess : .denied
    default:
      return status
    }
  }

  public func lists() async -> [ReminderList] {
    eventStore.calendars(for: .reminder).map { calendar in
      ReminderList(id: calendar.calendarIdentifier, title: calendar.title)
    }
  }

  public func defaultListName() -> String? {
    eventStore.defaultCalendarForNewReminders()?.title
  }

  public func reminders(in listName: String? = nil) async throws -> [ReminderItem] {
    let calendars: [EKCalendar]
    if let listName {
      calendars = eventStore.calendars(for: .reminder).filter { $0.title == listName }
      if calendars.isEmpty {
        throw RemindCoreError.listNotFound(listName)
      }
    } else {
      calendars = eventStore.calendars(for: .reminder)
    }

    return await fetchReminders(in: calendars)
  }

  public func createList(name: String) async throws -> ReminderList {
    let list = EKCalendar(for: .reminder, eventStore: eventStore)
    list.title = name
    guard let source = eventStore.defaultCalendarForNewReminders()?.source else {
      throw RemindCoreError.operationFailed("Unable to determine default reminder source")
    }
    list.source = source
    do {
      try eventStore.saveCalendar(list, commit: true)
    } catch {
      throw RemindCoreError.eventKitError("create list", detail: error.localizedDescription)
    }
    return ReminderList(id: list.calendarIdentifier, title: list.title)
  }

  public func renameList(oldName: String, newName: String) async throws {
    let calendar = try calendar(named: oldName)
    guard calendar.allowsContentModifications else {
      throw RemindCoreError.operationFailed("Cannot modify system list")
    }
    calendar.title = newName
    do {
      try eventStore.saveCalendar(calendar, commit: true)
    } catch {
      throw RemindCoreError.eventKitError("rename list", detail: error.localizedDescription)
    }
  }

  public func deleteList(name: String) async throws {
    let calendar = try calendar(named: name)
    guard calendar.allowsContentModifications else {
      throw RemindCoreError.operationFailed("Cannot delete system list")
    }
    do {
      try eventStore.removeCalendar(calendar, commit: true)
    } catch {
      throw RemindCoreError.eventKitError("delete list", detail: error.localizedDescription)
    }
  }

  public func createReminder(_ draft: ReminderDraft, listName: String) async throws -> ReminderItem {
    let calendar = try calendar(named: listName)
    let reminder = EKReminder(eventStore: eventStore)
    reminder.title = draft.title
    reminder.notes = draft.notes
    reminder.calendar = calendar
    reminder.priority = draft.priority.eventKitValue
    if let dueDate = draft.dueDate {
      reminder.dueDateComponents = calendarComponents(from: dueDate, isDateOnly: draft.dueDateIsAllDay)
    }
    if let startDate = draft.startDate {
      reminder.startDateComponents = calendarComponents(
        from: startDate, isDateOnly: draft.startDateIsAllDay)
    }
    if let tzID = draft.timeZone {
      let tz = TimeZone(identifier: tzID)
      reminder.dueDateComponents?.timeZone = tz
      reminder.startDateComponents?.timeZone = tz
    }
    if let recurrence = draft.recurrence {
      applyRecurrence(recurrence, to: reminder)
    }
    applyAlarms(draft.alarms, to: reminder)
    do {
      try eventStore.save(reminder, commit: true)
    } catch {
      throw RemindCoreError.eventKitError("save reminder", detail: error.localizedDescription)
    }
    return item(from: reminder)
  }

  public func updateReminder(id: String, update: ReminderUpdate) async throws -> ReminderItem {
    let reminder = try reminder(withID: id)

    if let title = update.title {
      reminder.title = title
    }
    if let notes = update.notes {
      reminder.notes = notes
    }
    if let dueDateUpdate = update.dueDate {
      if let dueDate = dueDateUpdate {
        let isDateOnly = update.dueDateIsAllDay ?? false
        reminder.dueDateComponents = calendarComponents(from: dueDate, isDateOnly: isDateOnly)
      } else {
        reminder.dueDateComponents = nil
      }
    }
    if let priority = update.priority {
      reminder.priority = priority.eventKitValue
    }
    if let startDateUpdate = update.startDate {
      if let startDate = startDateUpdate {
        let isDateOnly = update.startDateIsAllDay ?? false
        reminder.startDateComponents = calendarComponents(from: startDate, isDateOnly: isDateOnly)
      } else {
        reminder.startDateComponents = nil
      }
    }
    if let timeZoneUpdate = update.timeZone {
      let tz = timeZoneUpdate.flatMap { TimeZone(identifier: $0) }
      reminder.dueDateComponents?.timeZone = tz
      reminder.startDateComponents?.timeZone = tz
    }
    if let recurrenceUpdate = update.recurrence {
      if let recurrence = recurrenceUpdate {
        applyRecurrence(recurrence, to: reminder)
      } else {
        clearRecurrence(from: reminder)
      }
    }
    if let alarmsUpdate = update.alarms {
      if let alarms = alarmsUpdate {
        reminder.alarms?.forEach { reminder.removeAlarm($0) }
        applyAlarms(alarms, to: reminder)
      } else {
        reminder.alarms?.forEach { reminder.removeAlarm($0) }
      }
    }
    if let listName = update.listName {
      reminder.calendar = try calendar(named: listName)
    }
    if let isCompleted = update.isCompleted {
      reminder.isCompleted = isCompleted
    }

    do {
      try eventStore.save(reminder, commit: true)
    } catch {
      throw RemindCoreError.eventKitError("update reminder", detail: error.localizedDescription)
    }

    return item(from: reminder)
  }

  public func completeReminders(ids: [String]) async throws -> [ReminderItem] {
    var updated: [ReminderItem] = []
    for id in ids {
      let reminder = try reminder(withID: id)
      reminder.isCompleted = true
      do {
        try eventStore.save(reminder, commit: true)
      } catch {
        throw RemindCoreError.eventKitError("complete reminder", detail: error.localizedDescription)
      }
      updated.append(item(from: reminder))
    }
    return updated
  }

  public func deleteReminders(ids: [String]) async throws -> Int {
    var deleted = 0
    for id in ids {
      let reminder = try reminder(withID: id)
      do {
        try eventStore.remove(reminder, commit: true)
      } catch {
        throw RemindCoreError.eventKitError("delete reminder", detail: error.localizedDescription)
      }
      deleted += 1
    }
    return deleted
  }

  private func requestFullAccess() async throws -> Bool {
    try await withCheckedThrowingContinuation { continuation in
      eventStore.requestFullAccessToReminders { granted, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        continuation.resume(returning: granted)
      }
    }
  }

  private func fetchReminders(in calendars: [EKCalendar]) async -> [ReminderItem] {
    struct ReminderData: Sendable {
      let id: String
      let title: String
      let notes: String?
      let isCompleted: Bool
      let completionDate: Date?
      let creationDate: Date?
      let priority: Int
      let dueDateComponents: DateComponents?
      let startDateComponents: DateComponents?
      let timeZone: String?
      let recurrence: RecurrenceRule?
      let alarms: [ReminderAlarm]
      let listID: String
      let listName: String
      let sectionName: String?
    }

    let sectionMap = SectionResolver.resolve()

    let reminderData = await withCheckedContinuation { (continuation: CheckedContinuation<[ReminderData], Never>) in
      let predicate = eventStore.predicateForReminders(in: calendars)
      eventStore.fetchReminders(matching: predicate) { reminders in
        let data = (reminders ?? []).map { reminder in
          let recurrence: RecurrenceRule? = {
            guard let ekRule = reminder.recurrenceRules?.first else { return nil }
            let frequency: RecurrenceFrequency
            switch ekRule.frequency {
            case .daily: frequency = .daily
            case .weekly: frequency = .weekly
            case .monthly: frequency = .monthly
            case .yearly: frequency = .yearly
            @unknown default: return nil
            }
            let daysOfTheWeek = ekRule.daysOfTheWeek?.map { $0.dayOfTheWeek.rawValue }
            let daysOfTheMonth = ekRule.daysOfTheMonth?.map { $0.intValue }
            let monthsOfTheYear = ekRule.monthsOfTheYear?.map { $0.intValue }
            let weeksOfTheYear = ekRule.weeksOfTheYear?.map { $0.intValue }
            let daysOfTheYear = ekRule.daysOfTheYear?.map { $0.intValue }
            let setPositions = ekRule.setPositions?.map { $0.intValue }
            var endDate: Date?
            var endCount: Int?
            if let end = ekRule.recurrenceEnd {
              if let date = end.endDate {
                endDate = date
              } else if end.occurrenceCount > 0 {
                endCount = end.occurrenceCount
              }
            }
            return RecurrenceRule(
              frequency: frequency,
              interval: ekRule.interval,
              daysOfTheWeek: daysOfTheWeek,
              daysOfTheMonth: daysOfTheMonth,
              monthsOfTheYear: monthsOfTheYear,
              weeksOfTheYear: weeksOfTheYear,
              daysOfTheYear: daysOfTheYear,
              setPositions: setPositions,
              endDate: endDate,
              endOccurrenceCount: endCount
            )
          }()
          let tz = reminder.dueDateComponents?.timeZone?.identifier ?? reminder.startDateComponents?.timeZone?.identifier
          let alarms: [ReminderAlarm] = (reminder.alarms ?? []).compactMap { ekAlarm in
            if let structuredLoc = ekAlarm.structuredLocation,
              let geoLocation = structuredLoc.geoLocation
            {
              let proximity: LocationProximity = ekAlarm.proximity == .leave ? .leave : .enter
              let loc = LocationAlarm(
                title: structuredLoc.title ?? "",
                latitude: geoLocation.coordinate.latitude,
                longitude: geoLocation.coordinate.longitude,
                radius: structuredLoc.radius,
                proximity: proximity
              )
              return ReminderAlarm(location: loc)
            }
            if let absDate = ekAlarm.absoluteDate {
              return ReminderAlarm(absoluteDate: absDate)
            }
            return ReminderAlarm(relativeOffset: ekAlarm.relativeOffset)
          }
          return ReminderData(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            notes: reminder.notes,
            isCompleted: reminder.isCompleted,
            completionDate: reminder.completionDate,
            creationDate: reminder.creationDate,
            priority: Int(reminder.priority),
            dueDateComponents: reminder.dueDateComponents,
            startDateComponents: reminder.startDateComponents,
            timeZone: tz,
            recurrence: recurrence,
            alarms: alarms,
            listID: reminder.calendar.calendarIdentifier,
            listName: reminder.calendar.title,
            sectionName: sectionMap[reminder.calendarItemIdentifier]
          )
        }
        continuation.resume(returning: data)
      }
    }

    return reminderData.map { data in
      ReminderItem(
        id: data.id,
        title: data.title,
        notes: data.notes,
        isCompleted: data.isCompleted,
        completionDate: data.completionDate,
        priority: ReminderPriority(eventKitValue: data.priority),
        dueDate: date(from: data.dueDateComponents),
        startDate: date(from: data.startDateComponents),
        timeZone: data.timeZone,
        recurrence: data.recurrence,
        alarms: data.alarms,
        listID: data.listID,
        listName: data.listName,
        creationDate: data.creationDate,
        dueDateIsAllDay: data.dueDateComponents?.hour == nil && data.dueDateComponents != nil,
        sectionName: data.sectionName
      )
    }
  }

  private func reminder(withID id: String) throws -> EKReminder {
    guard let item = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
      throw RemindCoreError.reminderNotFound(id)
    }
    return item
  }



  private func calendar(named name: String) throws -> EKCalendar {
    let calendars = eventStore.calendars(for: .reminder).filter { $0.title == name }
    guard let calendar = calendars.first else {
      throw RemindCoreError.listNotFound(name)
    }
    return calendar
  }

  private func recurrenceRule(from reminder: EKReminder) -> RecurrenceRule? {
    guard let rule = reminder.recurrenceRules?.first else { return nil }
    let frequency: RecurrenceFrequency
    switch rule.frequency {
    case .daily: frequency = .daily
    case .weekly: frequency = .weekly
    case .monthly: frequency = .monthly
    case .yearly: frequency = .yearly
    @unknown default: return nil
    }

    let daysOfTheWeek = rule.daysOfTheWeek?.map { $0.dayOfTheWeek.rawValue }
    let daysOfTheMonth = rule.daysOfTheMonth?.map { $0.intValue }
    let monthsOfTheYear = rule.monthsOfTheYear?.map { $0.intValue }
    let weeksOfTheYear = rule.weeksOfTheYear?.map { $0.intValue }
    let daysOfTheYear = rule.daysOfTheYear?.map { $0.intValue }
    let setPositions = rule.setPositions?.map { $0.intValue }

    var endDate: Date?
    var endCount: Int?
    if let end = rule.recurrenceEnd {
      if let date = end.endDate {
        endDate = date
      } else if end.occurrenceCount > 0 {
        endCount = end.occurrenceCount
      }
    }

    return RecurrenceRule(
      frequency: frequency,
      interval: rule.interval,
      daysOfTheWeek: daysOfTheWeek,
      daysOfTheMonth: daysOfTheMonth,
      monthsOfTheYear: monthsOfTheYear,
      weeksOfTheYear: weeksOfTheYear,
      daysOfTheYear: daysOfTheYear,
      setPositions: setPositions,
      endDate: endDate,
      endOccurrenceCount: endCount
    )
  }

  private func applyRecurrence(_ rule: RecurrenceRule, to reminder: EKReminder) {
    reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
    let ekFrequency: EKRecurrenceFrequency
    switch rule.frequency {
    case .daily: ekFrequency = .daily
    case .weekly: ekFrequency = .weekly
    case .monthly: ekFrequency = .monthly
    case .yearly: ekFrequency = .yearly
    }

    let daysOfTheWeek = rule.daysOfTheWeek?.map {
      EKRecurrenceDayOfWeek(EKWeekday(rawValue: $0)!)
    }
    let daysOfTheMonth = rule.daysOfTheMonth?.map { NSNumber(value: $0) }
    let monthsOfTheYear = rule.monthsOfTheYear?.map { NSNumber(value: $0) }
    let weeksOfTheYear = rule.weeksOfTheYear?.map { NSNumber(value: $0) }
    let daysOfTheYear = rule.daysOfTheYear?.map { NSNumber(value: $0) }
    let setPositions = rule.setPositions?.map { NSNumber(value: $0) }

    var end: EKRecurrenceEnd?
    if let endDate = rule.endDate {
      end = EKRecurrenceEnd(end: endDate)
    } else if let count = rule.endOccurrenceCount {
      end = EKRecurrenceEnd(occurrenceCount: count)
    }

    let ekRule = EKRecurrenceRule(
      recurrenceWith: ekFrequency,
      interval: rule.interval,
      daysOfTheWeek: daysOfTheWeek,
      daysOfTheMonth: daysOfTheMonth,
      monthsOfTheYear: monthsOfTheYear,
      weeksOfTheYear: weeksOfTheYear,
      daysOfTheYear: daysOfTheYear,
      setPositions: setPositions,
      end: end
    )
    reminder.addRecurrenceRule(ekRule)
  }

  private func clearRecurrence(from reminder: EKReminder) {
    reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
  }

  private func extractAlarms(from reminder: EKReminder) -> [ReminderAlarm] {
    (reminder.alarms ?? []).compactMap { ekAlarm in
      if let structuredLoc = ekAlarm.structuredLocation,
        let geoLocation = structuredLoc.geoLocation
      {
        let proximity: LocationProximity = ekAlarm.proximity == .leave ? .leave : .enter
        let loc = LocationAlarm(
          title: structuredLoc.title ?? "",
          latitude: geoLocation.coordinate.latitude,
          longitude: geoLocation.coordinate.longitude,
          radius: structuredLoc.radius,
          proximity: proximity
        )
        return ReminderAlarm(location: loc)
      }
      if let absDate = ekAlarm.absoluteDate {
        return ReminderAlarm(absoluteDate: absDate)
      }
      return ReminderAlarm(relativeOffset: ekAlarm.relativeOffset)
    }
  }

  private func applyAlarms(_ alarms: [ReminderAlarm], to reminder: EKReminder) {
    for alarm in alarms {
      switch alarm.type {
      case .absolute(let date):
        reminder.addAlarm(EKAlarm(absoluteDate: date))
      case .relative(let offset):
        reminder.addAlarm(EKAlarm(relativeOffset: offset))
      case .location(let loc):
        let ekAlarm = EKAlarm()
        let structuredLoc = EKStructuredLocation(title: loc.title)
        structuredLoc.geoLocation = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        structuredLoc.radius = loc.radius
        ekAlarm.structuredLocation = structuredLoc
        ekAlarm.proximity = loc.proximity == .leave ? .leave : .enter
        reminder.addAlarm(ekAlarm)
      }
    }
  }

  private func calendarComponents(from date: Date, isDateOnly: Bool = false) -> DateComponents {
    let components: Set<Calendar.Component> =
      isDateOnly ? [.year, .month, .day] : [.year, .month, .day, .hour, .minute]
    return calendar.dateComponents(components, from: date)
  }

  private func date(from components: DateComponents?) -> Date? {
    guard let components else { return nil }
    return calendar.date(from: components)
  }

  private func item(from reminder: EKReminder) -> ReminderItem {
    let dueDateIsAllDay =
      reminder.dueDateComponents != nil && reminder.dueDateComponents?.hour == nil
    return ReminderItem(
      id: reminder.calendarItemIdentifier,
      title: reminder.title ?? "",
      notes: reminder.notes,
      isCompleted: reminder.isCompleted,
      completionDate: reminder.completionDate,
      priority: ReminderPriority(eventKitValue: Int(reminder.priority)),
      dueDate: date(from: reminder.dueDateComponents),
      startDate: date(from: reminder.startDateComponents),
      timeZone: reminder.dueDateComponents?.timeZone?.identifier
        ?? reminder.startDateComponents?.timeZone?.identifier,
      recurrence: recurrenceRule(from: reminder),
      alarms: extractAlarms(from: reminder),
      listID: reminder.calendar.calendarIdentifier,
      listName: reminder.calendar.title,
      creationDate: reminder.creationDate,
      dueDateIsAllDay: dueDateIsAllDay
    )
  }
}
