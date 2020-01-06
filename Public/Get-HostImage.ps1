function Get-HostImage {
    <#
    .SYNOPSIS
        Get a list of ESXi images.

    .DESCRIPTION
        Makes a call to the VC Integrity API to get a list of ESXi images.

    .INPUTS
        None.

    .OUTPUTS
        IntegrityApi.UpgradeProductManagerUpgradeProduct One or more VUM ESXi images.

    .EXAMPLE
        Get-HostImage

        Return a list of all ESXi images on this VUM server.

    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       13/11/18     Initial version.                                       A McNair
        02       23/12/19     Tidied up synopsis and added verbose output.           A McNair
    #>

    [CmdletBinding()]
    Param
    (
    )

    Write-Verbose ("[Get-HostImage]Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Verbose ("[Get-HostImage]Got VUM connection.")
    } # try
    catch {
        Write-Debug ("[Get-HostImage]Failed to connect to VUM instance.")
        throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)
    } # catch


    ## Get available images
    try {
        $images = $vumCon.vumWebService.QueryAvailableProducts($vumCon.vumServiceContent.upgradeProductManager, "Host")
        Write-Verbose ("[Get-HostImage]Acquired available images.")
    } # try
    catch {
        Write-Debug ("[Get-HostImage]Failed to query available images.")
        throw ("Failed to query available images. " + $_)
    } # catch


    ## Logoff session
    try {
        $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)
        Write-Verbose ("[Get-HostImage]Disconnected from VUM API.")
    } # try
    catch {
        Write-Warning ("[Get-HostImage]Failed to disconnect from VUM API.")
    } # catch


    Write-Verbose ("[Get-HostImage]Function completed.")


    ## Return images
    return $images

} # function