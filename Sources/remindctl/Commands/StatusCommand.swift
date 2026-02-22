import Commander
import Foundation
import RemindCore

enum StatusCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "status",
      abstract: "Show Reminders authorization status",
      discussion: """
        Reports the current Reminders permission state without triggering a prompt.
        States: fullAccess, writeOnly, denied, restricted, notDetermined.

        JSON output: {"status": "<state>", "authorized": true|false}.
        Exit code is 0 regardless of state. Check 'authorized' for programmatic use.
        If not authorized, run 'remindctl authorize' first.
        """,
      signature: CommandSignatures.withRuntimeFlags(CommandSignature()),
      usageExamples: [
        "remindctl status",
        "remindctl status --json",
        "remindctl status --plain",
      ]
    ) { _, runtime in
      let status = RemindersStore.authorizationStatus()
      OutputRenderer.printAuthorizationStatus(status, format: runtime.outputFormat)
      if runtime.outputFormat == .standard, !status.isAuthorized {
        for line in PermissionsHelp.guidanceLines(for: status) {
          Swift.print(line)
        }
      }
    }
  }
}
