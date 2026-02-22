# Manual tests

## Scope
Run on a local GUI session (not SSH-only) so the Reminders permission prompt can appear.

## Test data
- Use a dedicated list: `remindctl-manual-YYYYMMDD` (create if missing).
- Create reminders with distinct states for each feature area.

## Checklist

### Permissions
- [ ] `remindctl authorize`
- [ ] `remindctl status`
- [ ] `remindctl status --json` — verify `{"status":"fullAccess","authorized":true}`

### Lists
- [ ] `remindctl list` — shows all lists with counts
- [ ] `remindctl list --json` — JSON array of list summaries
- [ ] `remindctl list "remindctl-manual-YYYYMMDD" --create`
- [ ] `remindctl list "remindctl-manual-YYYYMMDD"` — shows reminders in list
- [ ] `remindctl list "remindctl-manual-YYYYMMDD" --rename "remindctl-manual-renamed"`
- [ ] `remindctl list "remindctl-manual-renamed" --rename "remindctl-manual-YYYYMMDD"`

### Add reminders
- [ ] Basic: `remindctl add "Test A" --list "remindctl-manual-YYYYMMDD" --due today --priority high`
- [ ] With notes: `remindctl add "Test B" --list "remindctl-manual-YYYYMMDD" --due tomorrow --notes "Some notes"`
- [ ] No due date: `remindctl add "Test C" --list "remindctl-manual-YYYYMMDD"`
- [ ] Start date + timezone: `remindctl add "Test D" --list "remindctl-manual-YYYYMMDD" --due tomorrow --start-date today --timezone America/New_York`
- [ ] Recurrence: `remindctl add "Test E" --list "remindctl-manual-YYYYMMDD" --due tomorrow --recurrence 2-weekly --recurrence-days mon,fri`
- [ ] Recurrence with end: `remindctl add "Test F" --list "remindctl-manual-YYYYMMDD" --due tomorrow --recurrence daily --recurrence-end 5x`
- [ ] Alarm: `remindctl add "Test G" --list "remindctl-manual-YYYYMMDD" --due tomorrow --alarm -15m --alarm -1h`
- [ ] Location alarm: `remindctl add "Test H" --list "remindctl-manual-YYYYMMDD" --location-alarm "Office:37.7749,-122.4194:100:enter"`
- [ ] JSON output: `remindctl add "Test I" --list "remindctl-manual-YYYYMMDD" --json` — verify JSON fields

### Show filters
- [ ] `remindctl today`
- [ ] `remindctl tomorrow`
- [ ] `remindctl week`
- [ ] `remindctl overdue`
- [ ] `remindctl upcoming`
- [ ] `remindctl open`
- [ ] `remindctl completed`
- [ ] `remindctl all`
- [ ] `remindctl show --list "remindctl-manual-YYYYMMDD" --json`
- [ ] `remindctl show all --search "Test A"`

### Edit
- [ ] Update title: `remindctl edit 1 --title "Updated title"`
- [ ] Update priority: `remindctl edit 1 --priority low`
- [ ] Set due date: `remindctl edit 1 --due 2026-06-01`
- [ ] Clear due date: `remindctl edit 1 --clear-due`
- [ ] Set recurrence: `remindctl edit 1 --recurrence weekly`
- [ ] Clear recurrence: `remindctl edit 1 --clear-recurrence`
- [ ] Set start date: `remindctl edit 1 --start-date tomorrow`
- [ ] Clear start date: `remindctl edit 1 --clear-start-date`
- [ ] Set timezone: `remindctl edit 1 --timezone Europe/London`
- [ ] Clear timezone: `remindctl edit 1 --clear-timezone`
- [ ] Set alarms: `remindctl edit 1 --alarm -30m`
- [ ] Clear alarms: `remindctl edit 1 --clear-alarms`
- [ ] Move to list: `remindctl edit 1 --list Work`
- [ ] Multi-edit: `remindctl edit 1 2 3 --priority high`
- [ ] Dry run: `remindctl edit 1 --title "X" --dry-run`
- [ ] Mark complete: `remindctl edit 1 --complete`
- [ ] Mark incomplete: `remindctl edit 1 --incomplete`

### Complete
- [ ] `remindctl complete 1` — mark one
- [ ] `remindctl complete 1 2 3` — mark multiple
- [ ] `remindctl complete 1 --dry-run`
- [ ] `remindctl complete 1 --json`

### Delete
- [ ] `remindctl delete 1 --dry-run` — preview
- [ ] `remindctl delete 1 --force` — skip confirmation
- [ ] `remindctl delete 1 2 3 --force --json` — verify `{"deleted":3}`

### Cleanup
- [ ] `remindctl list "remindctl-manual-YYYYMMDD" --delete --force`

### Output formats
- [ ] `--json` on show, add, edit, complete, delete, list, status
- [ ] `--plain` on show — tab-separated output
- [ ] `--quiet` on show — count only
- [ ] `--no-input` on add (without title) — verify error, no prompt

### Shell completions
- [ ] `remindctl completions bash` — outputs bash script
- [ ] `remindctl completions zsh` — outputs zsh script
- [ ] `remindctl completions fish` — outputs fish script

## Results
- Date:
- Machine:
- Permission state before/after:
- Notes:
