function New-ImageBaseline {
    <#
    .SYNOPSIS
        Creates a new image baseline in VUM.

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


    Write-Verbose ("[New-ImageBaseline]Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Verbose ("[New-ImageBaseline]Got VUM connection.")
    } # try
    catch {
        Write-Debug ("[New-ImageBaseline]Failed to connect to VUM instance.")
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
        Write-Verbose ("[New-ImageBaseline]Acquired available images.")
    } # try
    catch {
        Write-Debug ("[New-ImageBaseline]Failed to query available images.")
        throw ("Failed to query available images. " + $_)
    } # catch


    ## Find key for specified image
    $Key = ($Images | Where-Object {$_.profileName -eq $Image}).upgradeReleaseKey

    ## Check we have an available image
    if (!$key) {
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

        ## Apply shouldProcess
        if ($PSCmdlet.ShouldProcess($name)) {

            $baselineID = $vumCon.vumWebService.CreateBaseline($vumCon.vumServiceContent.baselineManager, $baselineSpec)
        } # if

        Write-Verbose ("[New-ImageBaseline]Image baseline created.")
    } # try
    catch {
        Write-Debug ("[New-ImageBaseline]Failed to create image baseline.")
        throw ("Failed to create image baseline. " + $_)
    } # catch


    ## Generate return object
    $ibObject = [pscustomobject]@{"Name" = $Name; "Description" = $Description; "Id" = $baselineID}


    ## Logoff session
    try {
        $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)
        Write-Verbose ("[New-ImageBaseline]Disconnected from VUM API.")
    } # try
    catch {
        Write-Warning ("[New-ImageBaseline]Failed to disconnect from VUM API.")
    } # catch


    Write-Verbose ("[New-ImageBaseline]Function completed.")


    ## Return object
    return $IBObject


} # function