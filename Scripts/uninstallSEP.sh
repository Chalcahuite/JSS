#!/bin/bash
# uninstallSEP.sh
# Script to uninstall Symantec Endpoint Protection and all its components. Requires restart when complete.
# ©2020 by Sergio Aviles. 
# version 1.0.0 2020-03-30
# version 1.1.0 2020-07-14 Add check for app in "Incompatible Software" folder. 


##Variables

##Functions
ScriptLogging()
{
    #Define Logging
    log_location="/path/to/your/own/log/file.log"
    DATE=$(/bin/date +%Y-%m-%d\ %H:%M:%S)
    LOG="$log_location"
    script_name="Uninstall SEP"
    
    /bin/echo "$DATE" "[$script_name] $1" >> $LOG
    /bin/echo "$DATE" "[$script_name] $1" 
}

removeLaunchDaemons()
{   
    #Unload any launchdaemons found and then delete them.
    LaunchDaemons=("$(/usr/bin/find -x /Library/LaunchDaemons -name "com.symantec.*")")
    # echo "${LaunchDaemons[*]}"
    if [[ -n "${LaunchDaemons[*]}" ]]; then 
        ScriptLogging "Found LaunchDaemons to remove."
        for ld in ${LaunchDaemons[@]}; do
            ScriptLogging "Unloading $ld"
            /bin/launchctl bootout system "$ld"
            ScriptLogging "Removing $ld"
            /bin/rm -f "$ld"
        done
    else
        ScriptLogging "No LaunchDaemons found. Skipping."
    fi 
}

removeFiles()
{
    #Remove all support files and apps. 
    #Remove the regid files.
    regid_files=("$(/usr/bin/find -x "/Library/Application Support" -name "regid.*")")
    if [[ -n "${regid_files[*]}" ]]; then 
        ScriptLogging "Removing regid files"
        for r in "${regid_files[@]}"; do
        /bin/rm -f "$r"
        done
    else
        ScriptLogging "No regid files found. Skipping."
    fi

    #Remove re-located App.
    if [[ -e "/Incompatible Software/Symantec Endpoint Protection.app" ]]; then 
        ScriptLogging "Found incompatible version of app. Removing."
        /bin/rm -rf "/Incompatible Software"
    else
        ScriptLogging "No incompatible versions found."
    fi

    #Remove the Symantec Apps. 
    if [[ -e "/Applications/Symantec Solutions" ]]; then 
        ScriptLogging "Found Symantec app folder. Deleting."
        /bin/rm -rf "/Applications/Symantec Solutions"
    else
        ScriptLogging "Symantec app folder not found. Skipping."
    fi

    #Remove Application Support Folder>
    if [[ -e "/Library/Application Support/Symantec" ]]; then 
        ScriptLogging "Found Application Support directory. Deleting."
        /bin/rm -rf "/Library/Application Support/Symantec"
    else
        ScriptLogging "Application Support directory not found. Skipping."
    fi

    #Remove Extensions.
    kexts=('NortonForMac.kext' 'SymInternetSecurity.kext' 'SymIPS.kext' 'SymXIPS.kext')
    for k in "${kexts[@]}"; do
        kext_path="/Library/Extensions/$k"
        if [[ -e  "$kext_path" ]]; then 
            ScriptLogging "$k found. Removing"
            /bin/rm -rf "$kext_path"
        else
            ScriptLogging "$k not found. Skipping."
        fi
    done

    #Remove preference file
    if [[ -e "/Library/Preferences/com.symantec.trace.plist" ]]; then 
        ScriptLogging "Found trace preference file. Removing."
        /bin/rm -f "/Library/Preferences/com.symantec.trace.plist"
    else
        ScriptLogging "Trace preference file not found. Skipping."
    fi

    #Remove any temp files.
    if [[ -e "/private/tmp/SymXIPS.kext" ]]; then 
        ScriptLogging "Found kext in /tmp. Removing."
        /bin/rm -rf "/private/tmp/SymXIPS.kext"
    else
        ScriptLogging "No files found in /tmp. Skipping."
    fi

    #Remove binaries and libraries.
    binaries=('com.symantec.sep.SyLinkDropHelper' 'nortonscanner')
    for b in "${binaries[@]}"; do
        bin_path="/usr/local/bin/$b"
        if [[ -e  "$bin_path" ]]; then 
            ScriptLogging "Found binary $b. Removing."
        else
            ScriptLogging "Binaries not fould skipping."
        fi
    done
    
    if [[ -e "/usr/local/lib/libecomldor.dylib" ]]; then 
        ScriptLogging "Removing library."
        /bin/rm -f "/usr/local/lib/libecomldor.dylib"
    else
        ScriptLogging "Library not found. Skipping."
    fi

    #Remove conf files.
    if [[ -e "/private/etc/symantec" ]]; then 
        ScriptLogging "Found conf directory. Removing."
        /bin/rm -rf "/private/etc/symantec"
    else
        ScriptLogging "No conf file directory found. Skipping."
    fi

    #Remove services.
    if [[ -e "/Library/Services/Symantec Service.service" ]]; then 
        ScriptLogging "Found Symantec Service. Removing."
        /bin/rm -rf "/Library/Services/Symantec Service.service"
    else
        ScriptLogging "Symantec Service not found. Skipping."
    fi

    #Remove Logs.
    Logs=("$(/usr/bin/find -x "/Library/Logs" -name "Sym*")")
    if [[ -n "${Logs[*]}" ]]; then 
        ScriptLogging "Found logs. Removing."
        for l in "${Logs[@]}"; do
        /bin/rm -rf "$l"
        ScriptLogging "Removed $l"
        done
    else
        ScriptLogging "No logs found. Skipping."
    fi

    #Remove package receipts
    pkg_receipts=("$(/usr/sbin/pkgutil --pkgs="com.symantec*")")
    if [[ -n "${pkg_receipts[*]}" ]]; then 
        ScriptLogging "Found package receipts. Removing."
        for p in "${pkg_receipts[@]}"; do
            /usr/sbin/pkgutil --forget "$p"
            ScriptLogging "Removed $p"
        done
    else
        ScriptLogging "No receipts found. Skipping."
    fi
}


main()
{
    
    ScriptLogging "-----Start-----"
    removeLaunchDaemons
    removeFiles
    ScriptLogging "-----End-----"

}

##Execute

main
exit 0