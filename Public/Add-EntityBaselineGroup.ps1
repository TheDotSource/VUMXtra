function Add-EntityBaselineGroup {
    <#
    .SYNOPSIS
        Attaches a baseline group to host or cluster.

    .DESCRIPTION
        Makes a call to the VC Integrity API to attach a baseline group to a host or cluster.

    .PARAMETER baselineGroupName
        The name of the baseline group to attach to the host or cluster.

    .PARAMETER entity
        Entity to attach the baseline group to, for example, a host or cluster.

    .INPUTS
        PSObject An entity object for either a cluster or a host.
        Must be of type VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl or  VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl

    .OUTPUTS
        None.

    .EXAMPLE
        $VMHost = Get-VMHost -name "esxi01"
        Add-EntityBaselineGroup -BaselineGroupName "Sample Baselinegroup" -Entity $VMHost

        Attach Sample Baselingroup to a host esxi01.

    .EXAMPLE
        $VMHosts = Get-VMHost | where {$_.name -like "*esxdat*"}
        $VMHosts | Add-EntityBaselineGroup -BaselineGroupName "Sample Baselinegroup" -Verbose

        Attach Sample Baselingroup to all hosts matching *esxdat*. Use verbose output.

    .EXAMPLE
        $Cluster = Get-Cluster -name "vSAN"
        Add-EntityBaselineGroup -BaselineGroupName "Sample Baselinegroup" -Entity $Cluster

        Attach Sample Baselingroup to a cluster vSAN.

    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       13/11/18     Initial version.                                       A McNair
        02       23/12/19     Tidied up synopsis and added verbose output.           A McNair
                              Added pipeline for entities.
        03       30/11/22     Reworked for PowerCLI 12.7 and new API                 A McNair
    #>

    [CmdletBinding()]
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
            throw ("Failed to connect to VUM instance. The CMDlet returned " + $_.Exception.Message)
        } # catch


        ## Get baseline group object
        Write-Verbose ("Getting baseline group object.")

        $reqType = New-Object IntegrityApi.GetBaselineGroupInfoRequestType
        $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.baselineGroupManager

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


    } # begin


    process {

        Write-Verbose ("Processing entity " + $entity.name)

        ## Set object
        $parentTypeValue = $entity.Id.split("-",2)
        $entityObj = New-Object IntegrityApi.ManagedObjectReference
        $entityObj.type = $parentTypeValue[0]
        $entityObj.Value = $parentTypeValue[1]

        Write-Verbose ("Entity object configured.")


        ## Attach to host or cluster
        Write-Verbose ("Attaching baseline group to entity.")

        try {
            $reqType = New-Object IntegrityApi.AssignBaselineGroupToEntityRequestType -ErrorAction Stop
            $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.baselineGroupManager
            $reqType.entity = $entityObj
            $reqType.group = $baselineGroup.key

            $svcRefVum = New-Object IntegrityApi.AssignBaselineGroupToEntityRequest($reqType) -ErrorAction Stop

            $vumCon.vumWebService.AssignBaselineGroupToEntity($svcRefVum) | Out-Null
            Write-Verbose ("Baseline group assigned.")
        } # try
        catch {
            throw ("Failed to assign baseline group. " + $_.Exception.Message)
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