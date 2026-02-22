import Foundation

public enum RemindCoreError: LocalizedError, Sendable, Equatable {
  case accessDenied
  case accessRestricted
  case writeOnlyAccess
  case listNotFound(String)
  case reminderNotFound(String)
  case ambiguousIdentifier(String, matches: [String])
  case invalidIdentifier(String)
  case invalidDate(String)
  case unsupported(String)
  case operationFailed(String)
  case eventKitError(String, detail: String)

  public var errorDescription: String? {
    switch self {
    case .accessDenied:
      return [
        "Reminders access denied.",
        "Run `remindctl authorize` to request permission, then allow Terminal (or remindctl)",
        "in System Settings > Privacy & Security > Reminders.",
        "If running over SSH, grant access on the Mac that runs the command.",
      ].joined(separator: " ")
    case .accessRestricted:
      return [
        "Reminders access is restricted by a system policy (parental controls, MDM, or Screen Time).",
        "Contact your administrator or check Screen Time settings to allow Reminders access.",
      ].joined(separator: " ")
    case .writeOnlyAccess:
      return [
        "Reminders access is write-only — reading reminders is not permitted.",
        "Change to Full Access in System Settings > Privacy & Security > Reminders.",
      ].joined(separator: " ")
    case .listNotFound(let name):
      return "List not found: \"\(name)\". Run `remindctl list` to see available lists."
    case .reminderNotFound(let id):
      return "Reminder not found: \"\(id)\". It may have been deleted or the ID may be stale. Run `remindctl show all` to refresh."
    case .ambiguousIdentifier(let input, let matches):
      return "Identifier \"\(input)\" matches multiple reminders: \(matches.joined(separator: ", ")). Use a longer prefix to disambiguate."
    case .invalidIdentifier(let input):
      return "Invalid identifier: \"\(input)\". Use an index number from show output or at least 4 characters of an ID."
    case .invalidDate(let input):
      return "Invalid date: \"\(input)\". Accepted formats: today, tomorrow, YYYY-MM-DD, YYYY-MM-DD HH:mm, ISO 8601."
    case .unsupported(let message):
      return message
    case .operationFailed(let message):
      return message
    case .eventKitError(let operation, let detail):
      return "Failed to \(operation): \(detail). Check Reminders access with `remindctl status`."
    }
  }
}
