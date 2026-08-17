-- Media Download — a launcher for ~/bin/ytdl.
--
-- Not YouTube-only: yt-dlp handles about 1,750 sites.
--
-- Dialogs rather than a Terminal window: every dialog here is readable by
-- VoiceOver, and a scrolling terminal is exactly what ytdl exists to avoid.
--
-- Three rules this file follows throughout:
--
-- 1. Every choice says what it does. A list item reading "Default format" is
--    useless on its own; it reads "Default format (now: best)" so the current
--    state arrives with the label rather than after a guess.
-- 2. Every toggle says whether it is on. Same reason.
-- 3. The personality lives in wording that was going to be said anyway. No
--    dialog exists purely to be funny — a gag you have to dismiss stops being
--    one the second time, and someone listening rather than looking pays for
--    every word.
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
		if not mainScreen() then exit repeat
	end repeat
end run

on greetOnce()
	try
		do shell script "test -f " & welcomeFlag
		return
	end try
	display dialog "Hello. I fetch things off the internet so you can keep them." & return & return & ¬
		"Copy a link — YouTube, Bandcamp, SoundCloud, the BBC, about 1,750 sites — then launch me and press Return twice. That is the whole job." & return & return & ¬
		"You can paste several links at once, separated by spaces, and I will work through them one at a time." & return & return & ¬
		"I never open what I download and I never play anything at you. I put the file where you asked and get out of the way." & return & return & ¬
		"Everything is under the More button: where files go, what format, and how things are going. You will only see this message once." ¬
		with title "Hello from " & appTitle buttons {"Let's go"} default button "Let's go"
	do shell script "mkdir -p $HOME/.config/ytdl && touch " & welcomeFlag
end greetOnce

on pick(theList)
	return item (random number from 1 to (count of theList)) of theList
end pick

on ytdl(argsText)
	return do shell script shellPrefix & ytdlPath & " " & argsText
end ytdl

-- One saved setting, as text. Used to label every control with its state.
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

	-- Its own question with a real No, so declining the clipboard leaves you
	-- at an empty field instead of making you clear it by hand.
	if startURL is not "" then
		set shown to startURL
		if (count of shown) > 70 then set shown to (text 1 thru 70 of shown) & "..."
		set ans to button returned of (display dialog ¬
			"There is a " & siteName & " link on your clipboard:" & return & return & shown & ¬
			return & return & "Fetch this one, or start with an empty box?" ¬
			with title appTitle ¬
			buttons {"Quit", "No, something else", "Yes, fetch it"} ¬
			default button "Yes, fetch it")
		if ans is "Quit" then return false
		if ans is "No, something else" then set startURL to ""
	end if

	set opener to my pick({"What are we grabbing?", "Point me at something.", ¬
		"Give me a link and I will go and get it.", "What have you got?"})
	if startURL is not "" then set opener to "Ready when you are."

	try
		set reply to display dialog opener & return & ¬
			"Paste a link. Several at once? Separate them with spaces." & return & ¬
			"More: settings, progress, and what sites work." ¬
			default answer startURL with title appTitle ¬
			buttons {"Quit", "More", "Fetch it"} default button "Fetch it"
	on error number -128
		return false
	end try

	set pressed to button returned of reply
	if pressed is "Quit" then return false
	if pressed is "More" then
		moreScreen()
		return true
	end if

	set theURL to text returned of reply
	if theURL is "" then
		display dialog "That was nothing at all. I need a link." with title appTitle ¬
			buttons {"Fair enough"} default button "Fair enough"
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
		"How would you like it? Your usual is " & defFmt & "." ¬
		default items {item 1 of formatNames}
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
		set plAnswer to button returned of (display dialog ¬
			"Heads up — that link has a whole playlist attached to it." & return & return & ¬
			"All of it puts every track in its own numbered folder." with title appTitle ¬
			buttons {"Never mind", "Just this one", "All of it"} default button "Just this one")
		if plAnswer is "Never mind" then return true
		if plAnswer is "All of it" then set theFlag to theFlag & " --playlist"
	end if

	if howMany is 1 then
		try
			set infoText to my ytdl(quoted_urls & theFlag & " --info")
		on error errText
			display dialog "Hit a wall:" & return & return & errText with title appTitle ¬
				buttons {"OK"} default button "OK" with icon stop
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
	set answer2 to button returned of (display dialog sendoff & return & return & summary & ¬
		return & return & "You will hear the finished tone when it lands." ¬
		with title appTitle buttons {"Done", "How is it going?", "Grab another"} ¬
		default button "Grab another")
	if answer2 is "Done" then return false
	if answer2 is "How is it going?" then progressScreen()
	return true
end mainScreen

-- Re-checking is a button, never a timer: a dialog that refreshed itself would
-- talk over VoiceOver mid-sentence.
on progressScreen()
	repeat
		set report to my ytdl("--jobs")
		set ans to button returned of (display dialog report with title appTitle ¬
			buttons {"Back", "Check again"} default button "Back")
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
			"Update yt-dlp now", "Back to the link box"}
		set choice to choose from list opts with prompt ¬
			"Settings and tools. Each one shows what it is set to now." ¬
			default items {item 1 of opts}
		if choice is false then return
		set what to item 1 of choice
		if what starts with "Back" then return

		if what starts with "How is it going" then
			progressScreen()

		else if what starts with "Show all" then
			display dialog my ytdl("--settings") with title appTitle ¬
				buttons {"OK"} default button "OK"

		else if what starts with "Where downloads go" then
			try
				set theFolder to choose folder with prompt ¬
					"Where should downloads land? Currently " & shortTo & "."
				my ytdl("--set to=" & quoted form of (POSIX path of theFolder))
				display dialog "Right, they go there now." with title appTitle ¬
					buttons {"Good"} default button "Good"
			on error number -128
			end try

		else if what starts with "Default format" then
			set nowFmt to my settingValue("format")
			set fmts to {"best - never converts anything", "m4a - plays anywhere", ¬
				"opus - smallest for the quality", "mp3 - always converts", ¬
				"wav - uncompressed", "flac - lossless", "video - MP4"}
			set f to choose from list fmts with prompt ¬
				"Default format. Currently " & nowFmt & "." default items {item 1 of fmts}
			if f is not false then
				set AppleScript's text item delimiters to " "
				set justFmt to first text item of (item 1 of f)
				set AppleScript's text item delimiters to ""
				my ytdl("--set format=" & justFmt)
				display dialog "Default is now " & justFmt & "." with title appTitle ¬
					buttons {"Good"} default button "Good"
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
					"Which site? Type part of its name, like bandcamp or bbc." ¬
					default answer "bandcamp" with title appTitle ¬
					buttons {"Cancel", "Check"} default button "Check")
				display dialog my ytdl("--sites " & quoted form of q) with title appTitle ¬
					buttons {"OK"} default button "OK"
			on error number -128
			end try

		else if what starts with "Update yt-dlp" then
			display dialog my ytdl("--update") with title appTitle ¬
				buttons {"OK"} default button "OK"
		end if
	end repeat
end moreScreen

-- A yes/no setting, always stating what it is now before asking.
on toggle(theKey, question)
	set nowVal to my settingValue(theKey)
	set a to button returned of (display dialog question & return & return & ¬
		"It is currently " & nowVal & "." with title appTitle ¬
		buttons {"Cancel", "No", "Yes"} default button "Cancel")
	if a is "Cancel" then return
	my ytdl("--set " & theKey & "=" & a)
	display dialog "Set to " & a & "." with title appTitle buttons {"Good"} default button "Good"
end toggle
