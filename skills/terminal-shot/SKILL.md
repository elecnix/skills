---
name: terminal-shot
description: Capture terminal screenshots as PNG or SVG for pull requests, docs and cards, with termframe (preferred) or termshot (fallback). Covers macOS and Linux, the font setup that keeps blocks, box-drawing and Nerd Font glyphs seamless, and a check that proves the font renders correctly.
license: MIT
metadata:
  author: elecnix
  version: "1.1"
---

# Terminal screenshots (TermShot)

Two harnesses, one job: turn terminal output into an image that can go in a pull request, a document or a card.

| Harness | Model | Use it for |
|---|---|---|
| **termframe** | emulates a screen, renders a full-screen TUI | the default; anything drawn by a TUI, including a captured tmux pane |
| **termshot** | renders the output of one command | fallback when termframe is unavailable |

Both write SVG; `rsvg-convert` turns that into PNG. The font matters: a missing or wrong font draws blocks and box-drawing characters short, which shows up as black bars through a logo, and turns Nerd Font icons into empty boxes.

## macOS

```sh
brew install termframe librsvg
brew install --cask font-jetbrains-mono
```

`termshot` is the fallback: `cargo install termshot`, or take a release binary.

## Linux

```sh
# PNG conversion (rsvg-convert) and the text font
sudo apt-get install -y librsvg2-bin fonts-jetbrains-mono

# termframe 0.10.0, Linux x86_64 (use the arm64 asset on arm64)
mkdir -p ~/.local/bin
curl -sSfL https://github.com/pamburus/termframe/releases/download/v0.10.0/termframe-linux-x86_64-gnu.tar.gz \
  | tar xz -C ~/.local/bin

# termshot 0.6.1 as the fallback
curl -sSfL -o /tmp/termshot.tgz https://github.com/homeport/termshot/releases/download/v0.6.1/termshot_0.6.1_linux_amd64.tar.gz
tar xzf /tmp/termshot.tgz -C ~/.local/bin
```

Verify with `termframe --version`, `termshot --version` and `rsvg-convert --version`.

Nerd Font icons (private-use area, used by pi's own UI and by status bar extensions) need a symbols font:

```sh
curl -sSfL -o /tmp/nerdfont.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip
unzip -o /tmp/nerdfont.zip -d /tmp/nerdfont
mkdir -p ~/.local/share/fonts
cp /tmp/nerdfont/SymbolsNerdFontMono-Regular.ttf ~/.local/share/fonts/
fc-cache -f ~/.local/share/fonts
```

### Point termframe at local fonts

termframe's built-in defaults name **remote** font files: the default JetBrains Mono entry downloads from `raw.githubusercontent.com`. On a host whose IPv6 route to GitHub blackholes, every render hangs for minutes in `connect(2)` instead of failing. The fix is a config that names local files:

```toml
# ~/.config/termframe/config.toml
[font]
family = ["JetBrains Mono", "Symbols Nerd Font Mono"]

[[fonts]]
family = "JetBrains Mono"
files = [
  "/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Regular.ttf",
  "/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Italic.ttf",
]

[[fonts]]
family = "Symbols Nerd Font Mono"
files = ["/home/USER/.local/share/fonts/SymbolsNerdFontMono-Regular.ttf"]
```

With the config in place a render finishes in well under a second. `--mode dark` does not help with the hang; only the local font files do.

### Capture a full-screen TUI

```sh
# 1. Run the TUI in tmux, wide enough that nothing is truncated.
tmux new-session -d -s cap -x 140 -y 26 "cd /path/to/project && pi --no-session"

# 2. Wait for a settled frame: two identical captures, with the banner on screen.
prev=""
for _ in $(seq 1 80); do
  cur=$(tmux capture-pane -p -t cap 2>/dev/null || true)
  [[ "$cur" == "$prev" && "$cur" == *"[Extensions]"* ]] && break
  prev=$cur
  sleep 0.4
done

# 3. Replay the pane, escapes and all, through the emulator.
tmux capture-pane -e -p -t cap > /tmp/screen.ansi
termframe -W 140 -H 26 -o /tmp/shot.svg < /tmp/screen.ansi

# 4. Convert at 2x so the text is legible in a browser.
rsvg-convert -z 2 -o /tmp/shot.png /tmp/shot.svg

tmux kill-session -t cap
```

## Check the font

`scripts/fontcheck.py` renders a grid of full blocks and fails when it finds a background seam inside the filled area, which is exactly the black-bar symptom, or when the renderer reports a glyph the configured fonts do not cover.

```sh
python3 scripts/fontcheck.py --config ~/.config/termframe/config.toml
# PASS: 135x129px block area, 0 background row(s), 0 background column(s) inside it
```

Run it after changing a font, and on any new machine, before trusting a screenshot of a logo or a progress bar.

## Pitfalls

- **Do not poll for a footer string to decide the screen is ready.** Status bars draw early; the banner and the settled-frame test are what say the TUI has finished loading.
- **Capture wider than the content.** Status bars truncate at the right edge, and a segment pushed off-screen is invisible proof.
- **Pipe into termframe; do not ask it to run `cat`.** `termframe -- cat file.ansi` waits forever; `termframe -o out.svg < file.ansi` does not.
- **A missing font is silent.** termframe logs `font not found for character ...` and draws an empty box; the font check turns that into a failure.
- **Composers fight over the footer.** With more than one footer extension loaded, the last one to install the footer owns it; capture the one you mean to show.
