function Remove-BaselineGroup {
    <#
    .SYNOPSIS
        Removes a baseline group from a VUM instance.

    .DESCRIPTION
        Makes a call to the VC Integrity API to remove a baseline group.

    .PARAMETER name
        Name of the baseline group to remove.

    .PARAMETER removeIfAssigned
        Force removal of baseline group even if it is currently assigned to an entity.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Remove-BaselineGroup -name "Test Baseline Group"

        Remove Baseline Group Test Baseline Group. Will not remove if baseline group is currently assigned.

    .EXAMPLE
        Remove-BaselineGroup -name "Test Baseline Group" -RemoveIfAssigned

        Remove Baseline Group even if it is currently assigned to hosts.

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
        [String]$name,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [Switch]$removeIfAssigned
    )

    Write-Verbose ("[Remove-BaselineGroup]Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Verbose ("[Remove-BaselineGroup]Got VUM connection.")
    } # try
    catch {
        Write-Debug ("[Remove-BaselineGroup]Failed to connect to VUM instance.")
        throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)
    } # catch


    ## Verify that this baseline group exists
    for ($i=0; $i -le 768; $i++) {

        ## When baseline is found break out of loop to continue function
        if (($vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)).name -eq $name) {

            $baselineGroup = $vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)
            Write-Verbose ("[Remove-BaselineGroup]Found baseline group.")
            Break

        } # if

    } # for


    ## Check we have a baseline group to work with
    if (!$baselineGroup) {
        Write-Debug ("[Remove-BaselineGroup]Baseline group not found.")
        throw ("The specified baseline group was not found on this VUM instance.")
    } # if


    Write-Verbose ("[Remove-BaselineGroup]Checking baseline group assignment.")

    ## Query what hosts this baseline group is assigned to
    try {
        $assignedHosts = $vumCon.vumWebService.QueryAssignedEntityForBaselineGroup($vumCon.vumServiceContent.baselineGroupManager,$baselineGroup.key)
    } # try
    catch {
        Write-Debug ("[Remove-BaselineGroup]Failed to query assigned hosts for baseline group.")
        throw ("Failed to query hosts assigned to this baseline group. " + $_)
    } # catch


    ## Baseline group is assigned, display warnings
    if ($assignedHosts -and $removeIfAssigned) {

        Write-Warning ("-removeIfAssigned has been specified. The following entities will have this baseline group removed.")

        foreach ($assignedHost in $assignedHosts.entity) {

            ## Write warning for assigned entity
            Write-Warning ("Entity "  + $assignedHost.value)

        } # foreach

    } # if
    ## Baseline group is assigned and won't be removed. Function will return.
    elseif ($assignedHosts -and !$removeIfAssigned) {

        Write-Warning ("-removeIfAssigned has not been specified. The following entities have this baseline group assigned.")

        foreach ($assignedHost in $assignedHosts.entity) {

            ## Write warning for assigned entity
            Write-Warning ("Entity "  + $assignedHost.value)

        } # foreach

        Write-Warning ("Use the -removeIfAssigned parameter or remove this group for these entities.")
        Return

    } # elseif


    ## Remove this baseline group. Either warning has been displayed or function has returned.
    try {
        ## Apply shouldProcess
        if ($PSCmdlet.ShouldProcess($name)) {

            $vumCon.vumWebService.DeleteBaselineGroup($vumCon.vumServiceContent.baselineGroupManager, $baselineGroup.key)
        } # if

        Write-Verbose ("[Remove-BaselineGroup]Baseline group removed.")
    } # try
    catch {
        Write-Debug ("[Remove-BaselineGroup]Could not remove baseline group.")
        throw ("Failed to remove the specified baseline group. " + $_)
    } # catch


    ## Logoff session
    try {
        $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)
        Write-Verbose ("[Remove-BaselineGroup]Disconnected from VUM API.")
    } # try
    catch {
        Write-Warning ("[Remove-BaselineGroup]Failed to disconnect from VUM API.")
    } # catch


    Write-Verbose ("[Attach-BaselineGroup]Function completed.")

} # function