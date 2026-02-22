# remindctl

Forget the app, not the task ✅

Fast CLI for Apple Reminders on macOS.

## Install

### Homebrew (Home Pro)
```bash
brew install steipete/tap/remindctl
```

### From source
```bash
pnpm install
pnpm build
# binary at ./bin/remindctl
```

## Development
```bash
make remindctl ARGS="status"   # clean build + run
make check                     # lint + test + coverage gate
```

## Requirements
- macOS 14+ (Sonoma or later)
- Swift 6.2+
- Reminders permission (System Settings → Privacy & Security → Reminders)

## Usage

```bash
# Show reminders (filters can be used as top-level shortcuts)
remindctl                       # show today (default, includes overdue)
remindctl today                 # same as above
remindctl tomorrow              # show tomorrow
remindctl week                  # show this week
remindctl overdue               # overdue only
remindctl upcoming              # upcoming with due dates
remindctl open                  # all incomplete reminders
remindctl completed             # completed
remindctl all                   # everything
remindctl 2026-01-03            # specific date

# Lists
remindctl list                  # show all lists with counts
remindctl list Work             # show reminders in a list
remindctl list Work --rename Office
remindctl list Work --delete --force
remindctl list Projects --create

# Add reminders
remindctl add "Buy milk"
remindctl add --title "Call mom" --list Personal --due tomorrow
remindctl add "Review docs" --priority high --due 2026-03-01
remindctl add "Standup" --due tomorrow --recurrence daily --alarm -15m
remindctl add "Biweekly" --recurrence 2-weekly --recurrence-days mon,fri
remindctl add "Task" --due tomorrow --start-date today --timezone America/New_York
remindctl add "Leave home" --location-alarm "Home:37.77,-122.42:100:leave"

# Edit (by index from show output or 4+ char UUID prefix)
remindctl edit 1 --title "New title" --due 2026-01-04
remindctl edit 1 2 3 --priority high --list Work
remindctl edit 3 --clear-due --clear-recurrence
remindctl edit 2 --complete

# Complete & delete
remindctl complete 1 2 3
remindctl delete 4A83 --force

# Permissions
remindctl status                # check permission state
remindctl authorize             # request permissions

# Shell completions
eval "$(remindctl completions zsh)"
```

Command aliases: `ls`/`lists` → `list`, `rm` → `delete`, `done` → `complete`.

## Automation

Use `--json` for structured output and `--no-input` to disable interactive prompts.

```bash
remindctl show --json                     # JSON array of reminders
remindctl add "Task" --json --no-input    # create and return JSON
remindctl status --json                   # {"status":"fullAccess","authorized":true}
remindctl delete 1 --force --json         # {"deleted":1}
```

## Output formats

| Flag | Description |
|------|-------------|
| `--json` | Machine-readable JSON arrays/objects |
| `--plain` | Tab-separated lines (stable for parsing) |
| `--quiet` | Counts only |
| `--no-input` | Disable interactive prompts |
| `--no-color` | Disable colored output |

## Date formats

Accepted by `--due`, `--start-date`, and filter arguments:
- `today`, `tomorrow`, `yesterday`, `now`
- `YYYY-MM-DD`
- `YYYY-MM-DD HH:mm`
- ISO 8601 (`2026-01-03T12:34:56Z`)

## Recurrence

```bash
--recurrence daily                     # every day
--recurrence weekly                    # every week
--recurrence 2-weekly                  # every 2 weeks
--recurrence "every 3 months"          # every 3 months
--recurrence-days mon,wed,fri          # specific days of week
--recurrence-month-days 1,15,-1        # specific days of month (-1 = last)
--recurrence-months jan,jul            # specific months (names or 1-12)
--recurrence-end 10x                   # end after 10 occurrences
--recurrence-end 2026-12-31            # end on date
```

## Alarms

```bash
--alarm -15m                           # 15 minutes before due
--alarm -1h                            # 1 hour before
--alarm -1d                            # 1 day before
--alarm 0                              # at due time
--alarm "2026-03-01 09:00"             # absolute date
--location-alarm "Home:37.77,-122.42:100:leave"   # geofenced
```

Alarm flags are repeatable — use multiple `--alarm` flags for multiple alarms.
Location alarm format: `"title:lat,lng:radius:enter|leave"`.

## Permissions

Run `remindctl authorize` to trigger the system prompt. If access is denied, enable
Terminal (or remindctl) in System Settings → Privacy & Security → Reminders.
If running over SSH, grant access on the Mac that runs the command.
