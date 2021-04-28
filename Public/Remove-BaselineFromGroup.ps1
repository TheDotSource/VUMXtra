function Remove-BaselineFromGroup {
    <#
    .SYNOPSIS
        Removes a baseline from a VUM baseline group.

    .DESCRIPTION
        Makes a call to the VC Integrity API to remove a baseline from a VUM baseline group.

    .PARAMETER baselineGroupName
        The target baseline group to remove the baseline from.

    .PARAMETER baselineName
        The baseline to remove from the baseline group.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Remove-BaselineFromGroup -baselineGroupName "Host Patches" -baseline "August Baseline"

        Removes a baseline called August Baseline from baseline group Host Patches.

    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       08/11/18     Initial version.                                      A McNair
        02       23/12/19     Tidied up synopsis and added verbose output.          A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Medium")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$baselineGroupName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$baselineName
    )

    Write-Verbose ("[Remove-BaselineFromGroup]Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction Stop
        Write-Verbose ("[Remove-BaselineFromGroup]Got VUM connection.")
    } # try
    catch {
        Write-Debug ("[Remove-BaselineFromGroup]Failed to connect to VUM instance.")
        throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)
    } # catch


    ## Verify that the baseline group exists
    for ($i=0; $i -le 255; $i++) {

        ## When baseline is found break out of loop to continue function
        if (($vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)).name -eq $baselineGroupName) {

            $baselineGroup = $vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)
            Write-Verbose ("[Remove-BaselineFromGroup]Found baseline group.")
            Break

        } # if

    } # for


    ## Check we have a baseline group to work with
    if (!$baselineGroup) {
        Write-Debug ("[Remove-BaselineFromGroup]Baseline group not found.")
        throw ("The specified baseline group was not found on this VUM instance.")
    } # if


    ## Check specified baseline exists
    try {
        $baseline = Get-Baseline -Name $baselineName -ErrorAction Stop
    } # try
    catch {
        Write-Debug ("[Remove-BaselineFromGroup]Failed to get baseline.")
        throw ("Failed to get baseline. " + $_)
    } # catch


    ## Get baselines already attached to this group
    ## VUM for whatever reason has a problem with Powershell arrays, so we need a .net one
    $arrayList = New-Object System.Collections.ArrayList


    ## Add each item into out .net array
    foreach ($baselineItem in $baselineGroup.baseline) {

        [void]$arrayList.Add($baselineItem)

    } # foreach

    Write-Verbose ("[Remove-BaselineFromGroup]Acquired list of existing baselines.")


    ## Verify that the baseline we are adding has this baseline assigned
    if ($arrayList -notcontains $baseline.Id) {

        Write-Warning ("Baseline does not exist in target baseline group. No action has been taken.")
        return

    } # if
    else {

        ## Add specified baseline ID to array
        [void]$ArrayList.Remove($Baseline.Id)
        Write-Verbose ("[Remove-BaselineFromGroup]Revmoed baseline from baseline group.")

    } # else


    ## Create new baseline group spec
    $baselineGroupUpdate = New-Object IntegrityApi.BaselineGroupManagerBaselineGroupInfo
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

        ## Apply shouldProcess
        if ($PSCmdlet.ShouldProcess($baselineName + " in baseline group " + $baselineGroupName)) {

            $vumCon.vumWebService.SetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$BaselineGroupUpdate)
        } # if

        Write-Verbose ("[Remove-BaselineFromGroup]Applied update to baseline group.")
    } # try
    catch {
        Write-Debug ("[Remove-BaselineFromGroup]Failed to apply update to group.")
        throw ("Failed to apply update to group. " + $_)
    } # catch


    ## Logoff session
    try {
        $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)
        Write-Verbose ("[Remove-BaselineFromGroup]Disconnected from VUM API.")
    } # try
    catch {
        Write-Warning ("[Remove-BaselineFromGroup]Failed to disconnect from VUM API.")
    } # catch


    Write-Verbose ("[Remove-BaselineFromGroup]Function completed.")

} # function