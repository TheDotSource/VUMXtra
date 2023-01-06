# VUMXtra #

VUM module to add additional functions for managing VUM, in particular around baseline groups and content import.

## New in 1.3 ##
A number of significant changes are present in this release:

VUMXtra now requires PowerCLI 12.7 or above and PowerShell Core. VMWare have ported the Update Manager module to PowerCLI Core which has resulted in significant changes to how the VUM API is called. All functions in this module have been reworked for the new API and are not backwards compatible. As such, support for PowerShell for Windows and PowerCLI versions prior to 12.7 has been dropped. If this is still a requirement you have, please continue to use VUMXtra 1.2.

Dropped support for Windows hosted vCenters. Most notably the Import-VUMContent function will no longer import to a Windows hosted vCenter. Most likely other functions will still work, but have not been tested. If this is a requirement, please continue to use VUMXtra 1.2.

Added functions to configure host remediation settings. This can be passed to Update-EntityBaselineGroup for remediation runtime settings, or applied as VUM default remediation settings. This includes enabling host Quick Boot where the hardware is supported.

Added support for cluster level remediation to Update-EntityBaselineGroup.

Many thanks to Lyuboslav Asenov @ VMWare for helping me with the new Update Manager API. Without his help this would not have been possible.


## New in 1.2 ##

Added support for HTTP locations to Import-VUMContent. This is considerably faster than VM tools file copy in most instances.

If the user PowerCLI session is configured to ignore invalid certificates, then Connect-VUM will also ignore them.


## New in 1.1 ##

General code tidy up and improvements to comply with PS Script Analyser. As a result some CMDlet names have changed to remove the use of unapproved verbs. CMDlets function exactly the same way as previously.

Support for none self managed vCenters when using Import-VUMContent. Previously, the VCSA would need to be managing it's own virtual machine object. With the use of an additional parameter multiple VI connections can be used to allow for a none self-managed scenario. Review the Import-VUMContent help for further details and examples.
