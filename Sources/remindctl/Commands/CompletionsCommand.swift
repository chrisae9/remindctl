import Commander
import Foundation
import RemindCore

enum CompletionsCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "completions",
      abstract: "Generate shell completions",
      discussion: "Outputs a completion script for the given shell.",
      signature: CommandSignatures.withRuntimeFlags(
        CommandSignature(
          arguments: [
            .make(label: "shell", help: "bash|zsh|fish", isOptional: false)
          ]
        )
      ),
      usageExamples: [
        "remindctl completions bash",
        "remindctl completions zsh",
        "eval \"$(remindctl completions zsh)\"",
      ]
    ) { values, _ in
      guard let shell = values.argument(0) else {
        throw ParsedValuesError.missingArgument("shell")
      }
      switch shell.lowercased() {
      case "bash":
        Swift.print(bashCompletions)
      case "zsh":
        Swift.print(zshCompletions)
      case "fish":
        Swift.print(fishCompletions)
      default:
        throw RemindCoreError.operationFailed("Unsupported shell: \"\(shell)\" (use bash|zsh|fish)")
      }
    }
  }

  // MARK: - Bash

  private static let bashCompletions = """
    _remindctl() {
        local cur prev commands filters
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"

        commands="show list add edit complete delete status authorize completions"
        filters="today tomorrow week overdue upcoming open completed all"

        if [[ ${COMP_CWORD} -eq 1 ]]; then
            COMPREPLY=( $(compgen -W "${commands} ${filters}" -- "${cur}") )
            return 0
        fi

        case "${COMP_WORDS[1]}" in
            show)
                if [[ "${cur}" == -* ]]; then
                    COMPREPLY=( $(compgen -W "--list --search --json --plain --quiet --no-color" -- "${cur}") )
                else
                    COMPREPLY=( $(compgen -W "${filters}" -- "${cur}") )
                fi
                ;;
            add)
                COMPREPLY=( $(compgen -W "--title --list --due --notes --priority --recurrence --start-date --timezone --json --plain --quiet" -- "${cur}") )
                ;;
            edit)
                COMPREPLY=( $(compgen -W "--title --list --due --notes --priority --recurrence --start-date --timezone --clear-due --clear-recurrence --clear-start-date --clear-timezone --complete --incomplete --json --plain --quiet" -- "${cur}") )
                ;;
            list)
                COMPREPLY=( $(compgen -W "--rename --delete --create --force --json --plain --quiet" -- "${cur}") )
                ;;
            complete)
                COMPREPLY=( $(compgen -W "--dry-run --json --plain --quiet" -- "${cur}") )
                ;;
            delete)
                COMPREPLY=( $(compgen -W "--dry-run --force --json --plain --quiet" -- "${cur}") )
                ;;
            completions)
                COMPREPLY=( $(compgen -W "bash zsh fish" -- "${cur}") )
                ;;
        esac
        return 0
    }
    complete -F _remindctl remindctl
    """

  // MARK: - Zsh

  private static let zshCompletions = """
    #compdef remindctl

    _remindctl_filters() {
        local filters=(
            'today:Show today and overdue'
            'tomorrow:Show tomorrow'
            'week:Show this week'
            'overdue:Show overdue'
            'upcoming:Show upcoming with due dates'
            'open:Show all incomplete'
            'completed:Show completed'
            'all:Show all reminders'
        )
        _describe 'filter' filters
    }

    _remindctl() {
        local -a commands
        commands=(
            'show:Show reminders'
            'list:List reminder lists or show list contents'
            'add:Add a reminder'
            'edit:Edit a reminder'
            'complete:Mark reminders complete'
            'delete:Delete reminders'
            'status:Show authorization status'
            'authorize:Request Reminders permission'
            'completions:Generate shell completions'
        )

        _arguments -C \\
            '--help[Show help]' \\
            '--version[Show version]' \\
            '1:command:->command' \\
            '*::arg:->args'

        case $state in
            command)
                _describe 'command' commands
                _remindctl_filters
                ;;
            args)
                case ${words[1]} in
                    show)
                        _arguments \\
                            '1:filter:_remindctl_filters' \\
                            '--list[Limit to a specific list]:list name:' \\
                            '(-s --search)'{-s,--search}'[Filter by text]:query:' \\
                            '(-j --json)'{-j,--json}'[JSON output]' \\
                            '--plain[Plain output]' \\
                            '(-q --quiet)'{-q,--quiet}'[Quiet output]' \\
                            '--no-color[Disable colors]'
                        ;;
                    add)
                        _arguments \\
                            '1:title:' \\
                            '--title[Reminder title]:title:' \\
                            '(-l --list)'{-l,--list}'[List name]:list name:' \\
                            '(-d --due)'{-d,--due}'[Due date]:date:' \\
                            '(-n --notes)'{-n,--notes}'[Notes]:notes:' \\
                            '(-p --priority)'{-p,--priority}'[Priority]:priority:(none low medium high)' \\
                            '(-r --recurrence)'{-r,--recurrence}'[Recurrence]:frequency:(daily weekly monthly yearly)' \\
                            '--start-date[Start date]:date:' \\
                            '--timezone[IANA timezone]:timezone:' \\
                            '(-j --json)'{-j,--json}'[JSON output]' \\
                            '--plain[Plain output]' \\
                            '(-q --quiet)'{-q,--quiet}'[Quiet output]'
                        ;;
                    edit)
                        _arguments \\
                            '1:id:' \\
                            '(-t --title)'{-t,--title}'[New title]:title:' \\
                            '(-l --list)'{-l,--list}'[Move to list]:list name:' \\
                            '(-d --due)'{-d,--due}'[Set due date]:date:' \\
                            '(-n --notes)'{-n,--notes}'[Set notes]:notes:' \\
                            '(-p --priority)'{-p,--priority}'[Priority]:priority:(none low medium high)' \\
                            '(-r --recurrence)'{-r,--recurrence}'[Recurrence]:frequency:(daily weekly monthly yearly)' \\
                            '--start-date[Set start date]:date:' \\
                            '--timezone[IANA timezone]:timezone:' \\
                            '--clear-due[Clear due date]' \\
                            '--clear-recurrence[Clear recurrence]' \\
                            '--clear-start-date[Clear start date]' \\
                            '--clear-timezone[Clear timezone]' \\
                            '--complete[Mark completed]' \\
                            '--incomplete[Mark incomplete]' \\
                            '(-j --json)'{-j,--json}'[JSON output]' \\
                            '--plain[Plain output]' \\
                            '(-q --quiet)'{-q,--quiet}'[Quiet output]'
                        ;;
                    list)
                        _arguments \\
                            '1:name:' \\
                            '(-r --rename)'{-r,--rename}'[Rename list]:new name:' \\
                            '(-d --delete)'{-d,--delete}'[Delete list]' \\
                            '--create[Create list]' \\
                            '(-f --force)'{-f,--force}'[Skip confirmation]' \\
                            '(-j --json)'{-j,--json}'[JSON output]' \\
                            '--plain[Plain output]' \\
                            '(-q --quiet)'{-q,--quiet}'[Quiet output]'
                        ;;
                    complete)
                        _arguments \\
                            '*:id:' \\
                            '(-n --dry-run)'{-n,--dry-run}'[Preview without changes]' \\
                            '(-j --json)'{-j,--json}'[JSON output]' \\
                            '--plain[Plain output]' \\
                            '(-q --quiet)'{-q,--quiet}'[Quiet output]'
                        ;;
                    delete)
                        _arguments \\
                            '*:id:' \\
                            '(-n --dry-run)'{-n,--dry-run}'[Preview without changes]' \\
                            '(-f --force)'{-f,--force}'[Skip confirmation]' \\
                            '(-j --json)'{-j,--json}'[JSON output]' \\
                            '--plain[Plain output]' \\
                            '(-q --quiet)'{-q,--quiet}'[Quiet output]'
                        ;;
                    completions)
                        _arguments '1:shell:(bash zsh fish)'
                        ;;
                esac
                ;;
        esac
    }

    _remindctl "$@"
    """

  // MARK: - Fish

  private static let fishCompletions = """
    # Commands
    set -l commands show list add edit complete delete status authorize completions
    set -l filters today tomorrow week overdue upcoming open completed all

    complete -c remindctl -f

    # Subcommands
    complete -c remindctl -n "not __fish_seen_subcommand_from $commands" -a show -d "Show reminders"
    complete -c remindctl -n "not __fish_seen_subcommand_from $commands" -a list -d "List reminder lists"
    complete -c remindctl -n "not __fish_seen_subcommand_from $commands" -a add -d "Add a reminder"
    complete -c remindctl -n "not __fish_seen_subcommand_from $commands" -a edit -d "Edit a reminder"
    complete -c remindctl -n "not __fish_seen_subcommand_from $commands" -a complete -d "Mark reminders complete"
    complete -c remindctl -n "not __fish_seen_subcommand_from $commands" -a delete -d "Delete reminders"
    complete -c remindctl -n "not __fish_seen_subcommand_from $commands" -a status -d "Show authorization status"
    complete -c remindctl -n "not __fish_seen_subcommand_from $commands" -a authorize -d "Request permission"
    complete -c remindctl -n "not __fish_seen_subcommand_from $commands" -a completions -d "Generate completions"

    # Filters as top-level shortcuts
    for f in $filters
        complete -c remindctl -n "not __fish_seen_subcommand_from $commands" -a $f
    end

    # show
    complete -c remindctl -n "__fish_seen_subcommand_from show" -a "$filters"
    complete -c remindctl -n "__fish_seen_subcommand_from show" -l list -s l -r -d "Limit to list"
    complete -c remindctl -n "__fish_seen_subcommand_from show" -l search -s s -r -d "Filter by text"
    complete -c remindctl -n "__fish_seen_subcommand_from show" -l json -s j -d "JSON output"
    complete -c remindctl -n "__fish_seen_subcommand_from show" -l plain -d "Plain output"
    complete -c remindctl -n "__fish_seen_subcommand_from show" -l quiet -s q -d "Quiet output"

    # add
    complete -c remindctl -n "__fish_seen_subcommand_from add" -l title -r -d "Title"
    complete -c remindctl -n "__fish_seen_subcommand_from add" -l list -s l -r -d "List name"
    complete -c remindctl -n "__fish_seen_subcommand_from add" -l due -s d -r -d "Due date"
    complete -c remindctl -n "__fish_seen_subcommand_from add" -l notes -s n -r -d "Notes"
    complete -c remindctl -n "__fish_seen_subcommand_from add" -l priority -s p -r -a "none low medium high" -d "Priority"
    complete -c remindctl -n "__fish_seen_subcommand_from add" -l recurrence -s r -r -a "daily weekly monthly yearly" -d "Recurrence"
    complete -c remindctl -n "__fish_seen_subcommand_from add" -l start-date -r -d "Start date"
    complete -c remindctl -n "__fish_seen_subcommand_from add" -l timezone -r -d "IANA timezone"

    # edit
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l title -s t -r -d "New title"
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l list -s l -r -d "Move to list"
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l due -s d -r -d "Due date"
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l notes -s n -r -d "Notes"
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l priority -s p -r -a "none low medium high" -d "Priority"
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l recurrence -s r -r -a "daily weekly monthly yearly" -d "Recurrence"
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l start-date -r -d "Start date"
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l timezone -r -d "IANA timezone"
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l clear-due -d "Clear due date"
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l clear-recurrence -d "Clear recurrence"
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l clear-start-date -d "Clear start date"
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l clear-timezone -d "Clear timezone"
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l complete -d "Mark completed"
    complete -c remindctl -n "__fish_seen_subcommand_from edit" -l incomplete -d "Mark incomplete"

    # list
    complete -c remindctl -n "__fish_seen_subcommand_from list" -l rename -s r -r -d "Rename list"
    complete -c remindctl -n "__fish_seen_subcommand_from list" -l delete -s d -d "Delete list"
    complete -c remindctl -n "__fish_seen_subcommand_from list" -l create -d "Create list"
    complete -c remindctl -n "__fish_seen_subcommand_from list" -l force -s f -d "Skip confirmation"

    # complete
    complete -c remindctl -n "__fish_seen_subcommand_from complete" -l dry-run -s n -d "Preview"

    # delete
    complete -c remindctl -n "__fish_seen_subcommand_from delete" -l dry-run -s n -d "Preview"
    complete -c remindctl -n "__fish_seen_subcommand_from delete" -l force -s f -d "Skip confirmation"

    # completions
    complete -c remindctl -n "__fish_seen_subcommand_from completions" -a "bash zsh fish"
    """
}
