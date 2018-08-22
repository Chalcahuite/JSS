#!/usr/bin/env python

import os
import CoreFoundation

''' EA Template for reading boolean value from a .plist '''

plist = '/Library/Preferences/com.comcast.cable.cis.plist'

if os.path.exists(plist):
    ''' Substitute key (FirstBootRun) and bundle identifier (com.comcast.cable.cis) as necessary'''
    value = CoreFoundation.CFPreferencesCopyAppValue("FirstBootRun", "com.comcast.cable.cis")
    if value is None:
        print '<results>False</results>'
    else:
        print '<results>%s</results>' % value

