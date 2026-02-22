import Commander
import Foundation
import RemindCore

enum ListCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "list",
      abstract: "List reminder lists or show list contents",
      discussion: """
        Without arguments, shows all reminder lists with reminder counts and overdue counts.
        With a name argument, shows all reminders in that list.

        Management operations: --create to create a new list, --delete to remove a list,
        --rename <new-name> to rename. Deletion prompts for confirmation unless --force
        or --no-input is set.

        Aliases: 'lists', 'ls'. JSON output for list summaries includes: id, title,
        reminderCount, overdueCount.
        """,
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "name", help: "List name", isOptional: true)
          ],
          options: [
            .make(
              label: "rename",
              names: [.short("r"), .long("rename")],
              help: "Rename the list",
              parsing: .singleValue
            )
          ],
          flags: [
            .make(label: "delete", names: [.short("d"), .long("delete")], help: "Delete the list"),
            .make(label: "create", names: [.long("create")], help: "Create list if missing"),
            .make(label: "force", names: [.short("f"), .long("force")], help: "Skip confirmation prompts"),
          ]
        )
      ),
      usageExamples: [
        "remindctl list --json",
        "remindctl list Work --json",
        "remindctl list Work --rename Office",
        "remindctl list Work --delete --force",
        "remindctl list Projects --create --json",
      ]
    ) { values, runtime in
      let name = values.argument(0)
      let renameTo = values.option("rename")
      let deleteList = values.flag("delete")
      let createList = values.flag("create")
      let force = values.flag("force")

      let store = RemindersStore()
      try await store.requestAccess()

      if let name {
        if deleteList {
          if !force && !runtime.noInput && Console.isTTY {
            if !Console.confirm("Delete list \"\(name)\"?", defaultValue: false) {
              return
            }
          }
          try await store.deleteList(name: name)
          if runtime.outputFormat == .standard {
            Swift.print("Deleted list \"\(name)\"")
          }
          return
        }

        if let renameTo {
          try await store.renameList(oldName: name, newName: renameTo)
          if runtime.outputFormat == .standard {
            Swift.print("Renamed list \"\(name)\" -> \"\(renameTo)\"")
          }
          return
        }

        if createList {
          let list = try await store.createList(name: name)
          if runtime.outputFormat == .json {
            OutputRenderer.printLists(
              [ListSummary(id: list.id, title: list.title, reminderCount: 0, overdueCount: 0)],
              format: runtime.outputFormat
            )
          } else if runtime.outputFormat == .standard {
            Swift.print("Created list \"\(list.title)\"")
          }
          return
        }

        let reminders = try await store.reminders(in: name)
        OutputRenderer.printReminders(reminders, format: runtime.outputFormat)
        return
      }

      let lists = await store.lists()
      let reminders = try await store.reminders(in: nil)

      let startOfToday = Calendar.current.startOfDay(for: Date())
      var counts: [String: (total: Int, overdue: Int)] = [:]
      for reminder in reminders where !reminder.isCompleted {
        let entry = counts[reminder.listID] ?? (0, 0)
        let overdue = (reminder.dueDate.map { $0 < startOfToday } ?? false) ? 1 : 0
        counts[reminder.listID] = (entry.total + 1, entry.overdue + overdue)
      }

      let summaries = lists.map { list in
        let entry = counts[list.id] ?? (0, 0)
        return ListSummary(
          id: list.id,
          title: list.title,
          reminderCount: entry.total,
          overdueCount: entry.overdue
        )
      }

      OutputRenderer.printLists(summaries, format: runtime.outputFormat)
    }
  }
}
