#!/bin/bash
# updateOAB.sh
# Deletes the .oab files in a User's Office 2016 profile to force a re-download of the Offline Address Book.
# © 2016-2017 by Sergio Aviles.
# version 1.0 2016-01-12
# version 2.0 2016-05-18 Added warnings for user, and restart Outlook function.
# version 3.0 2017-03-17 Expanded script to check if OAB files exist. Added checks to verify AutoDiscover and LDAP settings. Added function to download the OAB. And added function to verify GAL works for user.
# version 3.1 2017-03-20 sanitized for public use.

#Define Logging
# Scriptlogging function stolen shamelessly from Rich Trouton. https://github.com/rtrouton/rtrouton_scripts/blob/d10289c6614b13bb0e27cf8bba00910c08a6c317/rtrouton_scripts/delete_user_keychains/delete_user_keychains.sh
ScriptLogging()
{
    log_location="/Path/To/Log.log" # change to point to the path you want your log file to live.
    DATE=$(/bin/date +%Y-%m-%d\ %H:%M:%S)
    LOG="$log_location"

    /bin/echo "$DATE" " $1" >> $LOG
    #/bin/echo "$DATE" " $1" # extra pipe to echo to get picked up by a JSS when run as a policy. (Optional. Un-comment to use.)
}

ScriptLogging "-----Verify/Update GAL-----"

##Variables
#get user from https://macmule.com/2014/11/19/how-to-get-the-currently-logged-in-user-in-a-more-apple-approved-way/
User=$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
#get current date minus 24 hours
dateMinus24h=$(/bin/date -v-86400S +%s)
#get last modified date of udetails.oab file
oabModifiedDate=$(/usr/bin/stat -Ls "$cachePath"/*/IndexDirName_*/udetails.oab | /usr/bin/awk ' { print $10 }' | /usr/bin/awk -F= '{print $2}')
#Logo files (Alter to point to your logo image/icons.)
iconPath="/path/to/logo.icns"
#prep icon path for applescript by swapping "/" for ":".
theIconPath=$(/bin/echo "$iconPath" | /usr/bin/sed 's/\//:/g')
#path to Outlook
Outlook="/Applications/Microsoft Outlook.app"
#path to User's Outlook cache
cachePath="/Users/$User/Library/Group Containers/UBF8T346G9.Office/Outlook/Outlook 15 Profiles/Main Profile/Caches"
#Window heading (Alter to taste.)
headingText="Updating the Offline Address Book"
#Restart Outlook Warning (Alter to taste.)
warningText="Outlook 2016 is currently runnning and will be restarted if the address book file needs to be updated. This process will automatically relaunch Outlook on completion."
#Outlook 2011 found text (Alter to taste.)
oldVersionText="Outlook 2016 is missing from this Mac. This script is compatible only with Outlook 2016. Please contact IT for issues with Outlook 2011."
#Alert user that oab file will be purged (Alter to taste.)
purgeText="The Offline Address Book (GAL) file is out of date and will be updated."
#Alert user that no action will be taken. (Alter to taste.)
noAction="The Offline Address Book (GAL) is current and will not be updated at this time."
#Outlook Process checkUser
OutlookPID=$(/usr/bin/pgrep Outlook)

##Functions
checkforIcon()
{
  #Verify that icon files are present, download and install if not.
  if [[ -e "$iconPath" ]]; then
    ScriptLogging "Icon files present. Proceeding."
  else
    ScriptLogging "Icon files missing. Installing."
    #Error out or add line to install missing icon files.
    #exit 111
  fi
}

alertUser()
{
  #If Outlook 2016 is present and running, warn user that it will need to be restarted after the script runs; if Outlook isn't runnning, proceed silently. If Outlook 2016 isn't on the Mac exit out quietly.
  if [[ -e "$Outlook" ]]; then
    ScriptLogging "Outlook 2016 found. Proceeding."
    #check if Outlook is running.
    if [[ ${OutlookPID} -ge 0 ]]; then
      ScriptLogging "Outlook 2016 is running. Will need to be bounced after purging OAB file."
      #Set value to restartOutlook for later.
      restartOutlook=1
      #Warn user that Outlook may need to be restarted.
      /usr/bin/sudo -u "$User" /usr/bin/osascript -e 'tell application "System Events"' -e 'with timeout of 86400 seconds' -e 'display dialog "'"$warningText"'" with title "'"$headingText"'" with text buttons {"OK"} default button 1 with hidden answer with icon file "'"$theIconPath"'"' -e 'end timeout' -e 'end tell'
    else
      #Outlook isn't running. No need to restart. Set restartOutlook value to 0.
      ScriptLogging "Outlook 2016 is not running. Proceeding."
      restartOutlook=0
    fi
  else
    #Outlook 2016 not on this box. Inform user that there's no Outlook 2016 and then exit without doing anything.
    ScriptLogging "Outlook 2016 not found. Exiting."
    /usr/bin/sudo -u "$User" /usr/bin/osascript -e 'tell application "System Events"' -e 'with timeout of 86400 seconds' -e 'display dialog "'"$oldVersionText"'" with title "'"$headingText"'" with text buttons {"OK"} default button 1 with hidden answer with icon file "'"$theIconPath"'"' -e 'end timeout' -e 'end tell'
    ScriptLogging "-----END-----"
    exit 0
  fi
}

restartApp()
{
  # Quit out of Outlook "gracefully".
  if [[ ${restartOutlook} -eq 1 ]]; then
    ScriptLogging "Quitting Micrososft Outlook."
    /usr/bin/osascript -e 'quit app "Microsoft Outlook"'
    OutlookPID=$(/usr/bin/pgrep Outlook)
    while [[ ${OutlookPID} -gt 0 ]]; do
      /bin/sleep 5
      OutlookPID=$(/usr/bin/pgrep Outlook)
      if [[ ${OutlookPID} -gt 0 ]]; then
        ScriptLogging "Waiting for Outlook to quit."
      else
        ScriptLogging "Restarting Outlook."
        /usr/bin/osascript -e 'tell app "Microsoft Outlook" to activate'
      fi
    done
  fi
}

purgeOAB()
{
# If the last modified date of the udetails.oab file is older than the current date minus 24 hours then delete all the .oab files to force a download.
ScriptLogging "Determining whether last modified date of OAB is older than 24 hours ago."
if [[ ${dateMinus24h} -gt ${oabModifiedDate} ]]; then
  /usr/bin/sudo -u "$User" /usr/bin/osascript -e 'tell application "System Events"' -e 'with timeout of 86400 seconds' -e 'display dialog "'"$purgeText"'" with title "'"$headingText"'" with text buttons {"OK"} default button 1 with hidden answer with icon file "'"$theIconPath"'"' -e 'end timeout' -e 'end tell'
  /bin/rm -r "$cachePath/*/IndexDirName_*/*.oab"
  ScriptLogging "OAB last modified date is older than 24 hours. Deleting all .oab files to force a new download."
  restartApp
else
  ScriptLogging "OAB has been recently updated. No force update required. "
  /usr/bin/sudo -u "$User" /usr/bin/osascript -e 'tell application "System Events"' -e 'with timeout of 86400 seconds' -e 'display dialog "'"$noAction"'" with title "'"$headingText"'" with text buttons {"OK"} default button 1 with hidden answer with icon file "'"$theIconPath"'"' -e 'end timeout' -e 'end tell'
fi
}

checkAutoDiscover()
{
  #check to see if the autodiscover background service is on. If off, enable it.
    checkAutoDiscoverEnabled=$(/usr/bin/sudo -u "$User" /usr/bin/osascript -e 'tell application "Microsoft Outlook" to get background autodiscover of exchange account 1')
  if [[ "$checkAutoDiscoverEnabled" = "false" ]]; then
    ScriptLogging "Background AutoDiscover service not enabled. Enabling."
    /usr/bin/sudo -u "$User" /usr/bin/osascript -e 'tell application "Microsoft Outlook" to set background autodiscover of exchange account 1 to true'
  else
    ScriptLogging "Background AutoDiscover server enabled. Proceeding."
  fi
}

downloadOABFiles()
{
  ScriptLogging "Pausing....."
  /bin/sleep 5
  ScriptLogging "Kickstarting download of OAB file."
  /usr/bin/sudo -u "$User" /usr/bin/osascript -e 'tell application "Microsoft Outlook" to download oab now of exchange account 1'
}

checkForOAB()
{
  #Check to see if user has any .oab files before proceeding.
  detectOAB=$(/usr/bin/find "$cachePath" -maxdepth 3 -iname '*.oab')
  if [[ -z "$detectOAB" ]]; then
    ScriptLogging "No OAB files found for User $User."
    downloadOAB=1
  else
    ScriptLogging "OAB files for for User $User. Proceeding."
    downloadOAB=0
  fi
}

setGAL()
{
  if [[ ${OutlookPID} -gt 0 ]]; then
    ScriptLogging "Setting contacts search source to GAL."
    /usr/bin/sudo -u "$User" /usr/bin/osascript << EOF
    tell application "Microsoft Outlook"
	set accountName to (get name of exchange account 1)
	set theSearch to text returned of (display dialog "Search the Comcast Global Address Book:" default answer "Enter a name or network login" with icon 1 with title "Search")
	set visible of shared contacts panel to true
	tell shared contacts panel
		set current source to directory source (accountName & " Directory")
		set search string to theSearch
	end tell
end tell
EOF
  else
    ScriptLogging "Outlook not running. Launching."
    /usr/bin/osascript -e 'tell app "Microsoft Outlook" to activate'
    /bin/sleep 5
    ScriptLogging "Setting contacts search source to GAL."
    /usr/bin/sudo -u "$User" /usr/bin/osascript << EOF
    tell application "Microsoft Outlook"
	set accountName to (get name of exchange account 1)
	set theSearch to text returned of (display dialog "Search the Comcast Global Address Book:" default answer "Enter a name or network login" with icon 1 with title "Search")
	set visible of shared contacts panel to true
	tell shared contacts panel
		set current source to directory source (accountName & " Directory")
		set search string to theSearch
	end tell
end tell
EOF
  fi
}

verifyLDAP()
{
  verifySSLEnabled=$(/usr/bin/sudo -u "$User" /usr/bin/osascript -e 'tell application "Microsoft Outlook" to get ldap use ssl of exchange account 1')
  verifyNeedsAuthentication=$(/usr/bin/sudo -u "$User" /usr/bin/osascript -e 'tell application "Microsoft Outlook" to get ldap needs authentication of exchange account 1')
  if [[ "$verifySSLEnabled" = "false" ]]; then
    ScriptLogging "Use SSL for Directory Services server not enabled. Enabling."
    /usr/bin/sudo -u "$User" /usr/bin/osascript -e 'tell application "Microsoft Outlook" to set ldap use ssl of exchange account 1 to true'
  else
    ScriptLogging "Use SSL for Directory Services server enabled. Proceeding."
  fi
  if [[ "$verifyNeedsAuthentication" = "false" ]]; then
    ScriptLogging "User authentication for Directory Services server not enabled. Enabling."
    /usr/bin/sudo -u "$User" /usr/bin/osascript -e 'tell application "Microsoft Outlook" to set ldap needs authentication of exchange account 1 to true'
  else
    ScriptLogging "User authentication for Directory Services server enabled. Proceeding."
  fi
}

fixGAL()
{
  checkForOAB
  if [[ ${downloadOAB} = 1 ]]; then
    verifyLDAP
    checkAutoDiscover
    downloadOABFiles
    setGAL
  else
    verifyLDAP
    checkAutoDiscover
    alertUser
    purgeOAB
    downloadOABFiles
    setGAL
  fi

}

main()
{
  checkforIcon
  fixGAL
}
###Execute
main
ScriptLogging "-----End-----"
exit 0
