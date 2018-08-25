#!/usr/bin/env python

"""Template for reading values from a .plist. Can be used any plist or for an app."""

import os
import CoreFoundation

plist = '/path/to/plist'

if os.path.exists(plist):
    """Substitute key (someKey) and bundle identifier (tld.company.app) as necessary."""
    value = CoreFoundation.CFPreferencesCopyAppValue("someKey", "tld.company.app") 
print '<results>%s</results>' % value
