# Visual Studio Code

## Automation tip `shift-enter`

If you work with automations and different scripts a lot, you
might find that sending commands directly from VS Code editor to terminal
speeds up your development a lot. This works with all kind files including markdown!

Open `Show all commands` (Windows: `Ctrl-shift-p` or `F1`).

Open `Preferences: Open keyboard shortcuts`.

Find `Terminal: Run Selected Text In Active Terminal` and set that be your
preferred shortcut e.g., `shift-enter`.

*Note:* You need to then search with that shortcut to remove other shortcuts
that might overlap with your selection.

Now you're ready to test this. Just create **any** file and put some command to it e.g.

```bash
echo "Sending command from file"
```

Then `shift-enter` when cursor is on that line and then it will be automatically executed in active terminal.
For multi-line commands you just select all that text that should be send to terminal.

If you want enhanced scripting experience, then you might want to install [Send snippet to Terminal](https://marketplace.visualstudio.com/items?itemName=jannemattila.send-snippet-to-terminal) VS Code extension.
