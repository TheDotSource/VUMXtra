function Remove-BaselineGroup {
    <#
    .SYNOPSIS
        Removes a baseline group from a VUM instance.

        With thanks to Lyuboslav Asenov @ VMWare for providing assistance with new Update Manager API.

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
        03       30/11/22     Reworked for PowerCLI 12.7 and new API                A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Medium")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$name,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [Switch]$removeIfAssigned
    )

    Write-Verbose ("Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Verbose ("Got VUM connection.")
    } # try
    catch {
        throw ("Failed to connect to VUM instance. " + $_.Exception.Message)
    } # catch


    $reqType = New-Object IntegrityApi.GetBaselineGroupInfoRequestType
    $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.baselineGroupManager

    ## Verify that the baseline group exists
    for ($i=0; $i -le 100; $i++) {

        $reqType.id = $i

        try {
            $svcRefVum = New-Object IntegrityApi.GetBaselineGroupInfoRequest($reqType) -ErrorAction Stop
            $result = $vumCon.vumWebService.GetBaselineGroupInfo($svcRefVum)

            ## When baseline is found break out of loop to continue function
            if (($result.GetBaselineGroupInfoResponse1).name -eq $name) {

                $baselineGroup  = $result.GetBaselineGroupInfoResponse1
                Break

            } # if
        } # try
        catch {
            throw ("Failed to query for baseline group. " + $_.Exception.message)
        } # catch

    } # for


    ## Check we have a baseline group to work with
    if (!$baselineGroup) {
        throw ("The specified baseline group was not found on this VUM instance.")
    } # if
    else {
        Write-Verbose ("Baseline group " + $baselineGroup.name + " was found, ID " + $baselineGroup.key)
    } # else


    Write-Verbose ("Checking baseline group assignment.")

    ## Query what hosts this baseline group is assigned to
    try {
        $reqType = New-Object IntegrityApi.QueryAssignedEntityForBaselineGroupRequestType -ErrorAction Stop
        $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.baselineGroupManager
        $reqType.group = $baselineGroup.key

        $svcRefVum = New-Object IntegrityApi.QueryAssignedEntityForBaselineGroupRequest($reqType) -ErrorAction Stop

        $assignedHosts = ($vumCon.vumWebService.QueryAssignedEntityForBaselineGroup($svcRefVum).QueryAssignedEntityForBaselineGroupResponse1.entity)
    } # try
    catch {
        throw ("Failed to query hosts assigned to this baseline group. " + $_.Exception.Message)
    } # catch


    ## Baseline group is assigned, display warnings
    if ($assignedHosts -and $removeIfAssigned) {

        Write-Warning ("-removeIfAssigned has been specified. The following entities will have this baseline group removed.")

        foreach ($assignedHost in $assignedHosts) {

            ## Write warning for assigned entity
            Write-Warning ("Entity "  + $assignedHost.value)

        } # foreach

    } # if
    ## Baseline group is assigned and won't be removed. Function will return.
    elseif ($assignedHosts -and !$removeIfAssigned) {

        Write-Warning ("-removeIfAssigned has not been specified. The following entities have this baseline group assigned.")

        foreach ($assignedHost in $assignedHosts) {

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

            $reqType = New-Object IntegrityApi.DeleteBaselineGroupRequestType -ErrorAction Stop
            $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.baselineGroupManager
            $reqType.id = $baselineGroup.key

            $svcRefVum = New-Object IntegrityApi.DeleteBaselineGroupRequest($reqType) -ErrorAction Stop

            $result = $vumCon.vumWebService.DeleteBaselineGroup($svcRefVum)
        } # if

        Write-Verbose ("Baseline group removed.")
    } # try
    catch {
        throw ("Failed to remove the specified baseline group. " + $_.Exception.Message)
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

} # function