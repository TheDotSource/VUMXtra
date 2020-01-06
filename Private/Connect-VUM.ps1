function Connect-VUM {
    <#
    .SYNOPSIS
        Private function to create connection to VUM instance.

    .DESCRIPTION
        In order to make calls to the vcIntegrity API a connection to a VUM instance is required.
        All functions within the VUMXtra module call this prior to executing any actions.
        The connection object is then used within the calling function.

        If multiple defaultVIServers exists, then the -vumVI parameter must be used to specify which to use for the VUM connection.

    .PARAMETER vumVI
        The name of the VI connection to use to connect to the VUM service. Optional if there is only a single connection.

    .INPUTS
        None.

    .OUTPUTS
        System.Management.Automation.PSCustomObject. A VUM service connection object.

    .EXAMPLE
        $vumCon = Connect-VUM

        Creates a VUM connection object using the single default vCenter connection.

    .EXAMPLE
        $vumCon = Connect-VUM -vumVI vcsa01.lab.local

        Creates a VUM connection object to vcsa01.lab.local.

    .NOTES
        01       18/03/19     Initial version.                                         A McNair
        02       23/12/19     Tidied up synopsis and added verbose output.             A McNair
                              Added parameter to specify which VI connection to use.
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [String]$vumVI
    )

    Write-Verbose ("[Connect-VUM]Function start.")


    ## Address the 3 possible conditions and set an appropriate vCenter connection
    switch ($vumVI) {

        ## Parameter was specified, set the VI connection to use
        {($_)} {
            Write-Verbose ("vumVI parameter was specified. Using vCenter " + $vumVI + " for VUM API connection.")
            $vCenterServer = $global:DefaultVIServers | where {$_.name -eq $vumVI}
        } # true

        ## Parameter not specified, but there multiple VI connections, exit as this is ambiguous.
        {(!$_) -and ($global:DefaultVIServers.count -gt 1)} {        
            throw ("Multiple vCenter connections detected, either use a single default connection, or specify the -vumVI parameter.")
        }  # false

        ## Parameter not specified, one default instance
        default {
            Write-Verbose ("Assuming connection to default vCenter.")
            $vCenterServer = $global:DefaultVIServer
        }

    } # switch


    ## Check that there is a suitable vCenter connection
    if (!$vCenterServer) {
        throw ("Not connected to vCenter or specified vCenter instance was not found in list of active connections.")
    } # if


    ## Get VUM extension
    try {
        $serviceInstance = Get-View ServiceInstance -Server $vCenterServer
        $extensionMgr = Get-View $serviceInstance.Content.ExtensionManager -Server $vCenterServer
        $vumExtension = $extensionMgr.FindExtension("com.vmware.vcIntegrity")
        Write-Verbose ("[Connect-VUM]Got VUM extension.")
    } # try
    catch {
        throw ("Error getting VUM extension. " + $_)
        Write-Debug ("[Connect-VUM]Failed to get VUM extension.")
    } # catch


    ## Ensure VUM automation module is loaded
    try {
        Get-Patch -Id 0 -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        Write-Verbose ("[Connect-VUM]Loaded VUM assemblies.")
    } # try
    catch {
        throw ("Could not load VUM assemblies. " + $_)
        Write-Debug ("[Connect-VUM]Could not load VUM assemblies.")
    } # catch


    ## Initialise VUM service
    try {
        $vumWebService = New-Object IntegrityApi.IntegrityService
        $vumUrl = $vumExtension.Server[0].Url
        $vumWebService.Url = $vumUrl
        $vumWebService.CookieContainer = New-Object System.Net.CookieContainer
        $vumWebService.Timeout = 300000
        $svcRefVum = New-Object IntegrityApi.ManagedObjectReference
        $svcRefVum.type = "VcIntegrity"
        $svcRefVum.Value = 'Integrity.VcIntegrity'
        $sessionManager = Get-View $serviceInstance.Content.SessionManager -Server $vCenterServer
        $vumServiceContent = $vumWebService.RetrieveVcIntegrityContent($svcRefVum)
        $userSession  = $vumWebService.VciLogin($vumServiceContent.sessionManager, $sessionManager.CurrentSession.UserName,  $sessionManager.CurrentSession.Key,  $sessionManager.CurrentSession.Locale)
    } # try
    catch {
        throw ("Could not initialise the VUM service. " + $_)
        Write-Debug ("[Connect-VUM]Could not initialise the VUM service.")
    } # catch

    Write-Verbose ("[Connect-VUM]Connected to VUM.")

    ## Set return object
    $vumCon  = [pscustomobject]@{"vumWebService" = $vumWebService; "vumServiceContent" = $vumServiceContent}


    ## Return connection object
    return $vumCon


} # function