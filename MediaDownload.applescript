-- Media Download — a launcher for ~/bin/ytdl.
-- Not YouTube-only: yt-dlp handles about 1,750 sites.
--
-- Dialogs rather than a Terminal window: every dialog here is readable by
-- VoiceOver, and a scrolling terminal is exactly what ytdl exists to avoid.
--
-- A GUI-launched app gets a minimal PATH (/usr/bin:/bin:/usr/sbin:/sbin), so
-- Homebrew is invisible to it and yt-dlp would not be found. Hence the
-- explicit PATH on every shell call — this is the classic way a script that
-- works in the terminal fails silently as an app.

property shellPrefix : "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH; "
property ytdlPath : "$HOME/bin/ytdl"
property appTitle : "Media Download"

on run
	-- Prefill from the clipboard. Copying a link and then launching this is
	-- the common case, so it should usually be Return, Return and done.
	set startURL to ""
	try
		set clipText to (the clipboard as text)
		set trimmed to do shell script "printf %s " & quoted form of clipText & " | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'"
		if trimmed starts with "http" then set startURL to trimmed
	end try

	try
		set urlReply to display dialog "Paste or edit the link (any site, not just YouTube):" default answer startURL with title appTitle buttons {"Cancel", "Continue"} default button "Continue"
	on error number -128
		return
	end try
	set theURL to text returned of urlReply
	if theURL is "" then return

	set formatNames to {"My default", "Audio - best quality, no conversion", ¬
		"M4A - plays anywhere", "Opus - best per kilobyte", ¬
		"WAV - for a REAPER session", "MP3 320", "FLAC", "Video - MP4"}
	set chosen to choose from list formatNames with prompt "What do you want?" default items {item 1 of formatNames}
	if chosen is false then return
	set chosenName to item 1 of chosen

	set theFlag to ""
	if chosenName starts with "Audio" then set theFlag to " --format best"
	if chosenName starts with "M4A" then set theFlag to " --format m4a"
	if chosenName starts with "Opus" then set theFlag to " --format opus"
	if chosenName starts with "WAV" then set theFlag to " --format wav"
	if chosenName starts with "MP3" then set theFlag to " --format mp3"
	if chosenName starts with "FLAC" then set theFlag to " --format flac"
	if chosenName starts with "Video" then set theFlag to " --format video"

	-- A link copied from a queue carries the whole playlist with it. Ask
	-- rather than guess: silently taking two hundred videos would be far
	-- worse than silently taking one.
	if theURL contains "list=" then
		set plAnswer to button returned of (display dialog ¬
			"That link is part of a set." with title appTitle ¬
			buttons {"Cancel", "Just this one", "The whole set"} ¬
			default button "Just this one")
		if plAnswer is "Cancel" then return
		if plAnswer is "The whole set" then set theFlag to theFlag & " --playlist"
	end if

	-- Check the link before starting anything, so a bad paste or an
	-- unavailable video fails as a sentence in a dialog rather than as a
	-- background job that quietly does nothing.
	try
		set infoText to do shell script shellPrefix & ytdlPath & " " & quoted form of theURL & theFlag & " --info"
	on error errText
		display dialog errText with title appTitle buttons {"OK"} default button "OK" with icon stop
		return
	end try

	set summary to paragraph 1 of infoText
	try
		set summary to summary & return & paragraph 2 of infoText
	end try

	-- Detached on purpose: the app must never sit blocking on a long download
	-- with no way to report progress. The ytdl-done and ytdl-fail Pushover
	-- tones are the completion signal, which is why --notify is not optional
	-- here even though it is on the command line.
	do shell script shellPrefix & "nohup " & ytdlPath & " " & quoted form of theURL & theFlag & " --notify > $HOME/.ytdl-app.log 2>&1 &"

	display dialog "Downloading:" & return & return & summary & return & return & "It will ping you when it is done." with title appTitle buttons {"OK"} default button "OK"
end run
