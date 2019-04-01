function Remove-BaselineFromGroup {
    <#
    .SYNOPSIS
        Removes a baseline from a baseline group.
    .DESCRIPTION
        This function is part of a module that addresses gaps in the VUM PowerCLI CMDlets.
        The VCItegrity private API is used.
        This function will remove a Baseline to a BaselineGroup
    .EXAMPLE
        Remove-BaselineFromGroup -BaselineGroupName "Host Patches" -Baseline "August Baseline"

        Removes a baseline called August Baseline to a baseline group Host Patches.
    .NOTES
        01       08/11/18     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$BaselineGroupName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$BaselineName
    )

    Write-Debug ("[Remove-BaselineFromGroup]Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Debug ("[Remove-BaselineGroup]Got VUM connection.")
    } # try
    catch {
        Write-Debug ("[Remove-BaselineGroup]Failed to connect to VUM instance.")
        throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)  
    } # catch
 

    ## Verify that the baseline group exists
    $BaseLineGroupInfo = New-Object IntegrityApi.BaselineGroupManagerBaselineGroupInfo

    for ($i=0; $i -le 100; $i++) {
        
        ## When baseline is found break out of loop to continue function
        if (($vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)).name -eq $BaselineGroupName) {

            $BaselineGroup = $vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)
            Write-Debug ("[Remove-BaselineFromGroup]Found baseline group.")
            Break    

        } # if

    } # for


    ## Check we have a baseline group to work with
    if (!$BaselineGroup) {
        Write-Debug ("[Remove-BaselineFromGroup]Baseline group not found.")
        throw ("The specified baseline group was not found on this VUM instance.")  
    } # if


    ## Check specified baseline exists
    try {
        $Baseline = Get-Baseline -Name $BaselineName -ErrorAction Stop
    } # try
    catch {
        Write-Debug ("[Remove-BaselineFromGroup]Failed to get baseline.")
        throw ("Failed to get baseline. " + $_)  
    } # catch


    ## Get baselines already attached to this group
    ## VUM for whatever reason has a problem with Powershell arrays, so we need a .net one
    $ArrayList = New-Object System.Collections.ArrayList


    ## Add each item into out .net array
    foreach ($BaselineItem in $BaselineGroup.baseline) {

        [void]$ArrayList.Add($BaselineItem)

    } # foreach

    Write-Debug ("[Remove-BaselineFromGroup]Acquired list of existing baselines.")


    ## Verify that the baseline we are adding has this baseline assigned
    if ($ArrayList -notcontains $Baseline.Id) {

        Write-Debug ("[Remove-BaselineFromGroup]Baseline does not exist in group.")
        throw ("This baseline does not exist in the baseline group.")

    } # if
    else {

        ## Add specified baseline ID to array
        [void]$ArrayList.Remove($Baseline.Id)
        Write-Debug ("[Remove-BaselineFromGroup]Added baseline.")
    } # else


    ## Create new baseline group spec
    $BaselineGroupUpdate = New-Object IntegrityApi.BaselineGroupManagerBaselineGroupInfo
    Write-Debug ("[Remove-BaselineFromGroup]Created baseline group update object.")

    ## Set baseline group spec properties
    $BaselineGroupUpdate.Key = $BaselineGroup.Key
    $BaselineGroupUpdate.versionNumber = $BaselineGroup.versionNumber
    $BaselineGroupUpdate.lastUpdateTimeSpecified = $true
    $BaselineGroupUpdate.lastUpdateTime = Get-Date
    $BaselineGroupUpdate.name = $BaselineGroup.name
    $BaselineGroupUpdate.targetType = "HOST"
    $BaselineGroupUpdate.baseline = $ArrayList
    $BaselineGroupUpdate.description = $BaselineGroup.Description
    Write-Debug ("[Remove-BaselineFromGroup]Set baseline group update properties.")


    ## Apply update to baseline group
    try {
        $vumCon.vumWebService.SetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$BaselineGroupUpdate)
        Write-Debug ("[Remove-BaselineFromGroup]Applied update to baseline group.")
    } # try
    catch {
        Write-Debug ("[Remove-BaselineFromGroup]Failed to apply update to group.")
        throw ("Failed to apply update to group. " + $_)
    } # catch


    ## Logoff session
    $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)

} # function