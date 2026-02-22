import Commander
import Foundation
import RemindCore

enum EditCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "edit",
      abstract: "Edit one or more reminders",
      discussion: """
        Edit one or more reminders by index or ID prefix. All specified reminders
        receive the same changes. Get indexes from 'remindctl show' output (1-based)
        or use 4+ character UUID prefixes from the id field.

        Clear optional fields with --clear-due, --clear-recurrence, --clear-start-date,
        --clear-timezone, --clear-alarms. A --clear flag and its setter cannot be combined.

        All value formats (dates, priority, recurrence, alarms) are the same as 'add'.
        See 'remindctl add --help' for format details.

        Use --complete/--incomplete to change completion status.
        Use --dry-run to preview which reminders would be affected without saving.
        Returns the updated reminder(s). Use --json for structured output.
        """,
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "ids", help: "Indexes or ID prefixes", isOptional: false)
          ],
          options: [
            .make(label: "title", names: [.short("t"), .long("title")], help: "New title", parsing: .singleValue),
            .make(label: "list", names: [.short("l"), .long("list")], help: "Move to list", parsing: .singleValue),
            .make(label: "due", names: [.short("d"), .long("due")], help: "Set due date", parsing: .singleValue),
            .make(label: "notes", names: [.short("n"), .long("notes")], help: "Set notes", parsing: .singleValue),
            .make(
              label: "priority",
              names: [.short("p"), .long("priority")],
              help: "none|low|medium|high",
              parsing: .singleValue
            ),
            .make(
              label: "recurrence",
              names: [.short("r"), .long("recurrence")],
              help: "daily|2-weekly|\"every 3 months\"",
              parsing: .singleValue
            ),
            .make(
              label: "recurrenceDays",
              names: [.long("recurrence-days")],
              help: "Days of week: mon,wed,fri",
              parsing: .singleValue
            ),
            .make(
              label: "recurrenceMonthDays",
              names: [.long("recurrence-month-days")],
              help: "Days of month: 1,15,-1",
              parsing: .singleValue
            ),
            .make(
              label: "recurrenceMonths",
              names: [.long("recurrence-months")],
              help: "Months: jan,jul or 1,7",
              parsing: .singleValue
            ),
            .make(
              label: "recurrenceEnd",
              names: [.long("recurrence-end")],
              help: "End: date or 10x for count",
              parsing: .singleValue
            ),
            .make(
              label: "startDate",
              names: [.long("start-date")],
              help: "Set start date",
              parsing: .singleValue
            ),
            .make(
              label: "timezone",
              names: [.long("timezone"), .long("tz")],
              help: "IANA timezone (e.g. America/New_York)",
              parsing: .singleValue
            ),
            .make(
              label: "alarm",
              names: [.long("alarm")],
              help: "Alarm: -15m, -1h, -1d, 0, or date (repeatable)",
              parsing: .singleValue
            ),
            .make(
              label: "locationAlarm",
              names: [.long("location-alarm")],
              help: "Location alarm: \"title:lat,lng:radius:enter|leave\" (repeatable)",
              parsing: .singleValue
            ),
          ],
          flags: [
            .make(label: "clearDue", names: [.long("clear-due")], help: "Clear due date"),
            .make(
              label: "clearRecurrence", names: [.long("clear-recurrence")], help: "Clear recurrence"),
            .make(label: "clearStartDate", names: [.long("clear-start-date")], help: "Clear start date"),
            .make(label: "clearTimezone", names: [.long("clear-timezone")], help: "Clear timezone"),
            .make(label: "clearAlarms", names: [.long("clear-alarms")], help: "Remove all alarms"),
            .make(label: "complete", names: [.long("complete")], help: "Mark completed"),
            .make(label: "incomplete", names: [.long("incomplete")], help: "Mark incomplete"),
            .make(label: "dryRun", names: [.long("dry-run")], help: "Preview without changes"),
          ]
        )
      ),
      usageExamples: [
        "remindctl edit 1 --title \"New title\" --json",
        "remindctl edit 4A83 --due tomorrow",
        "remindctl edit 1 2 3 --priority high --list Work",
        "remindctl edit 3 --clear-due --clear-recurrence",
        "remindctl edit 1 --recurrence weekly --alarm -15m",
        "remindctl edit 2 --complete",
      ]
    ) { values, runtime in
      let inputs = values.positional
      guard !inputs.isEmpty else {
        throw ParsedValuesError.missingArgument("ids")
      }

      let store = RemindersStore()
      try await store.requestAccess()
      let reminders = try await store.reminders(in: nil)
      let resolved = try IDResolver.resolve(inputs, from: reminders)

      let title = values.option("title")
      let listName = values.option("list")
      let notes = values.option("notes")

      var dueUpdate: Date??
      if let dueValue = values.option("due") {
        dueUpdate = try CommandHelpers.parseDueDate(dueValue)
      }
      if values.flag("clearDue") {
        if dueUpdate != nil {
          throw RemindCoreError.operationFailed("Use either --due or --clear-due, not both")
        }
        dueUpdate = .some(nil)
      }

      var priority: ReminderPriority?
      if let priorityValue = values.option("priority") {
        priority = try CommandHelpers.parsePriority(priorityValue)
      }

      var recurrenceUpdate: RecurrenceRule??
      if let recurrenceValue = values.option("recurrence") {
        recurrenceUpdate = try CommandHelpers.parseRecurrence(recurrenceValue)
      }
      let recDays = try values.option("recurrenceDays").map(CommandHelpers.parseDaysOfWeek)
      let recMonthDays = try values.option("recurrenceMonthDays").map(CommandHelpers.parseDaysOfMonth)
      let recMonths = try values.option("recurrenceMonths").map(CommandHelpers.parseMonthsOfYear)
      let recEnd = try values.option("recurrenceEnd").map(CommandHelpers.parseRecurrenceEnd)
      if recDays != nil || recMonthDays != nil || recMonths != nil || recEnd != nil {
        let base: RecurrenceRule
        if let update = recurrenceUpdate, let rule = update {
          base = rule
        } else {
          base = RecurrenceRule(frequency: .weekly)
        }
        recurrenceUpdate = CommandHelpers.buildRecurrenceRule(
          base: base,
          daysOfWeek: recDays, daysOfMonth: recMonthDays, monthsOfYear: recMonths,
          endDate: recEnd?.date, endCount: recEnd?.count
        )
      }
      if values.flag("clearRecurrence") {
        if recurrenceUpdate != nil {
          throw RemindCoreError.operationFailed("Use either --recurrence or --clear-recurrence, not both")
        }
        recurrenceUpdate = .some(nil)
      }

      var startDateUpdate: Date??
      if let startDateValue = values.option("startDate") {
        startDateUpdate = try CommandHelpers.parseDueDate(startDateValue)
      }
      if values.flag("clearStartDate") {
        if startDateUpdate != nil {
          throw RemindCoreError.operationFailed("Use either --start-date or --clear-start-date, not both")
        }
        startDateUpdate = .some(nil)
      }

      var timeZoneUpdate: String??
      if let tzValue = values.option("timezone") {
        timeZoneUpdate = try CommandHelpers.parseTimeZone(tzValue)
      }
      if values.flag("clearTimezone") {
        if timeZoneUpdate != nil {
          throw RemindCoreError.operationFailed("Use either --timezone or --clear-timezone, not both")
        }
        timeZoneUpdate = .some(nil)
      }

      var alarmsUpdate: [ReminderAlarm]??
      let alarmValues = values.optionValues("alarm")
      let locationAlarmValues = values.optionValues("locationAlarm")
      if !alarmValues.isEmpty || !locationAlarmValues.isEmpty {
        var alarms = try alarmValues.map(CommandHelpers.parseAlarm)
        alarms += try locationAlarmValues.map(CommandHelpers.parseLocationAlarm)
        alarmsUpdate = alarms
      }
      if values.flag("clearAlarms") {
        if alarmsUpdate != nil {
          throw RemindCoreError.operationFailed("Use either --alarm or --clear-alarms, not both")
        }
        alarmsUpdate = .some(nil)
      }

      let completeFlag = values.flag("complete")
      let incompleteFlag = values.flag("incomplete")
      if completeFlag && incompleteFlag {
        throw RemindCoreError.operationFailed("Use either --complete or --incomplete, not both")
      }
      let isCompleted: Bool? = completeFlag ? true : (incompleteFlag ? false : nil)

      if title == nil && listName == nil && notes == nil && dueUpdate == nil && priority == nil
        && recurrenceUpdate == nil && startDateUpdate == nil && timeZoneUpdate == nil
        && alarmsUpdate == nil && isCompleted == nil
      {
        throw RemindCoreError.operationFailed("No changes specified")
      }

      if values.flag("dryRun") {
        OutputRenderer.printReminders(resolved, format: runtime.outputFormat)
        return
      }

      let update = ReminderUpdate(
        title: title,
        notes: notes,
        dueDate: dueUpdate,
        startDate: startDateUpdate,
        timeZone: timeZoneUpdate,
        priority: priority,
        recurrence: recurrenceUpdate,
        alarms: alarmsUpdate,
        listName: listName,
        isCompleted: isCompleted
      )

      var updated: [ReminderItem] = []
      for reminder in resolved {
        let result = try await store.updateReminder(id: reminder.id, update: update)
        updated.append(result)
      }
      OutputRenderer.printReminders(updated, format: runtime.outputFormat)
    }
  }
}
