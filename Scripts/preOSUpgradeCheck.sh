#!/bin/bash
# preOSUpgradeCheck.sh
# Script to verify apps compatible before upgrading. Presumes Jamf Pro as management tool. 
# ©2021 by Sergio Aviles.
# version 1.0.0 2021-02-15 Forked and sanitized for public use. 
# version 1.0.1 2021-02-18 Fixed issue where prompts were not seen if runSilent was set to "NO." Future proofed JSSTrust function. Added alert for 
#                          disk space errors. Added extra conditional to disk space check to account for more larger space requirements for Mojave and earlier. 

##Variables
User=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')
# AppPath and AppVersion variables for demo purposes. Customize for your needs as you see fit. 
AppPath="/Applications/MyApp.app" 
AppVersion=$(/usr/bin/defaults read "$AppPath/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null | /usr/bin/awk -F\. '{print $1$2}' )
HDName=$(/usr/sbin/diskutil list | /usr/bin/awk '/Apple_HFS/ {print $3,$4}')
iconPath="/pat/to/your/Custom_icon.icns" # If you have a custom icon you'd like to use for osascript dialog boxes, put it here. 
theIconPath="$HDName"$(/bin/echo "$iconPath" | /usr/bin/sed 's/\//:/g')
jamfbin="/usr/local/bin/jamf"
osmajver=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F\. '{print $1}')
osver=$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F\. '{print $2}')
macOSName=""
cacheInstaller="$4" # Option to install the macOS installer on the local drive prior to upgraing, originally for use with startosinstall
spaceStatus=""
runSilent="$5" # Expects "YES" or "NO" "YES" means no dialogs will be shown to the user. 
cacheVersion="$6" # Originally for use with startosinstall
upgradeVersion="$7" # For use with determining name. for 10.x upgrades use the "minor" version, e.g for Catalina, use 15; for Big Sur and newer use major version, e.g. 11.


##Functions
ScriptLogging()
{
    # Logging function to output to both console out for Jamf Pro agent
    # collection and also to a local file. 
    log_location="/path/to/your/logfile.log"
    DATE=$(/bin/date +%Y-%m-%d\ %H:%M:%S)
    LOG="$log_location"
    script_name="OS Upgrade Compatibility Check"
    
    /bin/echo "$DATE" "[$script_name]  $1" >> $LOG #log to local file
    /bin/echo "$DATE" "[$script_name]  $1" # log to default console output
}

runAsUser()
{  
  # runAsUser function liberated from ScriptingOSX
  # https://scriptingosx.com/2020/08/running-a-command-as-another-user/
  # convenience function to run a command as the current user
  # usage:
  #   runAsUser command arguments...
  currentUser="$User"
  uid=$(/usr/bin/id -u "$currentUser")
  if [[ "$currentUser" != "loginwindow" ]]; then
    /bin/launchctl asuser "$uid" /usr/bin/sudo -u "$currentUser" "$@"
  else
    ScriptLogging "No user logged in"
    # uncomment the exit command
    # to make the function exit with an error when no user is logged in
    ScriptLogging "-----End-----"
    exit 1
  fi
}

determineOSName()
{
  #Use passed parameter to determine which OS Name to use in dialogs. 
  OSX_MARKETING=(
  ["12"]="Sierra"
  ["13"]="High Sierra"
  ["14"]="Mojave"
  ["15"]="Catalina"
  ["11"]="Big Sur"
)
  if [[ -n "${OSX_MARKETING[$upgradeVersion]}" ]]; then 
    ScriptLogging "Determining OS version."
    macOSName="macOS ${OSX_MARKETING[$upgradeVersion]}"
  else
    ScriptLogging "Unable to determine upgrade OS Version. Exiting."
    ScriptLogging "-----End-----"
    exit 2
  fi
}

checkforIcon()
{
  # Presumes that you package and install a custom icon(s) to your fleet.
  # Check if icon is installed, and install it if it's missing. 
  if [[ -e "$iconPath" ]]; then
    ScriptLogging "Icon file found. Proceeding."
  else
    ScriptLogging "Icon file missing. Downloading."
    $jamfbin policy -event addLogo
  fi
}


updateApp() 
{
  # Demo function to update app. Customize and duplicate per your needs.
  # Function presumes you have a policy to install/update app with a custom trigger.
  ScriptLogging "Verifying if MyApp is installed."
  if [[ -e "$AppPath" ]]; then 
    ScriptLogging "MyApp is installed. Checking version."
    if [[ ${AppVersion} -lt 1234 ]]; then 
      if [[ "$runSilent" == "NO" ]]; then
        ScriptLogging "MyApp needs to be updated for $macOSName compatibility. Alerting user."
        runAsUser /usr/bin/osascript -e 'display dialog "Your version of MyApp needs to be upgraded for $macOSName compatibility. Standby." with title "'"$macOSName"' Pre-Upgrade Check" with icon file "'"$theIconPath"'" giving up after 5'
        ScriptLogging "Installing $macOSName compatible version of MyApp."
        $jamfbin policy -event updateApp # calls Jamf policy to install/update app with custom trigger. 
      else 
        ScriptLogging "Silent flag set. Skipping alert. Updating app."
        $jamfbin policy -event updateApp # calls Jamf policy to install/update app with custom trigger. 
    else
      ScriptLogging "MyApp version is compatible with $macOSName. Proceeding."
    fi
  else
    ScriptLogging "MyApp is not installed. Skipping."
  fi

}

removeApp()
{
  # Demo function to remove app that requires a restart. Dialog gives user option to defer uninstall. Customize and duplicate per your needs.
  # Function presumes you have a policy to remove/uninstall app with a custom trigger.
  ScriptLogging "Verifying if MyOtherApp is installed."
  if [[ -e "$AppPath" ]]; then
    ScriptLogging "MyOtherApp is installed. Removing."
    if [[ "$runSilent" == "NO" ]]; then 
      ScriptLogging "Alerting user."
      result=$(runAsUser /usr/bin/osascript -e 'set result to button returned of (display dialog "MyOtherApp needs to be removed before upgrading. A restarted is required. Click "OK" to proceed" buttons {"Cancel", "OK"} default button 2 with title "'"$macOSName"' Pre-Upgrade Check" with icon file "'"$theIconPath"'" giving up after 5')
      if [[ "$result" == "OK" ]]; then 
          ScriptLogging "User consented. Uninstalling MyOtherApp."
          "$jamfbin" policy -event uninstallMyOtherApp
      else
          ScriptLogging "User did not consent. Skipping."
      fi
    else 
      ScriptLogging "Silent flag set. Skipping alert. Uninstalling MyOtherApp."
      "$jamfbin" policy -event uninstallMyOtherApp
    fi
  fi 
}

checkDiskSpace()
{
  # Function liberated from https://github.com/kc9wwh/macOSUpgrade
  ##Check if free space > 25GB
  osMajor=$( /usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $2}' )
  osMinor=$( /usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $3}' )
  if [[ $osMajor -eq 12 ]] || [[ $osMajor -eq 13 && $osMinor -lt 4 ]]; then
      freeSpace=$( /usr/sbin/diskutil info / | /usr/bin/grep "Available Space" | /usr/bin/awk '{print $6}' | /usr/bin/cut -c 2- )
  else
      freeSpace=$( /usr/sbin/diskutil info / | /usr/bin/grep "Free Space" | /usr/bin/awk '{print $6}' | /usr/bin/cut -c 2- )
  fi

  if [[ $osMajor -eq 15 ]]; then
    if [[ ${freeSpace%.*} -ge 25000000000 ]]; then
        spaceStatus="OK"
        ScriptLogging "Disk Check: OK - ${freeSpace%.*} Bytes Free Space Detected"
    else
        spaceStatus="ERROR"
        ScriptLogging "Disk Check: ERROR - ${freeSpace%.*} Bytes Free Space Detected"
        if [[ "$runSilent" == "NO" ]]; then
          ScriptLogging "Alerting user."
          runAsUser /usr/bin/osascript -e 'display dialog "The free disk space available is insufficient to upgrade the OS. A minimum of 25GBs is needed to perform this upgrade. Click \"OK\" to exit." with title "An error has occurrred" buttons {"OK"} default button 1 with icon caution giving up after 15'
          ScriptLogging "-----End-----"
          exit 1
        else
          ScriptLogging "Silent flag set. Skipping alert. Exiting."
          ScriptLogging "-----End-----"
          exit 1
        fi
    fi
  else
    if [[ ${freeSpace%.*} -ge 45000000000 ]]; then
        spaceStatus="OK"
        ScriptLogging "Disk Check: OK - ${freeSpace%.*} Bytes Free Space Detected"
    else
        spaceStatus="ERROR"
        ScriptLogging "Disk Check: ERROR - ${freeSpace%.*} Bytes Free Space Detected"
        if [[ "$runSilent" == "NO" ]]; then
          ScriptLogging "Alerting user."
          runAsUser /usr/bin/osascript -e 'display dialog "The free disk space available is insufficient to upgrade the OS. A minimum of 45GBs is needed to perform this upgrade. Click \"OK\" to exit." with title "An error has occurrred" buttons {"OK"} default button 1 with icon caution giving up after 15'
          ScriptLogging "-----End-----"
          exit 1
        else
          ScriptLogging "Silent flag set. Skipping alert. Exiting."
          ScriptLogging "-----End-----"
          exit 1
        fi
    fi
  fi
}

checkPassedParameter()
{
  # Verifies that data is being passed in all parameters.
  if [[ -z "$cacheInstaller" ]]; then 
    ScriptLogging "No value for cacheInstaller passed. Skipping."
  else
    ScriptLogging "Value set for cacheInstaller. Proceeding."
  fi

  if [[ -z "$runSilent" ]]; then 
    ScriptLogging "No value for runSilent passed. Skipping."
  else
    ScriptLogging "Value set for runSilent. Proceeding."
  fi

  if [[ -z "$cacheVersion" ]]; then 
    ScriptLogging "No value set for cacheVersion. Skipping."
  else
    ScriptLogging "Value set for cacheVersion. Proceeding."
  fi

  if [[ -z "$upgradeVersion" ]]; then 
    ScriptLogging "No value set for upgradeVersion. Aborting."
    ScriptLogging "-----End-----"
    exit 1
  else
    ScriptLogging "Value set for upgradeVersion. Proceeding."
  fi
}

cacheInstaller()
{
  #If cacheInstaller variable is set to "YES" the call policy to download installer to local Mac.
  if [[ "$cacheInstaller" == "YES" ]]; then 
    ScriptLogging "Caching installer app on Mac."
    if [[ "$cacheVersion" == "Mojave" ]]; then 
      ScriptLogging "Caching macOS Mojave."
      $jamfbin policy -event cacheMojaveInstaller
    elif [[ "$cacheVersion" == "Catalina" ]]; then
      ScriptLogging "Caching macOS Catalina"
      $jamfbin policy -event cacheCatalinaInstaller
    else
      ScriptLogging "Caching current macOS Installer"
      $jamfbin policy -event cacheInstaller
    fi
  else
    ScriptLogging "Skipping caching of installer app. "
  fi
}

unhideOSInstaller()
{
  #Resets ignored software updates in Software Update if you ignored a macOS major release. 
  ScriptLogging "Reset ignored udpates"
  /usr/sbin/softwareupdate --reset-ignored
}

openAppStore()
{
  # Opens the App Store page for macOS Big Sur. Modify for any future macOS releases. 
  ScriptLogging "Launching App Store"
  runAsUser /usr/bin/open -a 'App Store' 'https://apps.apple.com/us/app/macos-big-sur/id1526878132?mt=12'
}

main()
{
  ScriptLogging "-----Start-----"
  checkPassedParameter
  determineOSName
  checkforIcon
  checkDiskSpace
  if [[ "$spaceStatus" == "OK" ]]; then
    updateApp
    removeApp
    #uncomment to cache installer locally. 
    #cacheInstaller
    unhideOSInstaller
    openAppStore
  else
    ScriptLogging "Not enough Disk Space for the installer. Aborting."
    ScriptLogging "-----End-----"
    /usr/bin/killall jamf
    exit 1
  ScriptLogging "-----End-----"
  fi
}

##Execute

main
exit 0
