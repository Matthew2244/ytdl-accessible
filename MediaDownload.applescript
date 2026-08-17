-- Media Download — a launcher for ~/bin/ytdl.
--
-- Not YouTube-only: yt-dlp handles about 1,750 sites.
--
-- ACCESSIBILITY NOTE, and the reason this file reads the way it does:
--
-- AppleScript's `display dialog` has no per-button help tag. VoiceOver is given
-- exactly two things — the button's label and the dialog's body text — and
-- nothing else. So every button here is explained in one of those two places:
-- either the label says what it does on its own, or the body has a line naming
-- each button. There is no third option, and leaving a bare "More" or "OK"
-- unexplained means a control that announces itself as a word with no meaning.
--
-- Three rules followed throughout:
--
-- 1. Every button is accounted for in the dialog text, or is self-explaining.
-- 2. Every setting shows its current value in its own label, so nothing has to
--    be selected to find out what it was.
-- 3. The personality lives in wording that was going to be said anyway. No
--    dialog exists purely to be funny — a gag you have to dismiss stops being
--    one the second time, and someone listening rather than looking pays for
--    every word.
--
-- KEYBOARD: Command-Q and Command-W do nothing in an osacompile applet,
-- because the bundle has no menu bar for them to be bound to — and even with
-- one, `display dialog` runs a modal session that blocks the menus while it is
-- up, which here is always. What does work is Escape (and Command-period), but
-- only on a dialog that declares a `cancel button`. So every dialog below
-- declares one, and every dialog names it in its text.
--
-- Escape never closes the app. It means "back" or "dismiss" everywhere, and on
-- the main link box it deliberately does nothing at all, because there is
-- nothing behind it to go back to — and the only way to make Escape inert on a
-- dialog is to give it no cancel button. Quit is a button press only. Escape
-- is easy to hit by accident, and losing the screen you were on is a poor
-- reward for it.
--
-- A GUI-launched app gets a minimal PATH (/usr/bin:/bin:/usr/sbin:/sbin), so
-- Homebrew is invisible to it and yt-dlp would not be found. Hence the
-- explicit PATH on every shell call — this is the classic way a script that
-- works in the terminal fails silently as an app.

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
			-- Escape anywhere that was not caught closer in. It must never
			-- close the app, so this loops back to the link box.
		end try
	end repeat
end run

on greetOnce()
	try
		do shell script "test -f " & welcomeFlag
		return
	end try
	try
		display dialog "Hello. I fetch things off the internet so you can keep them." & return & return & ¬
		"Copy a link — YouTube, Bandcamp, SoundCloud, the BBC, about 1,750 sites — then launch me and press Return twice. That is the whole job." & return & return & ¬
		"You can paste several links at once, separated by spaces, and I will work through them one at a time." & return & return & ¬
		"I never open what I download and I never play anything at you. I put the file where you asked and get out of the way." & return & return & ¬
		"Everything else lives under the More button, including a Help entry that explains every screen. You will only see this message once." & return & return & ¬
		"One button: Let's go, which closes this and starts. Escape does the same." ¬
			with title "Hello from " & appTitle buttons {"Let's go"} ¬
			default button "Let's go" cancel button "Let's go"
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

-- A link is only offered if yt-dlp actually recognises it. Asking yt-dlp's own
-- matchers beats guessing from the hostname, and it is offline, so it costs
-- about a third of a second and never a network round trip. Without this, any
-- old article or search-results page on the clipboard got offered as a
-- download.
on clipboardLink()
	try
		set clipText to (the clipboard as text)
		set trimmed to do shell script "printf %s " & quoted form of clipText & ¬
			" | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'"
		if trimmed does not start with "http" then return {"", ""}
		try
			set siteName to my ytdl("--check-url " & quoted form of trimmed)
			return {trimmed, siteName}
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
		if (count of shown) > 70 then set shown to (text 1 thru 70 of shown) & "..."
		try
			set ans to button returned of (display dialog ¬
				"There is a " & siteName & " link on your clipboard:" & return & return & shown & ¬
			return & return & ¬
			"Yes, fetch it — download this one." & return & ¬
			"No, something else — go to the link box, empty. Escape does the same." & return & ¬
			"Quit — close the app." ¬
			with title appTitle ¬
			buttons {"Quit", "No, something else", "Yes, fetch it"} ¬
				default button "Yes, fetch it" cancel button "No, something else")
		on error number -128
			set ans to "No, something else"
		end try
		if ans is "Quit" then return false
		if ans is "No, something else" then set startURL to ""
	end if

	set opener to my pick({"What are we grabbing?", "Point me at something.", ¬
		"Give me a link and I will go and get it.", "What have you got?"})
	if startURL is not "" then set opener to "Ready when you are."

	try
		set reply to display dialog opener & return & return & ¬
			"Type or paste a link. Several at once? Separate them with spaces." & return & return & ¬
			"Fetch it — choose a format, then download." & return & ¬
			"More — settings, progress, supported sites, and help." & return & ¬
			"Quit — close the app. Escape does nothing here, on purpose." ¬
			default answer startURL with title appTitle ¬
			buttons {"Quit", "More", "Fetch it"} default button "Fetch it"
	on error number -128
		-- Unreachable while this dialog has no cancel button, but if one is
		-- ever added back, a cancel here must return to the link box rather
		-- than close the app.
		return true
	end try

	set pressed to button returned of reply
	if pressed is "Quit" then return false
	if pressed is "More" then
		moreScreen()
		return true
	end if

	set theURL to text returned of reply
	if theURL is "" then
		try
			display dialog "That was nothing at all. I need a link." & return & return & ¬
				"Fair enough — back to the link box. Escape does the same." with title appTitle ¬
				buttons {"Fair enough"} default button "Fair enough" cancel button "Fair enough"
		on error number -128
		end try
		return true
	end if

	set defFmt to my settingValue("format")
	set formatNames to {"My usual (" & defFmt & ")", ¬
		"Best quality - never converts anything", ¬
		"M4A - plays anywhere, converts non-AAC", ¬
		"Opus - smallest for the quality", ¬
		"WAV - uncompressed, for a REAPER session", ¬
		"MP3 320 - most compatible, always converts", ¬
		"FLAC - lossless", "Video - MP4 with picture"}
	set chosen to choose from list formatNames with prompt ¬
		"How would you like it? Your usual is " & defFmt & ". Choose one and press Use this, or Back to return." ¬
		default items {item 1 of formatNames} ¬
		OK button name "Use this" cancel button name "Back"
	if chosen is false then return true
	set chosenName to item 1 of chosen

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
				"Heads up — that link has a whole playlist attached to it." & return & return & ¬
			"Just this one — only the single track or video." & return & ¬
			"All of it — every item, in its own numbered folder." & return & ¬
			"Never mind — back to the link box. Escape does the same." with title appTitle ¬
			buttons {"Never mind", "Just this one", "All of it"} ¬
				default button "Just this one" cancel button "Never mind")
		on error number -128
			return true
		end try
		if plAnswer is "Never mind" then return true
		if plAnswer is "All of it" then set theFlag to theFlag & " --playlist"
	end if

	if howMany is 1 then
		try
			set infoText to my ytdl(quoted_urls & theFlag & " --info")
		on error errText
			try
				display dialog "Hit a wall:" & return & return & errText & return & return & ¬
					"OK — back to the link box. Nothing was downloaded. Escape does the same." ¬
					with title appTitle buttons {"OK"} default button "OK" ¬
					cancel button "OK" with icon stop
			on error number -128
			end try
			return true
		end try
		set summary to paragraph 1 of infoText
		try
			set summary to summary & return & paragraph 2 of infoText
		end try
	else
		set summary to (howMany as text) & " links queued up, one after another."
	end if

	-- Detached on purpose: the app must never sit blocking on a long download
	-- with no way to report progress. The ytdl-done and ytdl-fail Pushover
	-- tones are the completion signal, which is why --notify is not optional.
	do shell script shellPrefix & "nohup " & ytdlPath & quoted_urls & theFlag & ¬
		" --notify > $HOME/.ytdl-app.log 2>&1 &"

	set sendoff to my pick({"Off I go.", "On it.", "Consider it done.", ¬
		"Right, fetching.", "Say no more."})
	try
		set answer2 to button returned of (display dialog sendoff & return & return & summary & ¬
		return & return & "You will hear the finished tone when it lands." & return & return & ¬
		"Grab another — back to the link box." & return & ¬
		"How is it going? — check on the download." & return & ¬
		"Grab another — Escape does the same." & return & ¬
		"Done — close the app. The download keeps going." ¬
		with title appTitle buttons {"Done", "How is it going?", "Grab another"} ¬
			default button "Grab another" cancel button "Grab another")
	on error number -128
		set answer2 to "Grab another"
	end try
	if answer2 is "Done" then return false
	if answer2 is "How is it going?" then progressScreen()
	return true
end mainScreen

-- Re-checking is a button, never a timer: a dialog that refreshed itself would
-- talk over VoiceOver mid-sentence.
on progressScreen()
	repeat
		set report to my ytdl("--jobs")
		try
			set ans to button returned of (display dialog report & return & return & ¬
			"Check again — re-read the current state." & return & ¬
			"Back — return to what you were doing. Escape does the same." ¬
			with title appTitle buttons {"Back", "Check again"} ¬
				default button "Back" cancel button "Back")
		on error number -128
			return
		end try
		if ans is "Back" then return
	end repeat
end progressScreen

on moreScreen()
	repeat
		-- Every label carries its current value, so the state arrives with the
		-- name rather than needing a separate trip to find out.
		set sTo to my settingValue("to")
		set AppleScript's text item delimiters to "/"
		set shortTo to last text item of sTo
		set AppleScript's text item delimiters to ""
		set opts to {"How is it going? - anything downloading now", ¬
			"Where downloads go (now: " & shortTo & ")", ¬
			"Default format (now: " & my settingValue("format") & ")", ¬
			"Ping my phone when finished (now: " & my settingValue("notify") & ")", ¬
			"Say progress while downloading (now: " & my settingValue("progress") & ")", ¬
			"Keep yt-dlp updated (now: " & my settingValue("auto_update") & ")", ¬
			"Show all my settings - the full list", ¬
			"Is a site supported? - check any site", ¬
			"Update yt-dlp now - fetch the newest version", ¬
			"Help - what every screen and button does", ¬
			"Back to the link box"}
		set choice to choose from list opts with prompt ¬
			"Settings and tools. Each line shows what it is set to now. Choose one and press Open, or Back to return." ¬
			default items {item 1 of opts} ¬
			OK button name "Open" cancel button name "Back"
		if choice is false then return
		set what to item 1 of choice
		if what starts with "Back" then return

		try
		if what starts with "How is it going" then
			progressScreen()

		else if what starts with "Help" then
			helpScreen()

		else if what starts with "Show all" then
			display dialog my ytdl("--settings") & return & return & ¬
				"OK — back to the settings list. Escape does the same." with title appTitle ¬
				buttons {"OK"} default button "OK" cancel button "OK"

		else if what starts with "Where downloads go" then
			try
				set theFolder to choose folder with prompt ¬
					"Where should downloads land? Currently " & shortTo & ". Choose a folder and press Choose, or Cancel to leave it as it is."
				my ytdl("--set to=" & quoted form of (POSIX path of theFolder))
				display dialog "Right, they go there now." & return & return & ¬
					"Good — back to the settings list. Escape does the same." with title appTitle ¬
					buttons {"Good"} default button "Good" cancel button "Good"
			on error number -128
			end try

		else if what starts with "Default format" then
			set nowFmt to my settingValue("format")
			set fmts to {"best - never converts anything", "m4a - plays anywhere", ¬
				"opus - smallest for the quality", "mp3 - always converts", ¬
				"wav - uncompressed", "flac - lossless", "video - MP4"}
			set f to choose from list fmts with prompt ¬
				"Default format. Currently " & nowFmt & ". Choose one and press Use this, or Back to leave it." ¬
				default items {item 1 of fmts} ¬
				OK button name "Use this" cancel button name "Back"
			if f is not false then
				set AppleScript's text item delimiters to " "
				set justFmt to first text item of (item 1 of f)
				set AppleScript's text item delimiters to ""
				my ytdl("--set format=" & justFmt)
				display dialog "Default is now " & justFmt & "." & return & return & ¬
					"Good — back to the settings list. Escape does the same." with title appTitle ¬
					buttons {"Good"} default button "Good" cancel button "Good"
			end if

		else if what starts with "Ping my phone" then
			my toggle("notify", "Send a Pushover notification when a download finishes?")

		else if what starts with "Say progress" then
			my toggle("progress", "Announce a percentage every ten seconds during a download?")

		else if what starts with "Keep yt-dlp updated" then
			my toggle("auto_update", "Let yt-dlp update itself when a download fails and a newer version exists?")

		else if what starts with "Is a site supported" then
			try
				set q to text returned of (display dialog ¬
					"Which site? Type part of its name, like bandcamp or bbc." & return & return & ¬
					"Check — search the list of about 1,750 sites." & return & ¬
					"Cancel — back to the settings list. Escape does the same." ¬
					default answer "bandcamp" with title appTitle ¬
					buttons {"Cancel", "Check"} default button "Check" cancel button "Cancel")
				display dialog my ytdl("--sites " & quoted form of q) & return & return & ¬
					"OK — back to the settings list. Escape does the same." with title appTitle ¬
					buttons {"OK"} default button "OK" cancel button "OK"
			on error number -128
			end try

		else if what starts with "Update yt-dlp" then
			display dialog my ytdl("--update") & return & return & ¬
				"OK — back to the settings list. Escape does the same." with title appTitle ¬
				buttons {"OK"} default button "OK" cancel button "OK"
		end if
		on error number -128
		end try
	end repeat
end moreScreen

on helpScreen()
	try
		display dialog "What everything does." & return & return & ¬
		"THE LINK BOX. Type or paste a link and press Fetch it. Several links at once work — separate them with spaces. More opens settings and tools. Quit closes the app." & return & return & ¬
		"CLIPBOARD. If you copied a link before launching, I offer it. I only offer links yt-dlp actually recognises, so an article or a search page will not be suggested. Say No to get an empty box instead." & return & return & ¬
		"FORMATS. My usual is whatever you set as your default. Best quality never converts anything, so nothing loses quality. Naming a format guarantees the file type but converts when the source is not already that codec." & return & return & ¬
		"AFTER YOU PRESS FETCH. The download runs in the background, so you can close the app and it carries on. You get a tone when it finishes, and a different one if it fails." & return & return & ¬
		"More help — the second page: progress, playlists and settings. Escape leaves help." ¬
			with title appTitle buttons {"More help"} default button "More help" ¬
			cancel button "More help"

		display dialog "The rest of it." & return & return & ¬
		"HOW IS IT GOING. Shows what is downloading now and what finished recently. Check again re-reads it. It never refreshes on its own, because that would interrupt VoiceOver mid-sentence." & return & return & ¬
		"PLAYLISTS. If a link has a playlist attached, I ask first. All of it puts every track in its own numbered folder and remembers what it already got, so running it again resumes." & return & return & ¬
		"SETTINGS. Every line in the More list shows its current value in brackets, so you never have to open one to find out what it was." & return & return & ¬
		"NOTHING IS EVER OPENED. I write the file and leave it alone. No app is launched and nothing plays." & return & return & ¬
		"Back — return to the settings list. Escape does the same." ¬
			with title appTitle buttons {"Back"} default button "Back" cancel button "Back"
	on error number -128
	end try
end helpScreen

-- A yes/no setting, always stating what it is now before asking.
on toggle(theKey, question)
	set nowVal to my settingValue(theKey)
	try
		set a to button returned of (display dialog question & return & return & ¬
		"It is currently " & nowVal & "." & return & return & ¬
		"Yes — turn it on.  No — turn it off.  Cancel — leave it as it is, and Escape does the same." ¬
		with title appTitle ¬
			buttons {"Cancel", "No", "Yes"} default button "Cancel" cancel button "Cancel")
	on error number -128
		return
	end try
	if a is "Cancel" then return
	my ytdl("--set " & theKey & "=" & a)
	try
		display dialog "Set to " & a & "." & return & return & ¬
			"Good — back to the settings list. Escape does the same." with title appTitle ¬
			buttons {"Good"} default button "Good" cancel button "Good"
	on error number -128
	end try
end toggle
