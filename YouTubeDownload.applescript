-- YouTube Download — a launcher for ~/bin/ytdl.
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
property appTitle : "YouTube Download"

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
		set urlReply to display dialog "Paste or edit the link:" default answer startURL with title appTitle buttons {"Cancel", "Continue"} default button "Continue"
	on error number -128
		return
	end try
	set theURL to text returned of urlReply
	if theURL is "" then return

	set formatNames to {"Audio - best quality, no conversion", "WAV - for a REAPER session", "Video - MP4", "MP3 320"}
	set chosen to choose from list formatNames with prompt "What do you want?" default items {item 1 of formatNames}
	if chosen is false then return
	set chosenName to item 1 of chosen

	set theFlag to ""
	if chosenName starts with "WAV" then set theFlag to " --wav"
	if chosenName starts with "Video" then set theFlag to " --video"
	if chosenName starts with "MP3" then set theFlag to " --mp3"

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
