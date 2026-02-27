import Commander
import Foundation
import RemindCore

enum ShowCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "show",
      abstract: "Show reminders",
      discussion: """
        Show reminders matching a filter. Default filter is 'today' (includes overdue).

        Filters: today, tomorrow, week, overdue, upcoming, open, completed, all.
        Date filters: YYYY-MM-DD, "YYYY-MM-DD HH:mm", ISO 8601, today, tomorrow.
        Filters can be top-level shortcuts: 'remindctl today' = 'remindctl show today'.

        --list limits results to a named list (repeatable for multiple lists). --search filters by substring in title or notes.

        JSON output fields per reminder: id, title, notes, isCompleted, completionDate,
        priority (none|low|medium|high), dueDate, startDate, timeZone, recurrence, alarms,
        listID, listName. Dates are ISO 8601. Indexes shown in standard output are 1-based
        and match the IDs accepted by edit, complete, and delete.
        """,
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
              help: "Limit to list(s) (repeatable: --list Work --list Personal)",
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
        "remindctl show --json",
        "remindctl show all --list Work --list Personal --json",
        "remindctl show all --search milk",
        "remindctl show 2026-01-04",
      ]
    ) { values, runtime in
      let listNames = values.optionValues("list")
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

      let reminders: [ReminderItem]
      if listNames.isEmpty {
        reminders = try await store.reminders(in: nil)
      } else {
        var combined: [ReminderItem] = []
        for name in listNames {
          combined += try await store.reminders(in: name)
        }
        reminders = combined
      }

      var filtered = ReminderFiltering.apply(reminders, filter: filter)
      if let query = searchQuery {
        filtered = ReminderFiltering.search(filtered, query: query)
      }
      OutputRenderer.printReminders(filtered, format: runtime.outputFormat)
    }
  }
}
