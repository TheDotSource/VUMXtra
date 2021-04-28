function Remove-EntityBaselineGroup {
    <#
    .SYNOPSIS
        Detaches a baseline group from a host or cluster.

    .DESCRIPTION
        Makes a call to the VC Integrity API to detach a baseline group from a host or cluster.

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
        Remove-EntityBaselineGroup -BaselineGroupName "Sample Baselinegroup" -Entity $VMHost

        Detaches Sample Baselingroup from host esxi01.

    .EXAMPLE
        $Cluster = Get-Cluster -name "vSAN"
        Remove-EntityBaselineGroup -BaselineGroupName "Sample Baselinegroup" -Entity $Cluster

        Detaches Sample Baselingroup from cluster vSAN.

    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       13/11/18     Initial version.                                       A McNair
        02       23/12/19     Tidied up synopsis and added verbose output.           A McNair
                              Added pipeline for baseline entities.
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Medium")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$BaselineGroupName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [ValidateScript({($_.GetType().toString() -eq "VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl") -or ($_.GetType().toString() -eq "VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl")})]
        [PSObject]$entity
    )

    begin {

        Write-Verbose ("[Remove-EntityBaselineGroup]Function start.")

        ## Get a VUM service connection object
        try {
            $vumCon = Connect-VUM -ErrorAction stop
            Write-Verbose ("[Remove-EntityBaselineGroup]Got VUM connection.")
        } # try
        catch {
            Write-Debug ("[Remove-EntityBaselineGroup]Failed to connect to VUM instance.")
            throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)
        } # catch


        ## Get the baseline group object
        for ($i=0; $i -le 255; $i++) {

            ## When baseline is found break out of loop to continue function
            if (($vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)).name -eq $baselineGroupName) {

                $BaselineGroup = $vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)
                Write-Verbose ("[Remove-EntityBaselineGroup]Found baseline group " + $baselineGroupName)
                Break

            } # if

        } # for


        ## Check we have a baseline group to work with
        if (!$baselineGroup) {
            Write-Debug ("[Remove-EntityBaselineGroup]Baseline group not found.")
            throw ("The specified baseline group was not found on this VUM instance.")
        } # if


    } # begin

    process {

        Write-Verbose ("[Remove-EntityBaselineGroup]Processing entity " + $entity.name)

        ## Set object
        $parentTypeValue = $entity.Id.split("-",2)
        $entityObj = New-Object IntegrityApi.ManagedObjectReference
        $entityObj.type = $parentTypeValue[0]
        $entityObj.Value = $parentTypeValue[1]

        Write-Verbose ("[Remove-EntityBaselineGroup]Entity object configured.")


        ## Remove from entity
        try {

            ## Apply shouldProcess
            if ($PSCmdlet.ShouldProcess($name)) {

                $vumCon.vumWebService.RemoveBaselineGroupFromEntity($vumCon.vumServiceContent.baselineGroupManager,$entityObj, $baselineGroup.Key) | Out-Null
            } # if

            Write-Verbose ("[Remove-EntityBaselineGroup]Baseline group detached.")
        } # try
        catch {
            Write-Debug ("[Remove-EntityBaselineGroup]Failed to detach baseline group.")
            throw ("Failed to detach baseline group. " + $_)
        } # catch


        Write-Verbose ("[Remove-EntityBaselineGroup]Completed entity " + $entity.name)

    } # process

    end {

        Write-Verbose ("[Remove-EntityBaselineGroup]All entities completed.")

        ## Logoff session
        try {
            $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)
            Write-Verbose ("[Remove-EntityBaselineGroup]Disconnected from VUM API.")
        } # try
        catch {
            Write-Warning ("[Remove-EntityBaselineGroup]Failed to disconnect from VUM API.")
        } # catch


        Write-Verbose ("[Remove-EntityBaselineGroup]Function completed.")

    } # end


} # function