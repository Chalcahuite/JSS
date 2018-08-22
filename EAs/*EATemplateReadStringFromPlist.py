#!/usr/bin/env python

''' Template for reading values from a .plist. Can be used for the CIS plist or for an app '''

import os
import CoreFoundation

plist = '/Library/Preferences/com.comcast.cable.cis.plist'

if os.path.exists(plist):
    ''' Substitute key (OUPath) and bundle identifier (com.comcast.cable.cis) as necessary'''
    value = CoreFoundation.CFPreferencesCopyAppValue("OUPath", "com.comcast.cable.cis") 
print '<results>%s</results>' % value
