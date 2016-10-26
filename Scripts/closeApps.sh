#!/bin/bash
# closeApps.sh
# pre-install script to make sure app is closed before installing. If running, prompt the user for permission to close.
# logging function "inspired" by Rich Trouton.

#Define Logging
log_location="/path/to/my.log" #change this to a log file you already use or create a new one. Log will echo to JSS and write locally. 
ScriptLogging()
{

    DATE=$(date +%Y-%m-%d\ %H:%M:%S)
    LOG="$log_location"

    echo "$DATE" " $1" >> $LOG
    echo "$DATE" " $1"
}

ScriptLogging "-----Blocking App Check-----"

##Variables
closeApp="NO"
App="$4" #Add an Application name in the JSS/JPS as part of the script options tab.
if [[ ! $4 ]]; then
   	ScriptLogging "No Application name. Aborting."
    exit 1
    else
    App="$4"
fi

##Functions
detectApp() # detects if App is running
{
appPID=$(pgrep "$App" | head -1) 
if [[ ${appPID} -gt 0 ]]; then
	ScriptLogging "$App is running. Proceeding...."
	closeApp="YES"
	else
	ScriptLogging "$App is not running. Skipping...."
fi
}

closeApp() # quit Server gracefully
{
ScriptLogging "Quitting $App...."
osascript -e 'quit app "'"$App"'"'
ScriptLogging "$App closed."
}

getuserConsent() # get user OK to close app, if running
{
jhpath="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
AppPath=$(find -x / -name "$App.app" | awk 'NR==1 {print $0}')
iconName=$(ls $AppPath/Content/Resources/ | grep "icns")
iconpath="$AppPath/Contents/Resources/$iconName"
userConsent=$("$jhpath" -windowType hud -title "Your IT Department here" -heading "'"$App Updater"'" -description "Can we close $App to update it to a new version?" -icon "$iconpath" -button1 "Yes" -button2 "No" -defaultButton 1 -cancelButton 2 -timeout 300 -countdown -lockHUD &)
if [[ ${userConsent} == "0" ]]; then
	ScriptLogging "User consent given. Proceeding to shut down $App.app...."
	closeApp="YES"
else
	ScriptLogging "User consent not given. Exiting."
	killall jamf
	exit 0
fi
}

main()
{
  #Check to see if the App is running
  detectApp

  # Get User Consent
  if [[ ${closeApp} == "YES" ]]; then
  	ScriptLogging "$App.app is currently running. Prompting user for permissions to close $App...."
  	getuserConsent
    # Close Server
    if [[ ${closeApp} == "YES" ]]; then
    	echo "Closing $App and proceeding with installation...."
    	closeApp
    fi
  else
  	ScriptLogging "No running $App detected. Proceeding with installation...."
  	closeApp="NO"
  	exit 0
  fi
}

##Execute
main

ScriptLogging "-----End-----"
exit 0
