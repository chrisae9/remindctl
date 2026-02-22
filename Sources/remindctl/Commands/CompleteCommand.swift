import Commander
import Foundation
import RemindCore

enum CompleteCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "complete",
      abstract: "Mark reminders complete",
      discussion: """
        Mark one or more reminders as completed. IDs are 1-based index numbers from
        'remindctl show' output or 4+ character UUID prefixes. Multiple IDs can be
        specified as separate arguments.

        Use --dry-run to preview which reminders would be completed without saving.
        Returns the updated reminder(s). Use --json for structured output.
        """,
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "ids", help: "Indexes or ID prefixes", isOptional: true)
          ],
          flags: [
            .make(label: "dryRun", names: [.short("n"), .long("dry-run")], help: "Preview without changes")
          ]
        )
      ),
      usageExamples: [
        "remindctl complete 1 --json",
        "remindctl complete 1 2 3",
        "remindctl complete 4A83",
        "remindctl complete 1 --dry-run",
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

      if values.flag("dryRun") {
        OutputRenderer.printReminders(resolved, format: runtime.outputFormat)
        return
      }

      let updated = try await store.completeReminders(ids: resolved.map { $0.id })
      OutputRenderer.printReminders(updated, format: runtime.outputFormat)
    }
  }
}
