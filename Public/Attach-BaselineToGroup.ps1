function Attach-BaselineToGroup {
    <#
    .SYNOPSIS
        Attaches an existing Baseline to a BaselineGroup.
    .DESCRIPTION
        This function is part of a module that addresses gaps in the VUM PowerCLI CMDlets.
        The VCItegrity private API is used.
        This function will attach an existing Baseline to a BaselineGroup.
    .EXAMPLE
        Attach-BaselineToGroup -BaselineGroupName "Host Patches" -Baseline "August Baseline"

        Attaches a baseline called August Baseline to a baseline group Host Patches.
    .NOTES
        01       13/11/18     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$BaselineGroupName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$BaselineName
    )

    Write-Debug ("[Attach-BaselineToGroup]Function start.")

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
            Write-Debug ("[Attach-BaselineToGroup]Found baseline group.")
            Break    

        } # if

    } # for


    ## Check we have a baseline group to work with
    if (!$BaselineGroup) {
        Write-Debug ("[Attach-BaselineToGroup]Baseline group not found.")
        throw ("The specified baseline group was not found on this VUM instance.")  
    } # if


    ## Check specified baseline exists
    try {
        $Baseline = Get-Baseline -Name $BaselineName -ErrorAction Stop
    } # try
    catch {
        Write-Debug ("[Attach-BaselineToGroup]Failed to get baseline.")
        throw ("Failed to get baseline. " + $_)  
    } # catch


    ## Get baselines already attached to this group
    ## VUM for whatever reason has a problem with Powershell arrays, so we need a .net one
    $ArrayList = New-Object System.Collections.ArrayList


    ## Add each item into out .net array
    foreach ($BaselineItem in $BaselineGroup.baseline) {

        [void]$ArrayList.Add($BaselineItem)

    } # foreach

    Write-Debug ("[Attach-BaselineToGroup]Acquired list of existing baselines.")


    ## If this baseline already exists in this group then return from the function, no more work to do
    if ($ArrayList -contains $Baseline.Id) {

        Write-Debug ("[Attach-BaselineToGroup]Baseline already exists in group.")
        return
    } # if
    else {

        ## Add specified baseline ID to array
        [void]$ArrayList.Add($Baseline.Id)
        Write-Debug ("[Attach-BaselineToGroup]Added baseline.")
    } # else


    ## Create new baseline group spec
    $BaselineGroupUpdate = New-Object IntegrityApi.BaselineGroupManagerBaselineGroupInfo
    Write-Debug ("[Attach-BaselineToGroup]Created baseline group update object.")

    ## Set baseline group spec properties
    $BaselineGroupUpdate.Key = $BaselineGroup.Key
    $BaselineGroupUpdate.versionNumber = $BaselineGroup.versionNumber
    $BaselineGroupUpdate.lastUpdateTimeSpecified = $true
    $BaselineGroupUpdate.lastUpdateTime = Get-Date
    $BaselineGroupUpdate.name = $BaselineGroup.name
    $BaselineGroupUpdate.targetType = "HOST"
    $BaselineGroupUpdate.baseline = $ArrayList
    $BaselineGroupUpdate.description = $BaselineGroup.Description
    Write-Debug ("[Attach-BaselineToGroup]Set baseline group update properties.")


    ## Apply update to baseline group
    try {
        $vumCon.vumWebService.SetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$BaselineGroupUpdate) | Out-Null
        Write-Debug ("[Attach-BaselineToGroup]Applied update to baseline group.")
    } # try
    catch {
        Write-Debug ("[Attach-BaselineToGroup]Failed to apply update to group.")
        throw ("Failed to apply update to group. " + $_)
    } # catch


    ## Logoff session
    $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)

} # function