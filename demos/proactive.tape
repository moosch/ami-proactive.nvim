# ami-proactive — an unsolicited suggestion (nudge)
#
# Record with:  vhs demos/proactive.tape
# Needs `vhs` + a running LM Studio, ami core, and ami-chat.nvim checked out next to
# this repo (suggestions land in the chat panel). Set $AMI_CORE / $AMI_ENDPOINT /
# $AMI_CHAT_MODEL as needed.
#
# :AmiNudge forces one suggestion now (bypassing the enable flag + rate limit).
# Lengthen the Sleep after it for slower models.

Output demos/proactive.gif

Require nvim
Set Shell "bash"
Set FontSize 18
Set Width 1280
Set Height 760
Set Padding 20
Set Framerate 24
Set TypingSpeed 45ms
Set Theme "Catppuccin Mocha"

# --- setup (hidden): write a source file and open it ---
# \042 is printf's octal for a double quote; %% prints a literal %.
Hide
Type "printf 'package store\n\nimport (\n\t\042context\042\n\t\042database/sql\042\n\t\042errors\042\n\t\042fmt\042\n)\n\nvar ErrNotFound = errors.New(\042store: user not found\042)\n\n// Get loads one user by id, returning ErrNotFound when the row is absent.\nfunc Get(ctx context.Context, db *sql.DB, id string) (*User, error) {\n\trow := db.QueryRowContext(ctx, \042SELECT id, name, email FROM users WHERE id = $1\042, id)\n\tvar u User\n\tif err := row.Scan(&u.ID, &u.Name, &u.Email); err != nil {\n\t\treturn nil, fmt.Errorf(\042store.Get(%%q): %%w\042, id, err)\n\t}\n\treturn &u, nil\n}\n' > /tmp/ami_proactive_demo.go"
Enter
Type "nvim -u demos/init.lua /tmp/ami_proactive_demo.go"
Enter
Sleep 5s           # let the daemon start and become ready
Show
Sleep 1s

# --- with the SOURCE file focused, ask for a suggestion now ---
# (nudge gathers context from the focused code buffer, not the chat prompt).
Type ":AmiNudge"
Enter
Sleep 2s

# --- open the panel to watch the 💡 suggestion land in the transcript ---
Type ":AmiChat"
Enter
Escape
Sleep 18s
