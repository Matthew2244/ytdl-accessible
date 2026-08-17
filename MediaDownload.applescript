-- Media Download — a launcher for ~/bin/ytdl.
--
-- Not YouTube-only: yt-dlp handles about 1,750 sites.
--
-- KEYBOARD. Command-Q and Command-W do nothing in an osacompile applet: the
-- bundle has no menu bar for them to bind to, and `display dialog` runs a modal
-- session that blocks menus anyway. Escape is the way out, and it behaves as
-- follows — measured, not assumed:
--
--   one button, set as BOTH default and cancel  ->  Escape does NOTHING
--   one button, set as cancel only              ->  Escape and Space work
--   two buttons, default and cancel different   ->  Escape and Return work
--
-- And separately, measured the same way: `choose from list` ignores Escape and
-- Command-period completely, even when the app is frontmost. Its Cancel button
-- is clickable but no key reaches it. So every list here also carries a plain
-- "Back" item, because a menu you can enter and not leave by keyboard is a
-- trap.
--
-- The first shape is the trap, and it is the obvious thing to write. Every
-- one-button dialog here therefore sets `cancel button` and no default.
--
-- Escape never closes the app. It means back or dismiss everywhere; on the
-- link box it does nothing, because there is nothing behind it. Quit is a
-- button press only, since Escape is easy to hit by accident.
--
-- WORDING. Buttons say what they do, so the body does not have to explain
-- them. Earlier versions listed every button with a description and became a
-- wall of text — costly when you are listening rather than looking. The long
-- explanations live in Help, once, where they can be read on purpose.
--
-- A GUI-launched app gets a minimal PATH (/usr/bin:/bin:/usr/sbin:/sbin), so
-- Homebrew is invisible to it and yt-dlp would not be found. Hence the
-- explicit PATH on every shell call.

property shellPrefix : "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH; "
property ytdlPath : "$HOME/bin/ytdl"
property appTitle : "Media Download"
property welcomeFlag : "$HOME/.config/ytdl/.welcomed"

on run
	greetOnce()
	repeat
		try
			if not mainScreen() then exit repeat
		on error number -128
			-- Escape that got past a closer handler. Never closes the app.
		end try
	end repeat
end run

-- An information dialog: one button, cancel-only so Escape and Space both work.
on tell_(theText)
	try
		display dialog theText with title appTitle buttons {"OK"} cancel button "OK"
	on error number -128
	end try
end tell_

on greetOnce()
	try
		do shell script "test -f " & welcomeFlag
		return
	end try
	try
		display dialog "I download things from the web so you can keep them." & return & return & ¬
			"Copy a link, open me, press Return twice. That's it." & return & return & ¬
			"About 1,750 sites work, not just YouTube. Several links at once are fine — put spaces between them." & return & return & ¬
			"I never open or play what I download." & return & return & ¬
			"Settings and Help are behind the Settings button. You'll only see this once." ¬
			with title "Hello from " & appTitle buttons {"Start"} cancel button "Start"
	on error number -128
	end try
	do shell script "mkdir -p $HOME/.config/ytdl && touch " & welcomeFlag
end greetOnce

on pick(theList)
	return item (random number from 1 to (count of theList)) of theList
end pick

on ytdl(argsText)
	return do shell script shellPrefix & ytdlPath & " " & argsText
end ytdl

on settingValue(theKey)
	try
		return my ytdl("--get " & theKey)
	on error
		return "?"
	end try
end settingValue

-- Only offer a link yt-dlp actually recognises. Asking yt-dlp's own matchers
-- beats guessing from the hostname, and it runs offline, so it costs about a
-- third of a second. Without it, any article or search page got offered.
on clipboardLink()
	try
		set clipText to (the clipboard as text)
		set trimmed to do shell script "printf %s " & quoted form of clipText & ¬
			" | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'"
		if trimmed does not start with "http" then return {"", ""}
		try
			return {trimmed, my ytdl("--check-url " & quoted form of trimmed)}
		on error
			return {"", ""}
		end try
	end try
	return {"", ""}
end clipboardLink

on mainScreen()
	set found to my clipboardLink()
	set startURL to item 1 of found
	set siteName to item 2 of found

	if startURL is not "" then
		set shown to startURL
		if (count of shown) > 60 then set shown to (text 1 thru 60 of shown) & "..."
		try
			set ans to button returned of (display dialog ¬
				"You copied a " & siteName & " link:" & return & return & shown & ¬
				return & return & "Download this one?" ¬
				with title appTitle ¬
				buttons {"Quit", "Type a different link", "Download this"} ¬
				default button "Download this" cancel button "Type a different link")
		on error number -128
			set ans to "Type a different link"
		end try
		if ans is "Quit" then return false
		if ans is "Type a different link" then set startURL to ""
	end if

	set opener to my pick({"What would you like?", "Give me a link.", ¬
		"What are we downloading?", "Paste a link and I'll fetch it."})

	try
		set reply to display dialog opener & return & ¬
			"Several at once? Put spaces between them." ¬
			default answer startURL with title appTitle ¬
			buttons {"Quit", "Settings", "Download"} default button "Download"
	on error number -128
		return true
	end try

	set pressed to button returned of reply
	if pressed is "Quit" then return false
	if pressed is "Settings" then
		settingsScreen()
		return true
	end if

	set theURL to text returned of reply
	if theURL is "" then
		my tell_("I need a link first.")
		return true
	end if

	set defFmt to my settingValue("format")
	set formatNames to {"My usual, which is " & defFmt, ¬
		"Best quality — never converts, no quality lost", ¬
		"M4A — plays in anything", ¬
		"Opus — smallest file for the quality", ¬
		"WAV — uncompressed, for REAPER", ¬
		"MP3 — plays in anything, older format", ¬
		"FLAC — lossless", "Video — MP4 with picture", "Back"}
	set chosen to choose from list formatNames with prompt ¬
		"Which format?" default items {item 1 of formatNames} ¬
		OK button name "Use this" cancel button name "Back"
	if chosen is false then return true
	set chosenName to item 1 of chosen
	if chosenName is "Back" then return true

	set theFlag to ""
	if chosenName starts with "Best" then set theFlag to " --format best"
	if chosenName starts with "M4A" then set theFlag to " --format m4a"
	if chosenName starts with "Opus" then set theFlag to " --format opus"
	if chosenName starts with "WAV" then set theFlag to " --format wav"
	if chosenName starts with "MP3" then set theFlag to " --format mp3"
	if chosenName starts with "FLAC" then set theFlag to " --format flac"
	if chosenName starts with "Video" then set theFlag to " --format video"

	set quoted_urls to ""
	set AppleScript's text item delimiters to " "
	set parts to text items of theURL
	set AppleScript's text item delimiters to ""
	set howMany to 0
	repeat with aPart in parts
		if (aPart as text) is not "" then
			set quoted_urls to quoted_urls & " " & quoted form of (aPart as text)
			set howMany to howMany + 1
		end if
	end repeat

	if theURL contains "list=" then
		try
			set plAnswer to button returned of (display dialog ¬
				"That link has a whole playlist attached." & return & return & ¬
				"The whole playlist goes into its own folder, numbered in order." ¬
				with title appTitle ¬
				buttons {"Cancel", "Whole playlist", "Just this one"} ¬
				default button "Just this one" cancel button "Cancel")
		on error number -128
			set plAnswer to "Cancel"
		end try
		if plAnswer is "Cancel" then return true
		if plAnswer is "Whole playlist" then set theFlag to theFlag & " --playlist"
	end if

	if howMany is 1 then
		try
			set infoText to my ytdl(quoted_urls & theFlag & " --info")
		on error errText
			my tell_("That didn't work." & return & return & errText & return & return & ¬
				"Nothing was downloaded.")
			return true
		end try
		set summary to paragraph 1 of infoText
		try
			set summary to summary & return & paragraph 2 of infoText
		end try
	else
		set summary to (howMany as text) & " links, one after another."
	end if

	-- Detached on purpose: the app must never sit blocking on a long download.
	-- The ytdl-done and ytdl-fail tones are the completion signal, which is why
	-- --notify is not optional here.
	do shell script shellPrefix & "nohup " & ytdlPath & quoted_urls & theFlag & ¬
		" --notify > $HOME/.ytdl-app.log 2>&1 &"

	set sendoff to my pick({"Off I go.", "On it.", "Right, downloading.", "Say no more."})
	try
		set answer2 to button returned of (display dialog sendoff & return & return & summary & ¬
			return & return & "You'll hear a tone when it's done." ¬
			with title appTitle ¬
			buttons {"Quit", "Check progress", "Another link"} ¬
			default button "Another link")
	on error number -128
		set answer2 to "Another link"
	end try
	if answer2 is "Quit" then return false
	if answer2 is "Check progress" then progressScreen()
	return true
end mainScreen

-- Re-checking is a button, never a timer: a dialog that refreshed itself would
-- talk over VoiceOver mid-sentence.
on progressScreen()
	repeat
		try
			set ans to button returned of (display dialog my ytdl("--jobs") ¬
				with title appTitle buttons {"Back", "Check again"} ¬
				default button "Check again" cancel button "Back")
		on error number -128
			return
		end try
		if ans is "Back" then return
	end repeat
end progressScreen

on settingsScreen()
	repeat
		set sTo to my settingValue("to")
		set AppleScript's text item delimiters to "/"
		set shortTo to last text item of sTo
		set AppleScript's text item delimiters to ""
		set opts to {"Check progress", ¬
			"Downloads folder: " & shortTo, ¬
			"Format: " & my settingValue("format"), ¬
			"Notify my phone: " & my settingValue("notify"), ¬
			"Speak progress: " & my settingValue("progress"), ¬
			"Auto-update: " & my settingValue("auto_update"), ¬
			"Show all settings", "Check if a site works", ¬
			"Update yt-dlp now", "Help", "Back"}
		set choice to choose from list opts with prompt ¬
			"Settings. Each line shows what it is set to." ¬
			default items {item 1 of opts} ¬
			OK button name "Open" cancel button name "Back"
		if choice is false then return
		set what to item 1 of choice
		if what is "Back" then return

		try
			if what is "Check progress" then
				progressScreen()

			else if what is "Help" then
				helpScreen()

			else if what is "Show all settings" then
				my tell_(my ytdl("--settings"))

			else if what starts with "Downloads folder" then
				set theFolder to choose folder with prompt "Where should downloads go?"
				my ytdl("--set to=" & quoted form of (POSIX path of theFolder))
				my tell_("Downloads now go to " & (POSIX path of theFolder) & ".")

			else if what starts with "Format" then
				set fmts to {"best — never converts anything", "m4a — plays in anything", ¬
					"opus — smallest for the quality", "mp3 — older, always converts", ¬
					"wav — uncompressed", "flac — lossless", "video — MP4", "Back"}
				set f to choose from list fmts with prompt ¬
					"Format, currently " & my settingValue("format") & "." ¬
					default items {item 1 of fmts} ¬
					OK button name "Use this" cancel button name "Back"
				if f is not false and (item 1 of f) is not "Back" then
					set AppleScript's text item delimiters to " "
					set justFmt to first text item of (item 1 of f)
					set AppleScript's text item delimiters to ""
					my ytdl("--set format=" & justFmt)
					my tell_("Format is now " & justFmt & ".")
				end if

			else if what starts with "Notify my phone" then
				my toggle("notify", "Send a notification to your phone when a download finishes?")

			else if what starts with "Speak progress" then
				my toggle("progress", "Say a percentage every ten seconds while downloading?")

			else if what starts with "Auto-update" then
				my toggle("auto_update", "Let yt-dlp update itself when a download fails?")

			else if what starts with "Check if a site" then
				set q to text returned of (display dialog "Which site?" ¬
					default answer "bandcamp" with title appTitle ¬
					buttons {"Cancel", "Check"} default button "Check" cancel button "Cancel")
				my tell_(my ytdl("--sites " & quoted form of q))

			else if what starts with "Update yt-dlp" then
				my tell_(my ytdl("--update"))
			end if
		on error number -128
			-- Escape inside any of the above just returns to this list.
		end try
	end repeat
end settingsScreen

on helpScreen()
	my tell_("How it works." & return & return & ¬
		"Paste a link and press Download. Several links at once work if you put spaces between them." & return & return & ¬
		"If you copied a link before opening me, I offer it — but only if it's a site that actually works, so an article or a search page won't be suggested." & return & return & ¬
		"Downloads run in the background. You can close me and they carry on. A tone plays when one finishes, and a different tone if one fails.")

	my tell_("Formats." & return & return & ¬
		"Best quality never converts anything, so nothing is lost." & return & return & ¬
		"Choosing a specific format guarantees the file type, but converts the file when it isn't already that format — which loses a little quality for MP3 and M4A." & return & return & ¬
		"WAV and FLAC lose nothing. WAV is the one for a REAPER session.")

	my tell_("The rest." & return & return & ¬
		"Check progress shows what's downloading and what just finished. It only updates when you ask, so it never talks over you." & return & return & ¬
		"Playlists: I always ask first, and the whole playlist goes into its own numbered folder. Running it again picks up where it left off." & return & return & ¬
		"Escape goes back, and never closes the app. Quit is a button." & return & return & ¬
		"I never open or play anything I download.")
end helpScreen

-- A yes/no setting, always saying what it is now before asking.
on toggle(theKey, question)
	try
		set a to button returned of (display dialog question & return & return & ¬
			"Currently " & my settingValue(theKey) & "." with title appTitle ¬
			buttons {"Cancel", "No", "Yes"} cancel button "Cancel")
	on error number -128
		return
	end try
	if a is "Cancel" then return
	my ytdl("--set " & theKey & "=" & a)
	my tell_("Set to " & a & ".")
end toggle
