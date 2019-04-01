function New-ImageBaseline {
    <#
    .SYNOPSIS
        Creates a new image baseline.
    .DESCRIPTION
        This function is part of a module that addresses gaps in the VUM PowerCLI CMDlets.
        The VCItegrity private API is used.
        This function will create a new image baseline on the specified VUM instance.
        The image must have been previously imported to VUM.
    .EXAMPLE
        New-ImageBaseline -Name "Test Image Baseline" -Description "Sample" -Image "ESXi 6.5 Standard"

        Creates a new image baseline called Test Image Baseline with description Sample using image ESXi 6.5 Standard
    .NOTES
        01       13/11/18     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$Name,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [String]$Description,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$Image
    )


    Write-Debug ("[New-ImageBaseline]Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Debug ("[Remove-BaselineGroup]Got VUM connection.")
    } # try
    catch {
        Write-Debug ("[Remove-BaselineGroup]Failed to connect to VUM instance.")
        throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)  
    } # catch


    ## Check this image baseline doesn't exist
    if (Get-Baseline -Name $Name -ErrorAction SilentlyContinue) {
        Write-Debug ("[New-ImageBaseline]Image baseline exists.")
        throw ("Image baseline already exists on this VUM instance.")
    } # if


    ## Get available images
    try {
        $Images = $vumCon.vumWebService.QueryAvailableProducts($vumCon.vumServiceContent.upgradeProductManager, "Host")
        Write-Debug ("[New-ImageBaseline]Acquired available images.")
    } # try
    catch {
        Write-Debug ("[New-ImageBaseline]Failed to query available images.")
        throw ("Failed to query available images. " + $_)
    } # catch


    ## Find key for specified image
    $Key = ($Images | where {$_.profileName -eq $Image}).upgradeReleaseKey

    ## Check we have an available image
    if (!$Key) {
        Write-Debug ("[New-ImageBaseline]Failed to find specified image.")
        throw ("The specified image does not exist on this VUM instance.")
    } # if


    ## Create a image baseline specification
    $baselineSpec = New-Object IntegrityApi.HostUpgradeBaselineSpec	
    $baselineSpec.attribute = New-Object IntegrityApi.BaselineAttribute
    $baselineSpec.name = $Name
    $baselineSpec.description = $Description
    $baselineSpec.attribute.targetType = "HOST"
    $baselineSpec.attribute.type = "Upgrade"
    $baselineSpec.upgradeTo = ""
    $baselineSpec.upgradeToVersion = ""
    $baselineSpec.upgradeReleaseKey = $Key
    $baselineSpec.attribute.targetComponent = "HOST_GENERAL"
    $baselineSpec.attribute.extraAttribute = "Singleton"


    ## Create new image baseline
    try {
        $baselineID = $vumCon.vumWebService.CreateBaseline($vumCon.vumServiceContent.baselineManager, $baselineSpec)
        Write-Debug ("[New-ImageBaseline]Image baseline created.")
    } # try
    catch {
        Write-Debug ("[New-ImageBaseline]Failed to create image baseline.")
        throw ("Failed to create image baseline. " + $_)
    } # catch


    ## Generate return object
    $IBObject = @{"Name" = $Name; "Description" = $Description; "Id" = $baselineID}


    ## Logoff session
    $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)


    return $IBObject

} # function