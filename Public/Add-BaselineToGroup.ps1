function Add-baselineToGroup {
    <#
    .SYNOPSIS
        Attaches an existing patch baseline to a baseline group.

        With thanks to Lyuboslav Asenov @ VMWare for providing assistance with new Update Manager API.

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
        03       30/11/22     Reworked for PowerCLI 12.7 and new API                 A McNair
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

        Write-Verbose ("Function start.")

        ## Get a VUM service connection object
        try {
            $vumCon = Connect-VUM -ErrorAction stop
            Write-Verbose ("Got VUM connection.")
        } # try
        catch {
            throw ("Failed to connect to VUM instance. " + $_.Exception.Message)
        } # catch


    } # begin


    process {

        Write-Verbose ("Processing baseline group " + $baselineGroupName)

        $reqType = New-Object IntegrityApi.GetBaselineGroupInfoRequestType
        $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.baselineGroupManager


        ## Verify that the baseline group exists
        for ($i=0; $i -le 100; $i++) {

            $reqType.id = $i

            try {
                $svcRefVum = New-Object IntegrityApi.GetBaselineGroupInfoRequest($reqType) -ErrorAction Stop
                $result = $vumCon.vumWebService.GetBaselineGroupInfo($svcRefVum)

                ## When baseline is found break out of loop to continue function
                if (($result.GetBaselineGroupInfoResponse1).name -eq $baselineGroupName) {

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


        ## Check specified baseline exists
        Write-Verbose ("Fetching target baseline.")

        try {
            $baseline = Get-Baseline -Name $baselineName -ErrorAction Stop
            Write-Verbose ("Got baseline " + $baseline.name)
        } # try
        catch {
            throw ("Failed to get baseline. " + $_)
        } # catch


        ## Get baselines already attached to this group
        ## VUM for whatever reason has a problem with Powershell arrays, so we need a .net one
        $arrayList = New-Object System.Collections.ArrayList


        ## Add each item into our .net array
        foreach ($baselineItem in $baselineGroup.baseline) {

            [void]$arrayList.Add($baselineItem)

        } # foreach

        Write-Verbose ("Acquired list of existing baselines.")


        ## If this baseline already exists in this group then return from the function, no more work to do
        if ($arrayList -contains $baseline.Id) {

            Write-Verbose ("Baseline already exists in group, no further action is necessary.")
            return
        } # if
        else {

            ## We need to check if the baseline to be added is an image baseline.
            ## If it is, we need to check if an image baseline is already in this baseline group.
            ## We can only have 1 image baseline per baseline group.

            if ($baseline.baselineType -eq "Upgrade") {

                Write-Verbose ("Target baseline is an image baseline. Checking for existing image baseline in baseline group.")

                ## Iterate through baseline ID's to check
                foreach ($baselineItem in $baselineGroup.baseline) {

                    $baselineDetail = Get-Baseline -Id $baselineItem -ErrorAction Stop

                    ## Bad news, there is already an image baseline in this baseline group.
                    ## This needs to be removed prior to adding the target image baseline.
                    if ($baselineDetail.baselineType -eq "Upgrade") {
                        throw ("The target baseline group contains an existing image baseline (" + $baselineDetail.name + "). Remove this image baseline and retry the operation.")
                    } # if

                } # foreach

            } # if

            ## Add specified baseline ID to array
            [void]$arrayList.Add($baseline.Id)
            Write-Verbose ("Added baseline.")
        } # else


        ## Create new baseline group spec
        Write-Verbose ("Creating baseline group spec.")
        try {
            $baselineGroupUpdate = New-Object IntegrityApi.BaselineGroupManagerBaselineGroupInfo -ErrorAction Stop
            $baselineGroupUpdate.Key = $baselineGroup.Key
            $baselineGroupUpdate.versionNumber = $baselineGroup.versionNumber
            $baselineGroupUpdate.lastUpdateTimeSpecified = $true
            $baselineGroupUpdate.lastUpdateTime = Get-Date
            $baselineGroupUpdate.name = $baselineGroup.name
            $baselineGroupUpdate.targetType = "HOST"
            $baselineGroupUpdate.baseline = $arrayList
            $baselineGroupUpdate.description = $baselineGroup.Description

            Write-Verbose ("Baseline group spec created.")
        } # try
        catch {
            throw ("Failed to create baseline group spec. " + $_.Exception.Message)
        } # catch


        ## Apply update to baseline group
        Write-Verbose ("Updating baseline group.")
        try {

            $reqType = New-Object IntegrityApi.SetBaselineGroupInfoRequestType
            $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.baselineGroupManager
            $reqType.info = $baselineGroupUpdate

            $svcRefVum = New-Object IntegrityApi.SetBaselineGroupInfoRequest($reqType)
            $result = $vumCon.vumWebService.SetBaselineGroupInfo($svcRefVum)

            Write-Verbose ("Applied update to baseline group.")
        } # try
        catch {
            throw ("Failed to apply update to group. " + $_.Exception.Message)
        } # catch

        Write-Verbose ("Completed baseline group " + $baselineGroupName)

    } # process

    end {

        Write-Verbose ("All baseline groups complete.")

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

    } # end

} # function