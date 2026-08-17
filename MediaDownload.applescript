-- Media Download — a launcher for ~/bin/ytdl.
--
-- Not YouTube-only: yt-dlp handles about 1,750 sites.
--
-- Dialogs rather than a Terminal window: every dialog here is readable by
-- VoiceOver, and a scrolling terminal is exactly what ytdl exists to avoid.
--
-- On personality: the jokes live in the *wording*, never in extra steps. The
-- welcome appears once and never again, and no dialog exists purely to be
-- funny — a gag you have to dismiss stops being one the second time. Anyone
-- listening to this rather than looking at it pays for every word, so the
-- character rides along inside sentences that were going to be said anyway.
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

-- Once. Ever. Then it gets out of the way for good.
on greetOnce()
	try
		do shell script "test -f " & welcomeFlag
		return
	end try
	display dialog "Hello. I fetch things off the internet so you can keep them." & return & return & ¬
		"Copy a link — YouTube, Bandcamp, SoundCloud, the BBC, about 1,750 sites — then launch me and press Return twice. That is the whole job." & return & return & ¬
		"You can paste several links at once, separated by spaces, and I will work through them." & return & return & ¬
		"I never open what I download and I never play anything at you. I put the file where you asked and get out of the way." & return & return & ¬
		"You will only see this once." ¬
		with title "Hello from " & appTitle buttons {"Let's go"} default button "Let's go"
	do shell script "mkdir -p $HOME/.config/ytdl && touch " & welcomeFlag
end greetOnce

on pick(theList)
	return item (random number from 1 to (count of theList)) of theList
end pick

on clipboardLink()
	try
		set clipText to (the clipboard as text)
		set trimmed to do shell script "printf %s " & quoted form of clipText & ¬
			" | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'"
		if trimmed starts with "http" then return trimmed
	end try
	return ""
end clipboardLink

-- Returns false when the user is done with us.
on mainScreen()
	set startURL to my clipboardLink()

	-- Offered as its own question, with a real No, so declining the clipboard
	-- takes you to an empty field rather than making you clear it by hand.
	if startURL is not "" then
		set shown to startURL
		if (count of shown) > 70 then set shown to (text 1 thru 70 of shown) & "..."
		set ans to button returned of (display dialog ¬
			my pick({"There is a link on your clipboard:", "Found this on your clipboard:", ¬
				"Your clipboard is holding:"}) & return & return & shown ¬
			with title appTitle buttons {"Quit", "No, something else", "Yes, fetch it"} ¬
			default button "Yes, fetch it")
		if ans is "Quit" then return false
		if ans is "No, something else" then set startURL to ""
	end if

	set opener to my pick({"What are we grabbing?", "Point me at something.", ¬
		"Give me a link and I will go and get it.", "What have you got?"})
	if startURL is not "" then set opener to "Ready when you are."

	try
		set reply to display dialog opener & return & ¬
			"(Several links at once? Separate them with spaces.)" ¬
			default answer startURL with title appTitle ¬
			buttons {"Quit", "More…", "Fetch it"} default button "Fetch it"
	on error number -128
		return false
	end try

	set pressed to button returned of reply
	if pressed is "Quit" then return false
	if pressed is "More…" then
		moreScreen()
		return true
	end if

	set theURL to text returned of reply
	if theURL is "" then
		display dialog "That was nothing at all. I need a link." with title appTitle ¬
			buttons {"Fair enough"} default button "Fair enough"
		return true
	end if

	set formatNames to {"My usual", "Best quality, no converting", ¬
		"M4A - plays anywhere", "Opus - best per kilobyte", ¬
		"WAV - for a REAPER session", "MP3 320", "FLAC - lossless", "Video - MP4"}
	set chosen to choose from list formatNames with prompt "How would you like it?" ¬
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

	-- Quote each link separately so several can go in one run.
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

	-- A link copied from a queue carries the whole set with it. Ask rather
	-- than guess: silently taking two hundred tracks would be far worse than
	-- silently taking one.
	if theURL contains "list=" then
		set plAnswer to button returned of (display dialog ¬
			"Heads up — that link has a whole playlist attached to it." with title appTitle ¬
			buttons {"Never mind", "Just this one", "All of it"} default button "Just this one")
		if plAnswer is "Never mind" then return true
		if plAnswer is "All of it" then set theFlag to theFlag & " --playlist"
	end if

	-- Check the first link before starting anything, so a bad paste or an
	-- unavailable video fails as a sentence in a dialog rather than as a
	-- background job that quietly does nothing.
	if howMany is 1 then
		try
			set infoText to do shell script shellPrefix & ytdlPath & quoted_urls & ¬
				theFlag & " --info"
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
		set summary to (howMany as text) & " links queued up."
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

-- The app detaches its downloads, so this asks ytdl what is actually running
-- rather than guessing. Re-checking is a button, not a timer: a dialog that
-- refreshed itself would talk over VoiceOver mid-sentence.
on progressScreen()
	repeat
		set report to do shell script shellPrefix & ytdlPath & " --jobs"
		set ans to button returned of (display dialog report with title appTitle ¬
			buttons {"Back", "Check again"} default button "Back")
		if ans is "Back" then return
	end repeat
end progressScreen

on moreScreen()
	repeat
		set opts to {"How is it going?", "Where downloads go", "Default format", ¬
			"Ping my phone when finished", "Say progress while downloading", ¬
			"Show all my settings", "Is a site supported?", "Update yt-dlp", "Back"}
		set choice to choose from list opts with prompt "What would you like to do?" ¬
			default items {item 1 of opts}
		if choice is false then return
		set what to item 1 of choice
		if what is "Back" then return

		if what is "How is it going?" then
			progressScreen()

		else if what is "Show all my settings" then
			set current to do shell script shellPrefix & ytdlPath & " --settings"
			display dialog current with title appTitle buttons {"OK"} default button "OK"

		else if what is "Where downloads go" then
			try
				set theFolder to choose folder with prompt "Where should downloads land?"
				do shell script shellPrefix & ytdlPath & " --set to=" & ¬
					quoted form of (POSIX path of theFolder)
				display dialog "Right, they go there now." with title appTitle ¬
					buttons {"Good"} default button "Good"
			on error number -128
			end try

		else if what is "Default format" then
			set fmts to {"best", "m4a", "opus", "mp3", "wav", "flac", "video"}
			set f to choose from list fmts with prompt ¬
				"Default format. 'best' never converts anything." default items {"best"}
			if f is not false then
				do shell script shellPrefix & ytdlPath & " --set format=" & (item 1 of f)
				display dialog "Default is now " & (item 1 of f) & "." with title appTitle ¬
					buttons {"Good"} default button "Good"
			end if

		else if what is "Ping my phone when finished" then
			set a to button returned of (display dialog ¬
				"Send a Pushover notification when a download finishes?" with title appTitle ¬
				buttons {"Cancel", "No", "Yes"} default button "Yes")
			if a is not "Cancel" then
				do shell script shellPrefix & ytdlPath & " --set notify=" & a
			end if

		else if what is "Say progress while downloading" then
			set a to button returned of (display dialog ¬
				"Announce a percentage every ten seconds during a download?" with title appTitle ¬
				buttons {"Cancel", "No", "Yes"} default button "No")
			if a is not "Cancel" then
				do shell script shellPrefix & ytdlPath & " --set progress=" & a
			end if

		else if what is "Is a site supported?" then
			try
				set q to text returned of (display dialog "Which site?" default answer "bandcamp" ¬
					with title appTitle buttons {"Cancel", "Check"} default button "Check")
				set r to do shell script shellPrefix & ytdlPath & " --sites " & quoted form of q
				display dialog r with title appTitle buttons {"OK"} default button "OK"
			on error number -128
			end try

		else if what is "Update yt-dlp" then
			set r to do shell script shellPrefix & ytdlPath & " --update"
			display dialog r with title appTitle buttons {"OK"} default button "OK"
		end if
	end repeat
end moreScreen
