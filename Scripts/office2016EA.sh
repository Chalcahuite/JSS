#!/bin/bash
officeApps=( "Excel.app" "Outlook.app" "PowerPoint.app" "Word.app")
for app in ${officeApps[*]}; do
	if ! [[ -d "/Applications/Microsoft $app" ]]; then
		echo "<result>False</result>"
		exit 0
	fi
done	
echo "<result>True</result>"
exit 0