# Handoff — ytdl-accessible

Written 2026-08-17 at the end of the session that built it. Read this first,
then `CLAUDE.md` (the `ytdl` and `ytdescribe` sections) for the reasoning
behind each decision.

## What exists, and where

| thing | where | note |
|---|---|---|
| `ytdl` | `~/ytdl-accessible/ytdl` | `~/bin/ytdl` is a **symlink** into the repo |
| `ytdescribe` | same repo | `~/bin/ytdescribe` likewise |
| Media Download.app | `/Applications` | compiled from `MediaDownload.applescript` |
| public repo | [Matthew2244/ytdl-accessible](https://github.com/Matthew2244/ytdl-accessible) | MIT |
| private notes | [Matthew2244/claude-setup](https://github.com/Matthew2244/claude-setup) | `~/CLAUDE.md` symlinks into it |

The app is the **only** thing that is a build rather than a symlink. Edit the
AppleScript and it does nothing until you recompile:

    osacompile -o "/Applications/Media Download.app" \
      ~/ytdl-accessible/MediaDownload.applescript

## Before you commit

    ./check.sh

Non-negotiable. It exists because a non-compiling AppleScript was committed and
pushed in this very session — the compile error scrolled past in a chained
command and the app was left missing from `/Applications`. It exits non-zero.

## State

Everything is committed and pushed. Both repos clean, both heads matching
GitHub. `claude-setup` also pushes itself daily at 9 PM via
`com.matthew.claude-setup-sync`.

Matthew's settings: format `best`, downloads to iCloud Drive / `Media
Downloads`, notify off, progress off, auto-update on.

## The things that will bite you

Ordered by how much time they cost the first time.

1. **A GUI-launched app gets a minimal `PATH`** with no Homebrew, so `yt-dlp`
   is invisible and every download fails while the identical command works in a
   terminal. Every `do shell script` exports `PATH` first.
2. **A dialog button set as both default and cancel makes Escape do nothing.**
   Measured. It is also the shape you write by accident. `check.sh` fails on it.
3. **`choose from list` ignores Escape and Command-period entirely.** Its Cancel
   button is clickable but no key reaches it, so every list carries a **Back**
   item.
4. **Command-Q and Command-W cannot work** — an `osacompile` applet has no menu
   bar, and `display dialog` blocks menus anyway. Do not go hunting.
5. **AppleScript allows one `on error` per `try`.** Two is a compile error, and
   that is what got pushed broken.
6. **Playlists need `--flat-playlist`** for metadata, or `-J` extracts every
   entry in full and times out on anything channel-sized.
7. **`--sub-langs "en.*"` earns an HTTP 429** by matching every auto-translated
   variant. Name the real tracks.
8. **A saved default format must not transcode a stream named by `--format-id`.**

## Not done / worth considering

- `ytdescribe`'s generation path is verified on a synthetic five-shot reel and
  one real short video, **not** on a long real video. Worth one real run.
- The spoken description **ducks** the original rather than fitting the gaps.
  Real AD uses the pauses; deciding which line outranks which piece of dialogue
  is editorial judgement the tool cannot make. Documented as a limitation.
- YouTube rate-limited this machine twice during testing. If something 403s
  soon after heavy use, wait rather than debug.
- `.opus` still has no default app on Matthew's Mac. Not a problem while his
  format default is `best`… except `best` often *is* Opus. One Get Info →
  Change All on any `.opus` file would settle it permanently.
