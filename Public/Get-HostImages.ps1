function Get-HostImages {
    <#
    .SYNOPSIS
        Get a list of ESXi images.
    .DESCRIPTION
        This function is part of a module that addresses gaps in the VUM PowerCLI CMDlets.
        The VCItegrity private API is used.
        This function returns a list of ESXi images on a VUM instance.
    .EXAMPLE
        Get-HostImages

        Return a list of all ESXi images on this VUM server.
    .NOTES
        01       13/11/18     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param
    (
    )

    Write-Debug ("[Get-HostImages]Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Debug ("[Remove-BaselineGroup]Got VUM connection.")
    } # try
    catch {
        Write-Debug ("[Remove-BaselineGroup]Failed to connect to VUM instance.")
        throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)  
    } # catch


    ## Get available images
    try {
        $Images = $vumCon.vumWebService.QueryAvailableProducts($vumCon.vumServiceContent.upgradeProductManager, "Host")
        Write-Debug ("[New-ImageBaseline]Acquired available images.")
    } # try
    catch {
        Write-Debug ("[New-ImageBaseline]Failed to query available images.")
        throw ("Failed to query available images. " + $_)
    } # catch


    ## Logoff session
    $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)


    ## Return images
    return $Images

} # function