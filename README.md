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
ytdl <url>                 your default format, into your default folder
ytdl <url> --info          what you would get, downloads nothing
```

**Choosing a format**

```
  --format KIND            best, m4a, opus, mp3, wav, flac or video
  --video --mp3 --wav      shorthand for the same
  --pick                   list the real formats and choose by number
  --list-formats           list them and stop
  --max-height 720         cap video height
  --format-id 251          an exact yt-dlp format id
  --set-default wav        remember a format, so you stop typing the flag
  --settings               show what you have saved
```

**Part of a video**

```
  --from 1:30              start there (also accepts 90 or 1:02:03)
  --to-time 3:45           stop there
  --chapters               also split into one file per chapter
  --subtitles              also fetch English subtitles as .srt
```

**Playlists**

```
  --playlist               the whole list, into its own numbered folder
  --items 1-10             or 3,5,7 — just those
  --no-resume              re-fetch items already downloaded
```

**Everything else**

```
  --to PATH                a different folder, just this once
  --name "..."             filename, without extension
  --progress               a percentage line every 10 seconds, no faster
  --cookies [BROWSER]      sign-in cookies, for "confirm you're not a bot"
  --notify                 Pushover ping on finish and on failure
  --quiet                  print the final path and nothing else
  --update                 upgrade yt-dlp now, and say what actually changed
  --no-auto-update         never upgrade yt-dlp on its own
```

Downloads default to `~/Library/Mobile Documents/com~apple~CloudDocs/Youtube Downloads`
(iCloud Drive). `ytdl --set-default --to ~/Music` changes that for good; `--to` changes
it for one run.

**Nothing here ever opens a file.** Downloads are written and left alone, so whatever
app owns the format on your Mac is never launched. If double-clicking a download opens
something you don't want, that is macOS file association, not this tool — and
`--set-default` lets you pick a format whose association you're happy with.

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

**A playlist must be listed flat, not extracted.** With `--playlist`, the metadata
call uses `--flat-playlist`. Without it, `-J` extracts every entry in full — for a
channel's uploads that is hundreds of round trips, and it simply times out before
anything downloads. Flat returns the list and its titles in one request and leaves
per-video work to the download itself.

**Partial playlist success is reported as partial success.** `--ignore-errors` keeps
yt-dlp going past a bad item, and it still exits non-zero afterwards. Treating that as
total failure would throw away news of every file that *did* arrive, leaving re-running
as the only way to find out. Each item is announced as it starts, an archive file beside
the downloads records what completed, and re-running the same command resumes rather
than starting over.

**An exact format id is taken as it comes.** `--format-id 251` (Opus) once landed as a
fatter, lossier `.m4a`, because a *saved default* of m4a was still being applied on top
of the stream that had been explicitly named. A saved default must never silently
transcode a stream you went to the trouble of asking for; an explicit flag still wins.

**Auto-update is triggered by failure, not by a timer.** YouTube breaks yt-dlp
periodically, and the moment a newer version is worth having is the moment a download
fails. So that is the primary trigger: on a failure, if a newer release exists, `ytdl`
upgrades and retries once — turning "it failed, go update, try again" into one command
that just works.

Two guards make that safe to leave on. It only fires for failures an upgrade could
plausibly fix — a private, removed or members-only video will fail identically on
every version ever released, and spending a minute on `brew` to prove that is worse
than just saying so. And it only retries when the version genuinely moved, so a
Homebrew that has nothing newer costs you one no-op rather than a pointless second
attempt.

The secondary trigger is a once-a-day check **after a successful download**, so the
upgrade has usually already happened before a break can reach you. Neither check ever
runs *before* a download — nothing should stand between you and the file you asked
for. `--no-auto-update` turns both off.

**No age-based staleness check.** An early version warned when yt-dlp was more than
30 days old. But yt-dlp releases irregularly, so this called a perfectly current
install stale — the warning fired on every failure and pointed at `--update`, which
correctly replied "already up to date". Version comparison is against the GitHub
releases API, and **stays silent when it cannot reach it**: "could not check" and
"you are behind" must never look the same.

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
