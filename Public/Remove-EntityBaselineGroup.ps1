function Remove-EntityBaselineGroup {
    <#
    .SYNOPSIS
        Detaches a baseline group from a host or cluster.

        With thanks to Lyuboslav Asenov @ VMWare for providing assistance with new Update Manager API.

    .DESCRIPTION
        Makes a call to the VC Integrity API to detach a baseline group from a host or cluster.

    .PARAMETER baselineGroupName
        The name of the baseline group to detach from the host or cluster.

    .PARAMETER entity
        The entity from which to detach the baseline from, for example, and host or cluster.

    .INPUTS
        VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl or VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl
        An entity object for either a cluster or a host.

    .OUTPUTS
        None.

    .EXAMPLE
        $VMHost = Get-VMHost -name "esxi01.local"
        Remove-EntityBaselineGroup -BaselineGroupName "Sample Baselinegroup" -Entity $VMHost

        Detaches Sample Baselinegroup from host esxi01.

    .EXAMPLE
        $cluster = Get-Cluster -name "vSAN"
        Remove-EntityBaselineGroup -BaselineGroupName "Sample Baselinegroup" -Entity $cluster

        Detaches Sample Baselinegroup from cluster vSAN.

    .EXAMPLE
        $vmHosts = Get-VMHost -name esxi01.local,esxi02.local
        $vmHosts | Remove-EntityBaselineGroup -BaselineGroupName "Sample Baselinegroup"

        Detaches Sample Baselinegroup from multiple entities using the pipeline.

    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       13/11/18     Initial version.                                       A McNair
        02       23/12/19     Tidied up synopsis and added verbose output.           A McNair
                              Added pipeline for baseline entities.
        03       13/12/22     Reworked for PowerCLI 12.7 and new API                 A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Medium")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$baselineGroupName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [ValidateScript({($_.GetType().toString() -eq "VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl") -or ($_.GetType().toString() -eq "VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl")})]
        [PSObject]$entity
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


    } # begin

    process {

        Write-Verbose ("Processing entity " + $entity.name)

        ## Set object
        $parentTypeValue = $entity.Id.split("-",2)
        $entityObj = New-Object IntegrityApi.ManagedObjectReference
        $entityObj.type = $parentTypeValue[0]
        $entityObj.Value = $parentTypeValue[1]

        Write-Verbose ("Entity object configured.")


        ## Remove from entity
        try {

            ## Apply shouldProcess
            if ($PSCmdlet.ShouldProcess($name)) {

                $reqType = New-Object IntegrityApi.RemoveBaselineGroupFromEntityRequestType
                $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.baselineGroupManager
                $reqType.entity = $entityObj
                $reqType.group = 39


                $svcRefVum = New-Object IntegrityApi.RemoveBaselineGroupFromEntityRequest($reqType)
                $result = $vumCon.vumWebService.RemoveBaselineGroupFromEntity($svcRefVum)

            } # if

            Write-Verbose ("Baseline group detached.")
        } # try
        catch {
            throw ("Failed to detach baseline group. " + $_.Exception.Message)
        } # catch


        Write-Verbose ("Completed entity " + $entity.name)

    } # process

    end {

        Write-Verbose ("All entities completed.")

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