# VUMXtra

VUM module to add additional functions for managing VUM, in particular around baseline groups and content import.

# New in 1.2

Added support for HTTP locations to Import-VUMContent. This is considerably faster than VM tools file copy in most instances.

If the user PowerCLI session is configured to ignore invalid certificates, then Connect-VUM will also ignore them.


# New in 1.1

General code tidy up and improvements to comply with PS Script Analyser. As a result some CMDlet names have changed to remove the use of unapproved verbs. CMDlets function exactly the same way as previously.

Support for none self managed vCenters when using Import-VUMContent. Previously, the VCSA would need to be managing it's own virtual machine object. With the use of an additional parameter multiple VI connections can be used to allow for a none self-managed scenario. Review the Import-VUMContent help for further details and examples.
