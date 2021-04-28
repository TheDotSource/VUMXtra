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
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [String]$name
    )

    Write-Verbose ("[Get-BaselineGroup]Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Verbose ("[Get-BaselineGroup]Got VUM connection.")
    } # try
    catch {
        Write-Debug ("[Get-BaselineGroup]Failed to connect to VUM instance.")
        throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)
    } # catch


    ## Gather existing baseline groups
    $baselineGroups = @()

    Write-Verbose ("[Get-BaselineGroup]Starting scan for baseline groups.")


    for ($i=0; $i -le 255; $i++) {

        if ($vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)) {

            $baselineGroup = $vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)

            Write-Verbose ("[Get-BaselineGroup]Got baseline group.")

            ## If name parameter is specified, check against this
            if ($name) {

                ## If baseline group name matches Name parameter add it and break the loop
                if ($Name -eq $baselineGroup.name) {

                    $baselineGroups += $baselineGroup
                    Write-Verbose ("[Get-BaselineGroup]Added baseline group with name match.")

                    ## We found the baseline group, we can break out of the loop
                    Break

                } # if
            } # if
            else {
                ## If name parameter not specified, add everything to the results
                $baselineGroups += $baselineGroup
                Write-Verbose ("[Get-BaselineGroup]Added baseline group.")
            } # else

        } # if

    } # for


    ## Logoff session
    try {
        $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)
        Write-Verbose ("[Get-BaselineGroup]Disconnected from VUM API.")
    } # try
    catch {
        Write-Warning ("[Get-BaselineGroup]Failed to disconnect from VUM API.")
    } # catch


    Write-Verbose ("[Get-BaselineGroup]Function completed.")

    ## Return results
    return $baselineGroups

} # function