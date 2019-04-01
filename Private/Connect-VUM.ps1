function Connect-VUM {
    <#
    .SYNOPSIS
        Creates a VUM connection object for the current vCenter connection.
    .DESCRIPTION
        In order to make calls to the vcIntegrity API a connection to a VUM instance is required.
        All functions within the VUM extra module call this prior to executing any actions.
        The connection object is then used within the calling function.
    .EXAMPLE
        $vumCon = Connect-VUM

        Creates a VUM connection object.
    .NOTES
        01       18/03/19     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param
    (
    )

    Write-Debug ("[Connect-VUM]Function start.")


    ## Get vCenter connection
    $vCenterServer = $global:DefaultVIServer

    if (!$vCenterServer) {
        throw ("Not connected to vCenter.")
    } 


    ## Get VUM extension
    try {
        $serviceInstance = Get-View ServiceInstance -Server $vCenterServer
        $extensionMgr = Get-View $serviceInstance.Content.ExtensionManager -Server $vCenterServer
        $vumExtension = $extensionMgr.FindExtension("com.vmware.vcIntegrity")
        Write-Debug ("[Connect-VUM]Got VUM extension.")
    } # try
    catch {
        throw ("Error getting VUM extension. " + $_)
        Write-Debug ("[Connect-VUM]Failed to get VUM extension.")
    } # catch


    ## Execute VUM cmdlet to load assemblies
    try {
        Get-Patch -Id 0 -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        Write-Debug ("[Connect-VUM]Loaded VUM assemblies.")
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

    Write-Debug ("[Connect-VUM]Connected to VUM.")

    ## Set return object
    $vumCon  = New-Object -TypeName PSObject -Property @{"vumWebService" = $vumWebService; "vumServiceContent" = $vumServiceContent}

    Write-Debug ("[Connect-VUM]Return completed object.")
    return $vumCon

} # function