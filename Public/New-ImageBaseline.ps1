function New-ImageBaseline {
    <#
    .SYNOPSIS
        Creates a new image baseline in VUM.

        With thanks to Lyuboslav Asenov @ VMWare for providing assistance with new Update Manager API.

    .DESCRIPTION
        Makes a call to the VC Integrity API to create a new VUM image baseline.

    .PARAMETER name
        The name of the new image baseline.

    .PARAMETER description
        The description of the new image baseline. Optional.

    .PARAMETER image
        The name of the image used to created the image baseline, as per the image name in the VUM console.

    .INPUTS
        None.

    .OUTPUTS
        System.Management.Automation.PSCustomObject. Object representing the new image baseline.


    .EXAMPLE
        New-ImageBaseline -Name "6.7 Upgrade" -Description "Sample" -Image "ESXi-6.7.0-20190802001-standard"

        Creates a new image baseline called "6.7 Upgrade" with description Sample using the VUM image ESXi-6.7.0-20190802001-standard

    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       13/11/18     Initial version.                                       A McNair
        02       23/12/19     Tidied up synopsis and added verbose output.           A McNair
        03       30/11/22     Reworked for PowerCLI 12.7 and new API                 A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$name,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [String]$description,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$image
    )


    Write-Verbose ("Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Verbose ("Got VUM connection.")
    } # try
    catch {
        throw ("Failed to connect to VUM instance. " + $_.Exception.Message)
    } # catch


    ## Check this image baseline doesn't exist
    if (Get-Baseline -Name $Name -ErrorAction SilentlyContinue) {
        throw ("Image baseline already exists on this VUM instance.")
    } # if


    ## Get available images
    try {
        $reqType = New-Object IntegrityApi.QueryAvailableProductsRequestType
        $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.upgradeProductManager
        $reqType.productType = "Host"

        $svcRefVum = New-Object IntegrityApi.QueryAvailableProductsRequest($reqType)

        $images = ($vumCon.vumWebService.QueryAvailableProducts($svcRefVum)).QueryAvailableProductsResponse1

        Write-Verbose ("Acquired available images.")
    } # try
    catch {
        throw ("Failed to query available images. " + $_.Exception.Message)
    } # catch


    ## Find key for specified image
    $key = ($images | Where-Object {$_.profileName -eq $image}).upgradeReleaseKey


    ## Check we have an available image
    if (!$key) {
        throw ("The specified image does not exist on this VUM instance.")
    } # if


    ## Create a image baseline specification
    Write-Verbose ("Creating image baseline spec.")
    try {
        $baselineSpec = New-Object IntegrityApi.HostUpgradeBaselineSpec -ErrorAction Stop
        $baselineSpec.attribute = New-Object IntegrityApi.BaselineAttribute -ErrorAction Stop
        $baselineSpec.name = $name
        $baselineSpec.description = $description
        $baselineSpec.attribute.targetType = "HOST"
        $baselineSpec.attribute.type = "Upgrade"
        $baselineSpec.upgradeTo = ""
        $baselineSpec.upgradeToVersion = ""
        $baselineSpec.upgradeReleaseKey = $key
        $baselineSpec.attribute.targetComponent = "HOST_GENERAL"
        $baselineSpec.attribute.extraAttribute = "Singleton"
    } # try
    catch {
        throw ("Failed to create image baseline spec. " + $_.Exception.Message)
    } # catch


    ## Create new image baseline
    try {

        ## Apply shouldProcess
        if ($PSCmdlet.ShouldProcess($name)) {

            $reqType = New-Object IntegrityApi.CreateBaselineRequestType -ErrorAction Stop
            $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.baselineManager
            $reqType.spec = $baselineSpec

            $svcRefVum = New-Object IntegrityApi.CreateBaselineRequest($reqType)

            $baselineID = ($vumCon.vumWebService.CreateBaseline($svcRefVum)).CreateBaselineResponse.returnval
        } # if

        Write-Verbose ("Image baseline created.")
    } # try
    catch {
        throw ("Failed to create image baseline. " + $_.Exception.Message)
    } # catch


    ## Generate return object
    $ibObject = [pscustomobject]@{"Name" = $name; "Description" = $description; "Id" = $baselineID}


    ## Logoff session
    try {
        $reqType = New-Object IntegrityApi.VciLogoutRequestType -ErrorAction Stop
        $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.sessionManager
        $svcRefVum = New-Object IntegrityApi.VciLogoutRequest($reqType)
        $vumCon.vumWebService.VciLogout($svcRefVum) | Out-Null

        Write-Verbose ("Disconnected from VUM API.")
    } # try
    catch {
        Write-Warning ("Failed to disconnect from VUM API.")
    } # catch


    Write-Verbose ("Function completed.")

    ## Return object
    return $ibObject

} # function