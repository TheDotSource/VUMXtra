function Detach-BaselineGroup {
    <#
    .SYNOPSIS
        Detaches a baseline group from a host or cluster.
    .DESCRIPTION
        This function is part of a module that addresses gaps in the VUM PowerCLI CMDlets.
        The VCItegrity private API is used.
        This function will detach a baseline group from a host or cluster.
    .EXAMPLE
        $VMHost = Get-VMHost -name "esxi01"
        Detach-BaselineGroup -BaselineGroupName "Sample Baselinegroup" -Entity $VMHost

        Detaches Sample Baselingroup from host esxi01.
    .EXAMPLE
        $Cluster = Get-Cluster -name "vSAN"
        Detach-BaselineGroup -BaselineGroupName "Sample Baselinegroup" -Entity $Cluster

        Detaches Sample Baselingroup from cluster vSAN.
    .NOTES
        01       13/11/18     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$BaselineGroupName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [PSObject]$Entity
    )

    Write-Debug ("[Detach-BaselineGroup]Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Debug ("[Remove-BaselineGroup]Got VUM connection.")
    } # try
    catch {
        Write-Debug ("[Remove-BaselineGroup]Failed to connect to VUM instance.")
        throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)  
    } # catch


    ## Get the baseline group object
    $BaseLineGroupInfo = New-Object IntegrityApi.BaselineGroupManagerBaselineGroupInfo

    for ($i=0; $i -le 100; $i++) {
        
        ## When baseline is found break out of loop to continue function
        if (($vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)).name -eq $BaselineGroupName) {

            $BaselineGroup = $vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)
            Write-Debug ("[Detach-BaselineGroup]Found baseline group.")
            Break    

        } # if

    } # for


    ## Check we have a baseline group to work with
    if (!$BaselineGroup) {
        Write-Debug ("[Detach-BaselineGroup]Baseline group not found.")
        throw ("The specified baseline group was not found on this VUM instance.")  
    } # if


    ## Check we have an entity ID to assign to
    if (!$Entity.Id) {
        Write-Debug ("[Detach-BaselineGroup]The supplied entity does not have an ID.")
        throw ("The supplied entity does not have an ID. Ensure that a valid vCenter object has been passed to this function, e.g. VM, host, cluster.") 
    }


    ## Set object
    $ParentTypeValue = $Entity.Id.split("-",2)
    $Entity = New-Object IntegrityApi.ManagedObjectReference
    $Entity.type = $ParentTypeValue[0]
    $Entity.Value = $ParentTypeValue[1]
    Write-Debug ("[Detach-BaselineGroup]Entity object configured.")


    ## Attach to host
    try {
        $vumCon.vumWebService.RemoveBaselineGroupFromEntity($vumCon.vumServiceContent.baselineGroupManager,$Entity, $BaselineGroup.Key) | Out-Null
        Write-Debug ("[Detach-BaselineGroup]Baseline group detached.")
    } # try
    catch {
        Write-Debug ("[Detach-BaselineGroup]Failed to detach baseline group.")
        throw ("Failed to detach baseline group. " + $_)
    } # catch


    ## Logoff session
    $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)

} # function