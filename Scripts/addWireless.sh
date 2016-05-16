#!/bin/bash
# addWireless.sh
# Script to add wireless network to a Mac
# ©2016 by Sergio Aviles and Tyler Morgan.

##Variables
echo "Getting Login."
User=$(python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')
UserID=$(dscl . read /Users/"$User" UniqueID | awk '$2 > 1000 {print $2}')
JAMF=$(which jamf)
iconPath="/path/to/your/logo/icon.png"
osVers=$(sw_vers -productVersion | awk -F\. '{ print $2 }')
SSID=""
customTrigger=""

##Functions
checkforIcon()
{
  if [[ ! -f "$iconPath" ]]; then
    echo "Icon file missing. Downloading."
    $JAMF policy -event "$customTrigger"
  else
    echo "Icon file found. Proceeding."
  fi
}

getuserID()
{
if [[ ${UserID} -gt 1000 ]];then
	echo "Network user detected. Proceeding."
	else
	echo "$user is not a network user. Prompting for network user login."
	user=$(osascript -e 'Tell application "SystemUIServer" to display dialog "Please enter a network user login" default answer "" with title "Enter NTlogin" with text buttons {"OK"} default button 1with icon file "Macintosh HD:path:to:your:logo:icon.png" as alias' -e 'text returned of result')
	echo "Entered user $user."
fi
}

getPassword()
{
echo "Prompting for user's password."
uPass=$(osascript -e 'Tell application "SystemUIServer" to display dialog "Please enter the password for '$User':" with hidden answer default answer "" with title "Enter Password" with text buttons {"OK"} default button 1 with icon file "Macintosh HD:Library:Application Support:CES:Comcast_Icons:Icon.iconset:Icon_256x256.png" as alias' -e 'text returned of result')
}

addWireless()
{
echo "Adding $SSID to login keychain for $User."
  if [[ ${osVers} -ge 10 ]]; then
      security add-generic-password -a "$User" -s "com.apple.network.eap.user.item.wlan.ssid.$SSID" -w "$uPass" -D "802.1X Password" -l "$SSID" -T "/System/Library/CoreServices/SystemUIServer.app" -T "group:///AirPort" -T "/System/Library/SystemConfiguration/EAPOLController.bundle/Contents/Resources/eapolclient" -T "/System/Library/CoreServices/WiFiAgent.app"
      networksetup -addpreferredwirelessnetworkatindex en0 $SSID 1 WPA2E
  else
      security add-generic-password -a "$User" -s "com.apple.network.eap.user.item.wlan.ssid.$SSID" -w "$uPass" -D "802.1X Password" -l "$SSID" -T "/System/Library/CoreServices/SystemUIServer.app" -T "group:///AirPort" -T "/System/Library/SystemConfiguration/EAPOLController.bundle/Contents/Resources/eapolclient"
      networksetup -addpreferredwirelessnetworkatindex en0 $SSID 1 WPA2E
  fi
}

createKeychain()
{
    #Create the new login keychain
    echo "Creating login keychain for user"
expect <<- DONE
  set timeout -1
  spawn su $User -c "security create-keychain login.keychain"

  # Look for  prompt
  expect "*?chain:*"
  # send user entered password from CocoaDialog
  send "$uPass\n"
  expect "*?chain:*"
  send "$uPass\r"
  expect EOF
DONE

#Set the newly created login.keychain as the users default keychain
su $User -c "security default-keychain -s login.keychain"
}

##Execute
sleep 5
checkforIcon
if [[ -f /Users/"$User"/Library/Keychains/login.keychain ]]; then
    getuserID
    getPassword
    addWireless
  else
    createKeychain
    getuserID
    getPassword
    addWireless
fi

echo "——End——"
exit 0
