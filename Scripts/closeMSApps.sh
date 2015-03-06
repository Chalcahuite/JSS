#!/bin/sh
# closeMSapps.sh
# detects running Microsoft Apps and prompts user to close before proceeding. 

## Define Variables
closeApps="NO"
MSDBU="Microsoft Database Utility"
MSAU="Microsoft AutoUpdate"
MSExcel="Microsoft Excel"
MSWord="Microsoft Word"
MSOutlook="Microsoft Outlook"
MSLync="Microsoft Lync"
MSPP="Microsoft PowerPoint"
MSDC="Microsoft Document Connection" 

## Define Functions

detectMSApps() # detects if MSDButil is running
{
microsoftPID=`pgrep Microsoft | head -1`
if [[ ${microsoftPID} -gt 0 ]]; then
	echo "Microsoft Apps are running. Proceeding...."
	closeApps="YES"
	else 
	echo "Microsoft Apps are not running. Skipping...."
fi
}


getuserConsent() # get user OK to close browsers
{
jhpath=/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper
iconpath=/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns
userConsent=`"$jhpath" -windowType hud -title "Please Choose" -heading "Close Microsoft Apps" -description "No Microsoft apps can be running during the Office 2016 Preview installation. Click Yes to proceed." -icon "$iconpath" -button1 "Yes" -button2 "No" -defaultButton 1 -cancelButton 2 -timeout 10 -countdown -lockHUD &`
if [[ ${userConsent} == "0" ]]; then
	echo "User consent given. Proceeding to shut down open browsers...."
	closeApps="YES"
	else
	echo "User consent not given. Exiting."
	killall jamf
	exit 1
fi
}

closeMSApps() # quit Safari gracefully
{
osascript -e 'quit app "Microsoft Database Utility"'
osascript -e 'quit app "Microsoft AutoUpdate"'
osascript -e 'quit app "Microsoft Excel"'
osascript -e 'quit app "Microsoft Word"'
osascript -e 'quit app "Microsoft Outlook"'
osascript -e 'quit app "Microsoft Lync"'
osascript -e 'quit app "Microsoft PowerPoint"'
osascript -e 'quit app "Microsoft Document Connection"'
echo "Closing Microsoft Apps."
}


## Execute

# Detect running browsers
echo "Looking to see if there are any Microsoft apps running that need to be closed...."
detectMSApps


# Get User Consent
if [[ ${closeApps} == "YES" ]]; then
	echo "Microsoft Apps running. Prompting user for permissions to close apps...."
	getuserConsent
	else
	echo "No Microsoft apps detected. Proceeding with installation...."
	closeApps="NO"
	exit 0
fi

# Close browsers
if [[ ${closeApps} == "YES" ]]; then
	echo "Closing browsers and proceeding with installation...."
	closeMSApps
	
fi
exit 0


