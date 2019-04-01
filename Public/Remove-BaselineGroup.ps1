function Remove-BaselineGroup {
    <#
    .SYNOPSIS
        This function removes a baseline group from a VUM instance.
    .DESCRIPTION
        This function is part of a module that addresses gaps in the VUM PowerCLI CMDlets.
        The VCItegrity private API is used.
        This function will remove a Baseline Group from the specified VUM instance.
    .EXAMPLE
        Remove-BaselineGroup -name "Test Baseline Group"

        Remove Baseline Group Test Baseline Group. Will not remove if baseline group is currently assigned.
    .EXAMPLE
        Remove-BaselineGroup -name "Test Baseline Group" -RemoveIfAssigned

        Remove Baseline Group even if it is currently assigned to hosts.
    .NOTES
        01       08/11/18     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$Name,
        [Switch]$RemoveIfAssigned
    )

    Write-Debug ("[Remove-BaselineGroup]Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Debug ("[Remove-BaselineGroup]Got VUM connection.")
    } # try
    catch {
        Write-Debug ("[Remove-BaselineGroup]Failed to connect to VUM instance.")
        throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)  
    } # catch

    ## Verify that this baseline exists
    $BaseLineGroupInfo = New-Object IntegrityApi.BaselineGroupManagerBaselineGroupInfo

    for ($i=0; $i -le 100; $i++) {
        
        ## When baseline is found break out of loop to continue function
        if (($vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)).name -eq $Name) {

            $BaselineGroup = $vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)
            Write-Debug ("[Remove-BaselineGroup]Found baseline group.")
            Break    

        } # if

    } # for


    ## Check we have a baseline group to work with
    if (!$BaselineGroup) {
        Write-Debug ("[Remove-BaselineGroup]Baseline group not found.")
        throw ("The specified baseline group was not found on this VUM instance.")  
    } # if


    ## If specified, check to see if this baseline group is currently assigned to hosts or clusters
    if ($RemoveIfAssigned) {

        Write-Debug ("[Remove-BaselineGroup]Checking baseline group assignment.")

        ## Query what hosts this baseline group is assigned to
        try {
            $AssignedHosts = $vumCon.vumWebService.QueryAssignedEntityForBaselineGroup($vumCon.vumServiceContent.baselineGroupManager,$BaselineGroup.key)
        } # try
        catch {
            Write-Debug ("[Remove-BaselineGroup]Failed to query assigned hosts for baseline group.")
            throw ("Failed to query hosts assigned to this baseline group. " + $_)  
        } # catch


        ## Return list of hosts with this baseline group assigned
        if ($AssignedHosts) {

            $ReturnHosts = @()

            foreach ($AssignedHost in $AssignedHosts.entity) {

                $ReturnHosts += (Get-VMHost | where {$_.ExtensionData.MoRef.value -eq $AssignedHost.value}).Name
                Write-Debug ("[Remove-BaselineGroup]Added host.")
            } # foreach


            ## Write-host used to stop output going to pipeline
            Write-Host "The following entities have this Baseline Group assigned. Use the RemoveIfAssigned switch to force removal."


            ## Return objects to pipeline
            Write-Debug ("[Remove-BaselineGroup]Return list of hosts.")
            return $ReturnHosts

        } # if

    } # if


    ## Remove this baseline group
    try {
        $vumCon.vumWebService.DeleteBaselineGroup($vumCon.vumServiceContent.baselineGroupManager, $BaselineGroup.key)
        Write-Debug ("[Remove-BaselineGroup]Baseline group removed.")
    } # try
    catch {
        Write-Debug ("[Remove-BaselineGroup]Could not remove baseline group.")
        throw ("Failed to remove the specified baseline group. " + $_)  
    } # catch


    ## Logoff session
    $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)

} # function