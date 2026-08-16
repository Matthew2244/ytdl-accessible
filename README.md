# ytdl-accessible

A screen-reader-friendly wrapper around [yt-dlp](https://github.com/yt-dlp/yt-dlp) for macOS,
plus a small app so it can be launched from the Applications folder.

## Why this exists

yt-dlp is excellent. Its **output** is the problem if you listen to your computer
rather than look at it.

The default progress display rewrites a single terminal line many times a second
using a carriage return. A screen reader re-announces on every write, so it spends
the entire download interrupting itself and never finishes a sentence. You get a
stream of noise, and no usable information.

`ytdl` runs yt-dlp with progress suppressed and prints **one line per event** instead:

```
Journey Uptown — Matthew Whitaker
6 minutes 42 seconds. About 8 MB.
Downloading...

Done. Saved to Youtube Downloads as Journey Uptown.opus (7.9 MB)
```

`--progress` adds a percentage line at most **every 10 seconds** — slow enough that
a screen reader can finish speaking it before the next one arrives.

Everything else here follows from the same idea: errors are sentences rather than
tracebacks, durations are "6 minutes 42 seconds" rather than `402`, and anything
that would need a glance at a progress bar is instead reported when it matters.

## Requirements

macOS, with [Homebrew](https://brew.sh):

```bash
brew install yt-dlp ffmpeg
```

Homebrew pulls in `deno` alongside yt-dlp, which is what satisfies YouTube's
player challenge. Nothing else is needed.

## Install

```bash
git clone https://github.com/Matthew2244/ytdl-accessible.git ~/ytdl-accessible
ln -s ~/ytdl-accessible/ytdl ~/bin/ytdl     # anywhere on your PATH
```

Optionally, build the Mac app:

```bash
osacompile -o "/Applications/YouTube Download.app" ~/ytdl-accessible/YouTubeDownload.applescript
```

## Usage

```
ytdl                       URL from the clipboard
ytdl <url>                 best audio, original codec
ytdl <url> --wav           decoded WAV, ready for a DAW session
ytdl <url> --video         best video and audio, merged to MP4
ytdl <url> --mp3           MP3 320 (a conversion, and it says so)
ytdl <url> --info          what you would get, downloads nothing

  --to PATH                destination folder
  --name "..."             filename, without extension
  --playlist               opt in to the whole playlist
  --progress               a percentage line every 10 seconds, no faster
  --cookies [BROWSER]      sign-in cookies, for "confirm you're not a bot"
  --notify                 Pushover ping on finish and on failure
  --quiet                  print the final path and nothing else
  --update                 upgrade yt-dlp, and say what actually changed
```

Downloads default to `~/Library/Mobile Documents/com~apple~CloudDocs/Youtube Downloads`
(iCloud Drive). Change it per run with `--to`, or edit `DEST` at the top of the script.

## Design notes

The parts that are less obvious than they look.

**Part-files never touch the destination.** yt-dlp writes `.part` files, per-fragment
chunks, and separate audio and video streams that ffmpeg merges afterwards. Written
straight into a synced folder — iCloud Drive, Dropbox — every one of those syncs to
your other devices and is then deleted. yt-dlp solves this itself with split paths,
so `ytdl` uses `-P temp:` for a local scratch directory and `-P home:` for the real
destination. Only the finished file ever appears there.

**The default never re-encodes.** `-x --audio-format best` keeps the source codec and
only changes the container: AAC lands as `.m4a`, Opus as `.opus`. Preferring `.m4a`
for tidiness would give you the *worse* stream — YouTube's Opus is typically ~106 kbps
against the AAC's ~130 kbps, and Opus wins comfortably at that bitrate. `--mp3` and
`--wav` are conversions, and the help text says so.

**`--info` asks yt-dlp what it would pick** rather than ranking the formats itself.
It passes the same `-f` selector the download will use into the `-J` call and reads
the selection back. An earlier version re-implemented the ranking and confidently
reported the 130 kbps AAC while the download quietly took the 106 kbps Opus.

**Playlists are refused unless asked for.** A URL copied from a queue carries `&list=`
on the end. Honouring that silently would drop a few hundred files on you. The count
comes from `--flat-playlist --playlist-items 0`, which reports `playlist_count`
without fetching the entries.

**No age-based staleness check.** An early version warned when yt-dlp was more than
30 days old, since YouTube breaks extraction regularly. But yt-dlp releases
irregularly, so this called a perfectly current install stale — the warning fired on
every failure and pointed at `--update`, which correctly replied "already up to date".
It now compares against the GitHub releases API, and **stays silent when it cannot
reach it**: "could not check" and "you are behind" must never look the same.

**The app exports PATH before doing anything.** A GUI-launched macOS app inherits a
minimal `PATH` of `/usr/bin:/bin:/usr/sbin:/sbin`, with no Homebrew in it — so yt-dlp
is invisible and every download fails while the identical command works fine in a
terminal. This is the classic way a working script dies as an app.

## The Mac app

`YouTubeDownload.applescript` compiles to an app you can launch from Applications or
Spotlight. Dialogs rather than a Terminal window, because each dialog is readable by
VoiceOver and a scrolling terminal is the thing this project exists to avoid.

It prefills the URL from the clipboard, asks for a format, validates the link
**before** starting anything, then launches the download detached and returns
immediately — a blocking app with no progress readout would be the worst of both
worlds.

## Optional: Pushover

`--notify` sends a [Pushover](https://pushover.net) notification on completion, and on
failure at priority 1 so it beats quiet hours. It shells out to a `pushover` script on
your `PATH` and **silently does nothing if you don't have one**, so this costs you
nothing if you don't use it.

If you do, note that Pushover rejects the *entire* notification for an unknown sound
name — so `notify()` retries without `--sound` rather than losing the message. Upload
custom sounds named `ytdl-done` and `ytdl-fail`, or edit those constants.

## License

MIT — see [LICENSE](LICENSE).
