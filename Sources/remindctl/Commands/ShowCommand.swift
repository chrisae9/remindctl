import Commander
import Foundation
import RemindCore

enum ShowCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "show",
      abstract: "Show reminders",
      discussion: "Filters: today, tomorrow, week, overdue, upcoming, open, completed, all, or a date string.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(
              label: "filter",
              help: "today|tomorrow|week|overdue|upcoming|open|completed|all|<date>",
              isOptional: true
            )
          ],
          options: [
            .make(
              label: "list",
              names: [.short("l"), .long("list")],
              help: "Limit to a specific list",
              parsing: .singleValue
            ),
            .make(
              label: "search",
              names: [.short("s"), .long("search")],
              help: "Filter by text in title or notes",
              parsing: .singleValue
            ),
          ]
        )
      ),
      usageExamples: [
        "remindctl",
        "remindctl today",
        "remindctl show overdue",
        "remindctl show 2026-01-04",
        "remindctl show --list Work",
        "remindctl show all --search milk",
      ]
    ) { values, runtime in
      let listName = values.option("list")
      let searchQuery = values.option("search")
      let filterToken = values.argument(0)

      let filter: ReminderFilter
      if let token = filterToken {
        guard let parsed = ReminderFiltering.parse(token) else {
          throw RemindCoreError.operationFailed("Unknown filter: \"\(token)\"")
        }
        filter = parsed
      } else {
        filter = .today
      }

      let store = RemindersStore()
      try await store.requestAccess()
      let reminders = try await store.reminders(in: listName)
      var filtered = ReminderFiltering.apply(reminders, filter: filter)
      if let query = searchQuery {
        filtered = ReminderFiltering.search(filtered, query: query)
      }
      OutputRenderer.printReminders(filtered, format: runtime.outputFormat)
    }
  }
}
