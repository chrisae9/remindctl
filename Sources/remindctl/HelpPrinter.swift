import Commander
import Foundation

struct HelpPrinter {
  static func printRoot(version: String, rootName: String, commands: [CommandSpec]) {
    for line in renderRoot(version: version, rootName: rootName, commands: commands) {
      Swift.print(line)
    }
  }

  static func printCommand(rootName: String, spec: CommandSpec) {
    for line in renderCommand(rootName: rootName, spec: spec) {
      Swift.print(line)
    }
  }

  static func renderRoot(version: String, rootName: String, commands: [CommandSpec]) -> [String] {
    var lines: [String] = []
    lines.append("\(rootName) \(version)")
    lines.append("Manage Apple Reminders from the terminal")
    lines.append("")
    lines.append("AUTOMATION: Use --json for structured output, --no-input to disable prompts.")
    lines.append("")
    lines.append("Usage:")
    lines.append("  \(rootName) [command] [options]")
    lines.append("  \(rootName) [filter]                Shortcut for 'show <filter>'")
    lines.append("")

    lines.append("Commands:")
    let maxLen = commands.map(\.name.count).max() ?? 0
    for command in commands {
      let pad = String(repeating: " ", count: maxLen - command.name.count + 2)
      lines.append("  \(command.name)\(pad)\(command.abstract)")
    }
    lines.append("")

    lines.append("Aliases: lists|ls → list, rm → delete, done → complete")
    lines.append("")

    lines.append("Filters (usable as top-level shortcuts):")
    lines.append("  today, tomorrow, week, overdue, upcoming, open, completed, all, <date>")
    lines.append("")

    lines.append("Output Formats:")
    lines.append("  --json       Machine-readable JSON (recommended for automation)")
    lines.append("  --plain      Tab-separated lines (stable for parsing)")
    lines.append("  --quiet      Counts only")
    lines.append("  --no-input   Disable interactive prompts (required for automation)")
    lines.append("  --no-color   Disable colored output")
    lines.append("")

    lines.append("ID Resolution (edit, complete, delete):")
    lines.append("  Index numbers from show output (1, 2, 3) or 4+ char UUID prefixes (4A83).")
    lines.append("  Run '\(rootName) show --json' first to see IDs.")
    lines.append("")

    lines.append("Date Formats (--due, --start-date, filters):")
    lines.append("  today, tomorrow, yesterday, now, YYYY-MM-DD, \"YYYY-MM-DD HH:mm\", ISO 8601")
    lines.append("")

    lines.append("Typical Workflow:")
    lines.append("  1. \(rootName) authorize              Grant permission (first run)")
    lines.append("  2. \(rootName) --json                  List today's reminders as JSON")
    lines.append("  3. \(rootName) add \"Buy milk\" --json   Create a reminder")
    lines.append("  4. \(rootName) edit 1 --due tomorrow   Modify by index from show output")
    lines.append("  5. \(rootName) complete 1              Mark done")
    lines.append("")

    lines.append("Run '\(rootName) <command> --help' for details on a specific command.")
    return lines
  }

  static func renderCommand(rootName: String, spec: CommandSpec) -> [String] {
    var lines: [String] = []
    lines.append("\(rootName) \(spec.name)")
    lines.append(spec.abstract)
    if let discussion = spec.discussion, !discussion.isEmpty {
      lines.append("")
      for line in discussion.split(separator: "\n", omittingEmptySubsequences: false) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        lines.append(trimmed.isEmpty ? "" : trimmed)
      }
    }
    lines.append("")
    lines.append("Usage:")
    lines.append("  \(rootName) \(spec.name) \(usageFragment(for: spec.signature))")
    lines.append("")

    if !spec.signature.arguments.isEmpty {
      lines.append("Arguments:")
      let maxArgLen = spec.signature.arguments.map { $0.label.count + ($0.isOptional ? 1 : 0) }.max() ?? 0
      for arg in spec.signature.arguments {
        let optionalMark = arg.isOptional ? "?" : ""
        let label = "\(arg.label)\(optionalMark)"
        let pad = String(repeating: " ", count: maxArgLen - label.count + 2)
        lines.append("  \(label)\(pad)\(arg.help ?? "")")
      }
      lines.append("")
    }

    let options = spec.signature.options
    let flags = spec.signature.flags
    if !options.isEmpty || !flags.isEmpty {
      lines.append("Options:")
      var entries: [(String, String)] = []
      for option in options {
        entries.append((formatNames(option.names, expectsValue: true), option.help ?? ""))
      }
      for flag in flags {
        entries.append((formatNames(flag.names, expectsValue: false), flag.help ?? ""))
      }
      let maxNameLen = entries.map(\.0.count).max() ?? 0
      for (name, help) in entries {
        let pad = String(repeating: " ", count: maxNameLen - name.count + 2)
        lines.append("  \(name)\(pad)\(help)")
      }
      lines.append("")
    }

    if !spec.usageExamples.isEmpty {
      lines.append("Examples:")
      for example in spec.usageExamples {
        lines.append("  \(example)")
      }
    }

    return lines
  }

  private static func usageFragment(for signature: CommandSignature) -> String {
    var parts: [String] = []
    for argument in signature.arguments {
      let token = argument.isOptional ? "[\(argument.label)]" : "<\(argument.label)>"
      parts.append(token)
    }
    if !signature.options.isEmpty || !signature.flags.isEmpty {
      parts.append("[options]")
    }
    return parts.joined(separator: " ")
  }

  private static func formatNames(_ names: [CommanderName], expectsValue: Bool) -> String {
    let parts = names.map { name -> String in
      switch name {
      case .short(let char):
        return "-\(char)"
      case .long(let value):
        return "--\(value)"
      case .aliasShort(let char):
        return "-\(char)"
      case .aliasLong(let value):
        return "--\(value)"
      }
    }
    let suffix = expectsValue ? " <value>" : ""
    return parts.joined(separator: ", ") + suffix
  }
}
