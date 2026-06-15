# termcraft

One script to forge a beautiful Debian-Hyprland-style terminal.

![termcraft POC](./terminal_modifier_POC.png)

## What it does

Transforms a bare Debian/Ubuntu terminal into a fully styled powerhouse:

- **zsh** + **Oh My Zsh** with **agnosterzak** theme
- **JetBrainsMono Nerd Font** for crisp icons and glyphs
- **Tokyo Night** color palette (Catppuccin, Dracula, Gruvbox also available)
- **lsd** — modern `ls` with icons and colors
- **fastfetch** — compact system info on shell start
- **XFCE Terminal** — transparency + font + palette via xfconf or terminalrc

## Quick Start

```bash
chmod +x terminal_modifier.sh
./terminal_modifier.sh
```

Open a new terminal window and enjoy your new look.

## Usage

```
./terminal_modifier.sh [OPTIONS]
```

| Flag | Description |
|------|-------------|
| `--scheme tokyonight` | Color scheme (default) — also: catppuccin, dracula, gruvbox, none |
| `--chsh` | Also set zsh as your default shell |
| `--verbose` | Show verbose output (no spinner) |
| `--no-color` | Disable colored output |
| `--no-spinner` | Disable spinner animation |

## Requirements

- Debian / Ubuntu (uses `apt-get`)
- Regular user (not root)

## After Install

- If colors look wrong in xfce4-terminal, log out and back in (xfconf cache).
- If prompt glyphs show as boxes, set terminal font to **JetBrainsMono Nerd Font** explicitly.
- For real transparency: XFCE Settings → Window Manager Tweaks → Compositor.

## Author

**Dickson Massawe** — [@archnexus707](https://github.com/archnexus707)

## Support

If termcraft made your terminal glow, consider buying me a coffee:

[![](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-archnexus707@gmail.com-yellow?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](mailto:archnexus707@gmail.com)

## License

MIT — see [LICENSE](./LICENSE)
