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
        03       30/11/22     Reworked for PowerCLI 12.7 and new API                 A McNair
    #>

    [CmdletBinding()]
    Param
    (
    )

    Write-Verbose ("Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Verbose ("Got VUM connection.")
    } # try
    catch {
        throw ("Failed to connect to VUM instance. The CMDlet returned " + $_.Exception.Message)
    } # catch


    ## Get available images
    try {
        $reqType = New-Object IntegrityApi.QueryAvailableProductsRequestType -ErrorAction Stop
        $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.upgradeProductManager
        $reqType.productType = "Host"

        $svcRefVum = New-Object IntegrityApi.QueryAvailableProductsRequest($reqType)
        $images = ($vumCon.vumWebService.QueryAvailableProducts($svcRefVum)).QueryAvailableProductsResponse1

        Write-Verbose ("Acquired available images.")
    } # try
    catch {
        throw ("Failed to query available images. " + $_.Exception.Message)
    } # catch


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


    ## Return images
    return $images

} # function