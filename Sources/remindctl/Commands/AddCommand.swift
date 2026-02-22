import Commander
import Foundation
import RemindCore

enum AddCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "add",
      abstract: "Add a reminder",
      discussion: "Provide a title as an argument or via --title.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "title", help: "Reminder title", isOptional: true)
          ],
          options: [
            .make(label: "title", names: [.long("title")], help: "Reminder title", parsing: .singleValue),
            .make(label: "list", names: [.short("l"), .long("list")], help: "List name", parsing: .singleValue),
            .make(label: "due", names: [.short("d"), .long("due")], help: "Due date", parsing: .singleValue),
            .make(label: "notes", names: [.short("n"), .long("notes")], help: "Notes", parsing: .singleValue),
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
            .make(
              label: "startDate",
              names: [.long("start-date")],
              help: "Start date",
              parsing: .singleValue
            ),
            .make(
              label: "timezone",
              names: [.long("timezone"), .long("tz")],
              help: "IANA timezone (e.g. America/New_York)",
              parsing: .singleValue
            ),
          ]
        )
      ),
      usageExamples: [
        "remindctl add \"Buy milk\"",
        "remindctl add --title \"Call mom\" --list Personal --due tomorrow",
        "remindctl add \"Review docs\" --priority high",
      ]
    ) { values, runtime in
      let titleOption = values.option("title")
      let titleArg = values.argument(0)
      if titleOption != nil && titleArg != nil {
        throw RemindCoreError.operationFailed("Provide title either as argument or via --title")
      }

      var title = titleOption ?? titleArg
      if title == nil {
        if runtime.noInput || !Console.isTTY {
          throw RemindCoreError.operationFailed("Missing title. Provide it as an argument or via --title.")
        }
        title = Console.readLine(prompt: "Title:")?.trimmingCharacters(in: .whitespacesAndNewlines)
        if title?.isEmpty == true { title = nil }
      }

      guard let title else {
        throw RemindCoreError.operationFailed("Missing title.")
      }

      let listName = values.option("list")
      let notes = values.option("notes")
      let dueValue = values.option("due")
      let priorityValue = values.option("priority")

      let dueDate = try dueValue.map(CommandHelpers.parseDueDate)
      let priority = try priorityValue.map(CommandHelpers.parsePriority) ?? .none
      let recurrenceValue = values.option("recurrence")
      let recurrence = try recurrenceValue.map(CommandHelpers.parseRecurrence)
      let startDate = try values.option("startDate").map(CommandHelpers.parseDueDate)
      let timeZone = try values.option("timezone").map(CommandHelpers.parseTimeZone)

      let store = RemindersStore()
      try await store.requestAccess()

      let targetList: String?
      if let listName {
        targetList = listName
      } else {
        targetList = await store.defaultListName()
      }
      guard let targetList else {
        throw RemindCoreError.operationFailed("No default list found. Specify --list.")
      }

      let draft = ReminderDraft(
        title: title, notes: notes, dueDate: dueDate, startDate: startDate,
        timeZone: timeZone, priority: priority, recurrence: recurrence)
      let reminder = try await store.createReminder(draft, listName: targetList)
      OutputRenderer.printReminder(reminder, format: runtime.outputFormat)
    }
  }
}
