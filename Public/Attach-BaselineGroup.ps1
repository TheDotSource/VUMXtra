function Attach-BaselineGroup {
    <#
    .SYNOPSIS
        Attaches a baseline group to host or cluster.
    .DESCRIPTION
        This function is part of a module that addresses gaps in the VUM PowerCLI CMDlets.
        The VCItegrity private API is used.
        This function will attach a baseline group to a host or cluster.
    .EXAMPLE
        $VMHost = Get-VMHost -name "esxi01"
        Attach-BaselineGroup -BaselineGroupName "Sample Baselinegroup" -Entity $VMHost

        Attach Sample Baselingroup to a host esxi01.
    .EXAMPLE
        $Cluster = Get-Cluster -name "vSAN"
        Attach-BaselineGroup -BaselineGroupName "Sample Baselinegroup" -Entity $Cluster

        Attach Sample Baselingroup to a cluster vSAN.
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

    Write-Debug ("[Attach-BaselineGroup]Function start.")

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
            Write-Debug ("[Attach-BaselineGroup]Found baseline group.")
            Break    

        } # if

    } # for


    ## Check we have a baseline group to work with
    if (!$BaselineGroup) {
        Write-Debug ("[Attach-BaselineGroup]Baseline group not found.")
        throw ("The specified baseline group was not found on this VUM instance.")  
    } # if


    ## Check we have an entity ID to assign to
    if (!$Entity.Id) {
        Write-Debug ("[Attach-BaselineGroup]The supplied entity does not have an ID.")
        throw ("The supplied entity does not have an ID. Ensure that a valid vCenter object has been passed to this function, e.g. VM, host, cluster.") 
    }


    ## Set object
    $ParentTypeValue = $Entity.Id.split("-",2)
    $Entity = New-Object IntegrityApi.ManagedObjectReference
    $Entity.type = $ParentTypeValue[0]
    $Entity.Value = $ParentTypeValue[1]
    Write-Debug ("[Attach-BaselineGroup]Entity object configured.")


    ## Attach to host
    try {
        $vumCon.vumWebService.AssignBaselineGroupToEntity($vumCon.vumServiceContent.baselineGroupManager,$Entity, $BaselineGroup.Key) | Out-Null
        Write-Debug ("[Attach-BaselineGroup]Baseline group assigned.")
    } # try
    catch {
        Write-Debug ("[Attach-BaselineGroup]Failed to assign baseline group.")
        throw ("Failed to assign baseline group. " + $_)
    } # catch


    ## Logoff session
    $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)

} # function