function Remove-BaselineFromGroup {
    <#
    .SYNOPSIS
        Removes a baseline from a VUM baseline group.

        With thanks to Lyuboslav Asenov @ VMWare for providing assistance with new Update Manager API.

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
        03       30/11/22     Reworked for PowerCLI 12.7 and new API                A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Medium")]
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
        try {
            $baseline = Get-Baseline -Name $baselineName -ErrorAction Stop
        } # try
        catch {
            throw ("Failed to get baseline. " + $_.Exception.Message)
        } # catch


        ## Get baselines already attached to this group
        ## VUM for whatever reason has a problem with Powershell arrays, so we need a .net one
        $arrayList = New-Object System.Collections.ArrayList


        ## Add each item into our .net array
        foreach ($baselineItem in $baselineGroup.baseline) {

            [void]$arrayList.Add($baselineItem)

        } # foreach

        Write-Verbose ("Acquired list of existing baselines.")


        ## Verify that the baseline we are removing is assigned to this group.
        if ($arrayList -notcontains $baseline.Id) {

            Write-Warning ("Baseline does not exist in target baseline group. No action has been taken.")
            return

        } # if
        else {

            ## Remove specified baseline ID from array
            [void]$arrayList.Remove($baseline.Id)
            Write-Verbose ("Revmoed baseline from baseline group.")

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
        try {

            ## Apply shouldProcess
            if ($PSCmdlet.ShouldProcess($baselineName + " in baseline group " + $baselineGroupName)) {

                $reqType = New-Object IntegrityApi.SetBaselineGroupInfoRequestType
                $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.baselineGroupManager
                $reqType.info = $baselineGroupUpdate

                $svcRefVum = New-Object IntegrityApi.SetBaselineGroupInfoRequest($reqType)
                $result = $vumCon.vumWebService.SetBaselineGroupInfo($svcRefVum)

            } # if

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