use scripting additions
use framework "Foundation"
use framework "AppKit"

-- This is the line you need to change!
-- It should to point to the user that controls the parent account
property dataStorageDirectory : "/Users/carlerik/"

--------------------------------------------------------------------------------
-- Do not change below this line
--------------------------------------------------------------------------------
property statusItem : missing value
property interval : 1.0
property dailyUsageFile : dataStorageDirectory & "mc-daily-usage.txt"
property dailyUsageTime : "00:00:00"
property weeklyUsageFile : dataStorageDirectory & "mc-weekly-usage.txt"
property weeklyUsageTime : "00:00:00"
property monitoredProcess : "minecraft"
property processGrepPattern : "[m]inecraft"
property weeklyUsageLimit : "05:00:00"
property dailyUsageLimit : "00:45:00"
property logFile : dataStorageDirectory & "mc-usage-log.txt"

writeFile("", logFile, 0)

-- Reset daily usage file if the day changed
try
	tell application "System Events" to set fileDate to creation date of file dailyUsageFile
	set fileDateString to formatDate(fileDate)
	set currentDateString to formatDate(current date)
	if fileDateString ≠ currentDateString then
		writeFile("Reset daily usage: " & fileDateString & " ≠ " & currentDateString, logFile, 1)
		do shell script "rm -f " & quoted form of dailyUsageFile
		writeFile(dailyUsageTime, dailyUsageFile, 0)
	end if
on error err
	writeFile("Daily reset error: " & err, logFile, 1)
end try

-- Reset weekly usage file if week changed
try
	tell application "System Events" to set fileDate to creation date of file weeklyUsageFile
	set fileWeekNumber to weekNumber(fileDate)
	set currentWeekNumber to (do shell script "date +%W") as integer
	if fileWeekNumber ≠ currentWeekNumber then
		writeFile("Reset weekly usage: Week " & fileWeekNumber & " ≠ " & currentWeekNumber, logFile, 1)
		do shell script "rm -f " & quoted form of weeklyUsageFile
		writeFile(weeklyUsageTime, weeklyUsageFile, 0)
	end if
on error err
	writeFile("Weekly reset error: " & err, logFile, 1)
end try

set dailyUsageTime to readFileOrDefault(dailyUsageFile, dailyUsageTime)
set weeklyUsageTime to readFileOrDefault(weeklyUsageFile, weeklyUsageTime)

my updateStatusItem("Minecraft Today: " & dailyUsageTime & " Week: " & weeklyUsageTime)

repeat
	tell application "System Events"
		set activeProcess to name of first process whose frontmost is true
	end tell

	if activeProcess contains "java" or activeProcess contains monitoredProcess then
		set processDetails to (do shell script "pgrep -lf " & quoted form of processGrepPattern)
		if processDetails ≠ "" then
			set dailyUsageTime to incrementTime(dailyUsageFile, dailyUsageTime, interval)
			set weeklyUsageTime to incrementTime(weeklyUsageFile, weeklyUsageTime, interval)

			my updateStatusItem("Minecraft Today: " & dailyUsageTime & " Week: " & weeklyUsageTime)

			if weeklyUsageTime > weeklyUsageLimit or dailyUsageTime > dailyUsageLimit then
				try
					do shell script "pgrep -f " & quoted form of processGrepPattern & " | xargs kill"
				end try
			end if
		end if
	end if

	delay interval
end repeat

on updateStatusItem(statusText)
	try
		current application's NSStatusBar's systemStatusBar()'s removeStatusItem:statusItem
	on error err
		writeFile("Status bar removal error: " & err, logFile, 1)
	end try
	set my statusItem to current application's NSStatusBar's systemStatusBar's statusItemWithLength:(current application's NSVariableStatusItemLength)
	statusItem's setTitle:statusText
end updateStatusItem

on readFileOrDefault(filePath, defaultValue)
	try
		return (do shell script "cat " & quoted form of filePath)
	on error
		writeFile(defaultValue, filePath, 0)
		return defaultValue
	end try
end readFileOrDefault

on writeFile(textContent, filePath, eofMode)
	if eofMode = 0 then
		do shell script "echo " & quoted form of textContent & " > " & quoted form of filePath
	else
		do shell script "echo " & quoted form of textContent & " >> " & quoted form of filePath
	end if
end writeFile

on incrementTime(filePath, currentTime, incrementSeconds)
	set newTimeSecs to timeToSeconds(currentTime) + incrementSeconds
	set newTimeString to secondsToTime(newTimeSecs)
	writeFile(newTimeString, filePath, 0)
	return newTimeString
end incrementTime

on timeToSeconds(timeString)
	set AppleScript's text item delimiters to ":"
	set {hrs, mins, secs} to text items of timeString
	set AppleScript's text item delimiters to ""
	return (hrs as integer) * 3600 + (mins as integer) * 60 + (secs as integer)
end timeToSeconds

