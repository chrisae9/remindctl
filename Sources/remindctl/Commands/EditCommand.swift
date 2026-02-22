import Commander
import Foundation
import RemindCore

enum EditCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "edit",
      abstract: "Edit one or more reminders",
      discussion: "Use indexes or ID prefixes from the show output. Applies the same changes to all specified reminders.",
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
              help: "daily|weekly|monthly|yearly",
              parsing: .singleValue
            ),
          ],
          flags: [
            .make(label: "clearDue", names: [.long("clear-due")], help: "Clear due date"),
            .make(
              label: "clearRecurrence", names: [.long("clear-recurrence")], help: "Clear recurrence"),
            .make(label: "complete", names: [.long("complete")], help: "Mark completed"),
            .make(label: "incomplete", names: [.long("incomplete")], help: "Mark incomplete"),
            .make(label: "dryRun", names: [.long("dry-run")], help: "Preview without changes"),
          ]
        )
      ),
      usageExamples: [
        "remindctl edit 1 --title \"New title\"",
        "remindctl edit 4A83 --due tomorrow",
        "remindctl edit 1 2 3 --priority high",
        "remindctl edit 1 2 3 --list Work",
        "remindctl edit 3 --clear-due",
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

      var recurrenceUpdate: RecurrenceFrequency??
      if let recurrenceValue = values.option("recurrence") {
        recurrenceUpdate = try CommandHelpers.parseRecurrence(recurrenceValue)
      }
      if values.flag("clearRecurrence") {
        if recurrenceUpdate != nil {
          throw RemindCoreError.operationFailed("Use either --recurrence or --clear-recurrence, not both")
        }
        recurrenceUpdate = .some(nil)
      }

      let completeFlag = values.flag("complete")
      let incompleteFlag = values.flag("incomplete")
      if completeFlag && incompleteFlag {
        throw RemindCoreError.operationFailed("Use either --complete or --incomplete, not both")
      }
      let isCompleted: Bool? = completeFlag ? true : (incompleteFlag ? false : nil)

      if title == nil && listName == nil && notes == nil && dueUpdate == nil && priority == nil
        && recurrenceUpdate == nil && isCompleted == nil
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
        priority: priority,
        recurrence: recurrenceUpdate,
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
