function Add-baselineToGroup {
    <#
    .SYNOPSIS
        Attaches an existing patch baseline to a baseline group.

    .DESCRIPTION
        Makes a call to the VC Integrity API to attach a baseline to an existing baseline group.

    .PARAMETER baselineGroupName
        The name of the baseline group to attach the baseline to.

    .PARAMETER baseline
        The name of the baseline to attach to the baseline group.

    .INPUTS
        System.String. The name of the baseline group to attach the baseline to.

    .OUTPUTS
        None.

    .EXAMPLE
        Add-baselineToGroup -baselineGroupName "Host Patches" -baseline "August Baseline"

        Attaches a baseline called August Baseline to a baseline group Host Patches.

    .EXAMPLE
        @("Test-BaselineGroup01","Test-BaselineGroup02") | Add-baselineToGroup -baselineName "Test-Baseline" -Verbose

        Attaches a baseline called August Baseline to a baseline group Host Patches.

    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       13/11/18     Initial version.                                       A McNair
        02       23/12/19     Tidied up synopsis and added verbose output.           A McNair
                              Added pipeline for baseline groups.
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [String]$baselineGroupName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$baselineName
    )

    begin {

        Write-Verbose ("[Add-baselineToGroup]Function start.")

        ## Get a VUM service connection object
        try {
            $vumCon = Connect-VUM -ErrorAction stop
            Write-Verbose ("[Add-baselineToGroup]Got VUM connection.")
        } # try
        catch {
            Write-Debug ("[Add-baselineToGroup]Failed to connect to VUM instance.")
            throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)
        } # catch


    } # begin


    process {

        Write-Verbose ("[Add-baselineToGroup]Processing baseline group " + $baselineGroupName)


        ## Verify that the baseline group exists
        for ($i=0; $i -le 768; $i++) {
                    ## When baseline is found break out of loop to continue function
            if (($vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)).name -eq $BaselineGroupName) {

                $BaselineGroup = $vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)
                Write-Verbose ("[Add-baselineToGroup]Found baseline group.")
                Break

            } # if

        } # for


        ## Check we have a baseline group to work with
        if (!$baselineGroup) {
            Write-Debug ("[Add-baselineToGroup]Baseline group not found.")
            throw ("The specified baseline group was not found on this VUM instance.")
        } # if


        ## Check specified baseline exists
        try {
            $baseline = Get-Baseline -Name $BaselineName -ErrorAction Stop
            Write-Verbose ("[Add-baselineToGroup]Got baseline " + $baseline.name)
        } # try
        catch {
            Write-Debug ("[Add-baselineToGroup]Failed to get baseline.")
            throw ("Failed to get baseline. " + $_)
        } # catch


        ## Get baselines already attached to this group
        ## VUM for whatever reason has a problem with Powershell arrays, so we need a .net one
        $arrayList = New-Object System.Collections.ArrayList


        ## Add each item into out .net array
        foreach ($BaselineItem in $BaselineGroup.baseline) {

            [void]$arrayList.Add($BaselineItem)

        } # foreach

        Write-Verbose ("[Add-baselineToGroup]Acquired list of existing baselines.")


        ## If this baseline already exists in this group then return from the function, no more work to do
        if ($arrayList -contains $baseline.Id) {

            Write-Verbose ("[Add-baselineToGroup]Baseline already exists in group, no further action is necessary.")
            return
        } # if
        else {

            ## Add specified baseline ID to array
            [void]$arrayList.Add($baseline.Id)
            Write-Verbose ("[Add-baselineToGroup]Added baseline.")
        } # else


        ## Create new baseline group spec
        $baselineGroupUpdate = New-Object IntegrityApi.BaselineGroupManagerBaselineGroupInfo
        Write-Verbose ("[Add-baselineToGroup]Created baseline group update object.")


        ## Set baseline group spec properties
        $BaselineGroupUpdate.Key = $baselineGroup.Key
        $BaselineGroupUpdate.versionNumber = $baselineGroup.versionNumber
        $BaselineGroupUpdate.lastUpdateTimeSpecified = $true
        $BaselineGroupUpdate.lastUpdateTime = Get-Date
        $BaselineGroupUpdate.name = $baselineGroup.name
        $BaselineGroupUpdate.targetType = "HOST"
        $BaselineGroupUpdate.baseline = $ArrayList
        $BaselineGroupUpdate.description = $baselineGroup.Description

        Write-Verbose ("[Add-baselineToGroup]Set baseline group update properties.")


        ## Apply update to baseline group
        try {
            $vumCon.vumWebService.SetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$BaselineGroupUpdate) | Out-Null
            Write-Verbose ("[Add-baselineToGroup]Applied update to baseline group.")
        } # try
        catch {
            Write-Debug ("[Add-baselineToGroup]Failed to apply update to group.")
            throw ("Failed to apply update to group. " + $_)
        } # catch


        Write-Verbose ("[Add-baselineToGroup]Completed baseline group " + $baselineGroupName)


    } # process


    end {

        Write-Verbose ("[Add-baselineToGroup]All baseline groups complete.")

        ## Logoff session
        try {
            $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)
            Write-Verbose ("[Add-baselineToGroup]Disconnected from VUM API.")
        } # try
        catch {
            Write-Warning ("[Add-baselineToGroup]Failed to disconnect from VUM API.")
        } # catch


        Write-Verbose ("[Add-baselineToGroup]Function completed.")

    } # end


} # function