function Get-BaselineGroup {
    <#
    .SYNOPSIS
        Gets a list of baseline groups from VUM.

    .DESCRIPTION
        Makes a call to the VC Integrity API to get a list of baseline groups.

    .PARAMETER name
        The name of the baseline group to get. Optional, if blank then all baseline groups will be retrieved.

    .INPUTS
        None.

    .OUTPUTS
        IntegrityApi.BaselineGroupManagerBaselineGroupInfo One or more baseline group objects.

    .EXAMPLE
        Get-BaselineGroup -name "Test Baseline Group"

        Get a specific baseline group

    .EXAMPLE
        Get-BaselineGroup

        Get all baseline groups on this server

    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       17/10/18     Initial version.                                       A McNair
        02       23/12/19     Tidied up synopsis and added verbose output.           A McNair
        03       30/11/22     Reworked for PowerCLI 12.7 and new API                 A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [String]$name
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


    ## Gather existing baseline groups
    $baselineGroups = @()

    Write-Verbose ("Starting scan for baseline groups.")


    $reqType = New-Object IntegrityApi.GetBaselineGroupInfoRequestType
    $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.baselineGroupManager

    for ($i=0; $i -le 100; $i++) {

        $reqType.id = $i

        try {
            $svcRefVum = New-Object IntegrityApi.GetBaselineGroupInfoRequest($reqType) -ErrorAction Stop
            $result = $vumCon.vumWebService.GetBaselineGroupInfo($svcRefVum)

            $baselineGroup  = $result.GetBaselineGroupInfoResponse1

            ## If name parameter is specified, check against this
            if ($name) {

                ## If baseline group name matches Name parameter add it and break the loop
                if ($name -eq $baselineGroup.name) {

                    $baselineGroups += $baselineGroup
                    Write-Verbose ("Added baseline group with name match.")

                    ## We found the baseline group, we can break out of the loop
                    Break

                } # if
            } # if
            else {
                ## If name parameter not specified, add everything to the results
                if ($baselineGroup) {
                    $baselineGroups += $baselineGroup
                    Write-Verbose ("Added baseline group " + $baselineGroup.name)
                } # if

            } # else

        } # try
        catch {
            throw ("Failed to query for baseline group. " + $_.Exception.message)
        } # catch

    } # for

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

    ## Return results
    return $baselineGroups

} # function