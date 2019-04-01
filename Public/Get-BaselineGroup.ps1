function Get-BaselineGroup {
    <#
    .SYNOPSIS
        Gets a list of baseline groups.
    .DESCRIPTION
        This function is part of a module that addresses gaps in the VUM PowerCLI CMDlets.
        The VCIntegrity private API is used.
        This function will get Baseline Groups from a VUM server.
        At present this is done in a less than optimal way. 
        We iterate through all baseline group ID's from 0 to 100 and check for the presence of a baseline group.
        As the VCIntegrity API is undocumented this is the only known method.
    .EXAMPLE
        Get-BaselineGroup -name "Test Baseline Group"

        Get a specific baseline group
    .EXAMPLE
        Get-BaselineGroup

        Get all baseline groups on this server
    .NOTES
        01       17/10/18     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [String]$Name
    )

    Write-Debug ("[Get-BaselineGroup]Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Debug ("[Remove-BaselineGroup]Got VUM connection.")
    } # try
    catch {
        Write-Debug ("[Remove-BaselineGroup]Failed to connect to VUM instance.")
        throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)  
    } # catch


    ## Gather existing baseline groups
    $BaselineGroups = @()
    $BaseLineGroupInfo = New-Object IntegrityApi.BaselineGroupManagerBaselineGroupInfo

    Write-Debug ("[Get-BaselineGroup]Starting scan for baseline groups.")

    for ($i=0; $i -le 100; $i++) {
        
        if ($vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)) {

            $BaselineGroup = $vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)

            Write-Debug ("[Get-BaselineGroup]Got baseline group.")

            ## If name parameter is specified, check against this
            if ($name) {

                ## If baseline group name matches Name parameter add it and break the loop
                if ($Name -eq $BaselineGroup.name) {

                    $BaselineGroups += $BaselineGroup
                    Write-Debug ("[Get-BaselineGroup]Added baseline group with name match.")

                    ## We found the baseline group, we can break out of the loop
                    Break

                } # if
            } # if
            else {
                ## If name parameter not specified, add everything to the results
                $BaselineGroups += $BaselineGroup
                Write-Debug ("[Get-BaselineGroup]Added baseline group.")
            } # else

        } # if

    } # for


    ## Logoff session
    $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)

    Write-Debug ("[Get-BaselineGroup]Function complete.")
    return $BaselineGroups

} # function