import Commander
import Foundation
import RemindCore

enum AuthorizeCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "authorize",
      abstract: "Request Reminders access",
      discussion: """
        Triggers the macOS Reminders permission prompt if not yet determined.
        If already authorized or denied, reports the current state without prompting.
        Must run from a TTY for the system dialog to appear. After granting access,
        all other commands will work. Exits with code 0 on fullAccess, non-zero otherwise.
        """,
      signature: CommandSignatures.withRuntimeFlags(CommandSignature()),
      usageExamples: [
        "remindctl authorize",
        "remindctl authorize --json",
        "remindctl authorize --quiet",
      ]
    ) { _, runtime in
      let store = RemindersStore()
      let current = RemindersStore.authorizationStatus()
      let status: RemindersAuthorizationStatus
      if current == .notDetermined {
        status = try await store.requestAuthorization()
      } else {
        status = current
      }

      OutputRenderer.printAuthorizationStatus(status, format: runtime.outputFormat)

      switch status {
      case .fullAccess:
        return
      case .writeOnly:
        throw RemindCoreError.writeOnlyAccess
      case .restricted:
        throw RemindCoreError.accessRestricted
      case .notDetermined, .denied:
        throw RemindCoreError.accessDenied
      }
    }
  }
}
