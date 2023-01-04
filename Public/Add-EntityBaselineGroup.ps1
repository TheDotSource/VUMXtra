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

        Write-Verbose ("[Add-EntityBaselineGroup]Function start.")

        ## Get a VUM service connection object
        try {
            $vumCon = Connect-VUM -ErrorAction stop
            Write-Verbose ("[Add-EntityBaselineGroup]Got VUM connection.")
        } # try
        catch {
            Write-Debug ("[Add-EntityBaselineGroup]Failed to connect to VUM instance.")
            throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)
        } # catch


        ## Get the baseline group object
        for ($i=0; $i -le 768; $i++) {

            ## When baseline is found break out of loop to continue function
            if (($vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)).name -eq $baselineGroupName) {

                $BaselineGroup = $vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)
                Write-Verbose ("[Add-EntityBaselineGroup]Found baseline group " + $baselineGroupName)
                Break

            } # if

        } # for


        ## Check we have a baseline group to work with
        if (!$baselineGroup) {
            Write-Debug ("[Add-EntityBaselineGroup]Baseline group not found.")
            throw ("The specified baseline group was not found on this VUM instance.")
        } # if


    } # begin


    process {

        Write-Verbose ("[Add-EntityBaselineGroup]Processing entity " + $entity.name)

        ## Set object
        $parentTypeValue = $entity.Id.split("-",2)
        $entityObj = New-Object IntegrityApi.ManagedObjectReference
        $entityObj.type = $parentTypeValue[0]
        $entityObj.Value = $parentTypeValue[1]

        Write-Verbose ("[Add-EntityBaselineGroup]Entity object configured.")


        ## Attach to host
        try {
            $vumCon.vumWebService.AssignBaselineGroupToEntity($vumCon.vumServiceContent.baselineGroupManager,$entityObj, $baselineGroup.Key) | Out-Null
            Write-Verbose ("[Add-EntityBaselineGroup]Baseline group assigned.")
        } # try
        catch {
            Write-Debug ("[Add-EntityBaselineGroup]Failed to assign baseline group.")
            throw ("Failed to assign baseline group. " + $_)
        } # catch


        Write-Verbose ("[Add-EntityBaselineGroup]Completed entity " + $entity.name)


    } # process

    end {

        Write-Verbose ("[Add-EntityBaselineGroup]All entities completed.")

        ## Logoff session
        try {
            $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)
            Write-Verbose ("[Add-EntityBaselineGroup]Disconnected from VUM API.")
        } # try
        catch {
            Write-Warning ("[Add-EntityBaselineGroup]Failed to disconnect from VUM API.")
        } # catch


        Write-Verbose ("[Add-EntityBaselineGroup]Function completed.")

    } # end

} # function