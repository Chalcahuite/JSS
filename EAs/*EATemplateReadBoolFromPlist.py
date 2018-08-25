#!/usr/bin/env python

"""EA Template for reading boolean value from a plist."""

import os
import CoreFoundation

plist = '/path/to/plist'

if os.path.exists(plist):
    """Substitute key (someKey) and bundle identifier (tld.company.app) as necessary."""
    value = CoreFoundation.CFPreferencesCopyAppValue("someKey", "tld.company.app")
    if value is None:
        print '<results>False</results>'
    else:
        print '<results>%s</results>' % value
