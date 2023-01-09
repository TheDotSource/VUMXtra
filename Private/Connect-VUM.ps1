#Requires -PSEdition Core
#Requires -Modules @{ ModuleName="VMware.VumAutomation"; ModuleVersion="12.7" }
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
        03       28/11/22     Reworked for PowerCLI 12.7 and new API                   A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [String]$vumVI
    )

    Write-Verbose ("Function start.")


    ## Address the 3 possible conditions and set an appropriate vCenter connection
    switch ($vumVI) {

        ## Parameter was specified, set the VI connection to use
        {($_)} {
            Write-Verbose ("vumVI parameter was specified. Using vCenter " + $vumVI + " for VUM API connection.")
            $vCenterServer = $global:DefaultVIServers | Where-Object {$_.name -eq $vumVI}
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

    ## Check the PowerCLI invalid vertificate action. If set to ignore, then configure HTTP connections to ignore invlaid certs
    Write-Verbose ("Fetching PowerCLI configuration and checking certificate policy.")

    try {
        $pcliConfig = Get-PowerCLIConfiguration -ErrorAction Stop
        Write-Verbose ("Got PowerCLI configuration.")
    } # try
    catch {
        throw ("Failed to get PowerCLI configuration. " + $_.Exception.message)
    } # catch


    ## Check if we are ignoring invalid certs or not
    if (($pcliConfig | Where-Object {$_.scope -eq "session"}).invalidCertificateAction -eq "ignore") {
        Write-Verbose ("Invalid certificates will be ignored as per PowerCLI configuration.")
        $ignoreCerts = $true
    } # if
    else {
        Write-Verbose ("Invalid certificates will not be ignored as per PowerCLI configuration.")
        $ignoreCerts = $false
    } # else


    ## Get VUM extension
    Write-Verbose ("Getting VUM extension.")

    try {
        $serviceInstance = Get-View ServiceInstance -Server $vCenterServer
        Write-Verbose ("Got VUM extension.")
    } # try
    catch {
        throw ("Error getting VUM extension. " + $_.Exception.message)
    } # catch


    ## Ensure VUM automation module is loaded
    Write-Verbose ("Loading VUM assemblies.")

    try {
        Get-Patch -Id 0 -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        Write-Verbose ("Loaded VUM assemblies.")
    } # try
    catch {
        throw ("Could not load VUM assemblies. " + $_.Exception.Message)
    } # catch


    ## Initialise VUM service
    Write-Verbose ("Initialising VUM service.")

    try {
        $sessionManager = Get-View $serviceInstance.Content.SessionManager -Server $vCenterServer
        Write-Verbose ("VUM service initialised.")
    } # try
    catch {
        throw ("Could not initialise the VUM service. " + $_)
    } # catch


    ## Add type to workaround generic method call
    Write-Verbose ("Adding type and creating WCF client.")

    try {
        if (!([System.Management.Automation.PSTypeName]'IntegrityApiClientFactory').Type) {
            Add-Type @"
            public class IntegrityApiClientFactory {
                public static object Create(string address, bool ignoreCert) {
                    var factory = new VMware.Binding.Wcf.ClientFactory();
                    factory.Url = address;
                    factory.CookieContainer = new System.Net.CookieContainer();
                    factory.IgnoreServerCertificateErrors = ignoreCert;
                    return factory.CreateWcfClient<IntegrityApi.IntegrityPortType>();
                }
            }
"@ -ReferencedAssemblies VMware.Binding.Wcf,IntegrityService,System.ServiceModel,System.Net.Primitives -IgnoreWarnings -ErrorAction Stop -WarningAction SilentlyContinue
    } # if

        ## Create WCF client
        $wcfClient = [IntegrityApiClientFactory]::Create("https://" + $vCenterServer.Name + ":8084/vci/sdk", $ignoreCerts)
        $vumWebService = $wcfClient.client

        Write-Verbose ("WCF client created.")
    } # try
    catch {
        throw ("Failed to create WCF client. " + $_.Exception.Message)
    } # catch


    ## Create request
    try {
        $mo = New-Object IntegrityApi.ManagedObjectReference -ErrorAction Stop
        $mo.type = "VcIntegrity"
        $mo.value = "Integrity.VcIntegrity"

        $reqType = New-Object IntegrityApi.RetrieveVcIntegrityContentRequestType -ErrorAction Stop
        $reqType._this = $mo

        $svcRefVum = New-Object IntegrityApi.RetrieveVcIntegrityContentRequest($reqType) -ErrorAction Stop
    } # try
    catch {
        throw ("Failed to create request. " + $_.Exception.Message)
    } # catch


    ## Call web service operation
    $vumServiceContent = $vumWebService.RetrieveVcIntegrityContent($svcRefVum)


    ## Login to VUM
    Write-Verbose ("Connecting to VUM.")
    try {
        $reqType = New-Object IntegrityApi.VciLoginRequestType -ErrorAction Stop
        $reqType.userName = $sessionManager.CurrentSession.UserName
        $reqType.sessionId = $sessionManager.CurrentSession.Key
        $reqType.locale = $sessionManager.CurrentSession.Locale
        $reqType._this = $vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.sessionManager

        $svcRefVum = New-Object IntegrityApi.VciLoginRequest($reqType) -ErrorAction Stop

        $vumWebService.VciLogin($svcRefVum)
    } # try
    catch {
        throw ("Failed to connect to VUM. " + $_.Exception.Message)
    } # catch


    Write-Verbose ("Connected to VUM.")

    ## Set return object
    $vumCon  = [pscustomobject]@{"vumWebService" = $vumWebService; "vumServiceContent" = $vumServiceContent}


    ## Return connection object
    return $vumCon


} # function