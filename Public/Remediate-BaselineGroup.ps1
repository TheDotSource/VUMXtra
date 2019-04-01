function Remediate-BaselineGroup {
    <#
    .SYNOPSIS
        Remediates a host against a baseline group.
    .DESCRIPTION
        This function is part of a module that addresses gaps in the VUM PowerCLI CMDlets.
        The VCItegrity private API is used.
        This function will remediate a host against a baseline group
    .EXAMPLE
        $VMHost = Get-VMHost -name "esxi01"
        Remediate-BaselineGroup -BaselineGroupName "Sample Baseline Group" -Entity $VMHost

        Remediates host esxi01 against baseline group Sample Baseline Group.
    .EXAMPLE
        $Cluster = Get-Cluster -name "vSAN"
        Remediate-BaselineGroup -BaselineGroupName "Sample Baseline Group" -Entity $Cluster

        Remediates cluster vSAN against baseline group Sample Baseline Group.
    .NOTES
        01       013/11/18     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$BaselineGroupName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [PSObject]$Entity
    )

    Write-Debug ("[Remediate-BaselineGroup]Function start.")

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
            Write-Debug ("[Remediate-BaselineGroup]Found baseline group.")
            Break    

        } # if

    } # for


    ## Check we have a baseline group to work with
    if (!$BaselineGroup) {
        Write-Debug ("[Remediate-BaselineGroup]Baseline group not found.")
        throw ("The specified baseline group was not found on this VUM instance.")  
    } # if


    ## Initiate a scan of the host
    try {
        $HostScan = Scan-Inventory -Entity $Entity -ErrorAction Stop
    } # try
    catch {
        Write-Debug ("[Remediate-BaselineGroup]Failed to scan entity.")
        throw ("Compliance scan failed on entity. " + $_)
    } # catch


    ## Set parent and leaf objects
    $LeafTypeValue = $Entity.id.split("-",2)
    $LeafEntity = New-Object IntegrityApi.ManagedObjectReference
    $LeafEntity.type = $LeafTypeValue[0]
    $LeafEntity.Value = $LeafTypeValue[1]

    $ParentTypeValue = $Entity.ParentId.split("-",2)
    $ParentEntity = New-Object IntegrityApi.ManagedObjectReference
    $ParentEntity.type = $ParentTypeValue[0]
    $ParentEntity.Value = $ParentTypeValue[1]
    Write-Debug ("[Remediate-BaselineGroup]Entity object configured.")



    ## Query compliance status for specified baseline group
    try {
        $ComplianceStatus = ($vumCon.vumWebService.QueryBaselineGroupComplianceStatus($vumCon.vumServiceContent.complianceStatusManager,$LeafEntity) | where {$_.key -eq $BaselineGroup.key})
        Write-Debug ("[Remediate-BaselineGroup]Obtained entity compliance status.")
    } # try
    catch {
        Write-Debug ("[Remediate-BaselineGroup]Failed to get compliance status.")
        throw ("Failed to query compliance status of entity. " + $_)
    } # catch


    ## Check if this entity is compliant with baseline group or not
    if ($ComplianceStatus.status -eq "Compliant") {
        Write-Debug ("[Remediate-BaselineGroup]Entity is already compliant with baseline group.")
        Write-Output ("Entity is already compliant with baseline group.")
        Break
    } # if


    ## Phase 1 remediation
    ## Initialise IntegrityApi.HostRemediationScheduleOption object and configure
    $hostScheduler = New-Object IntegrityApi.HostRemediationScheduleOption 
    $hostScheduler.failureAction = "Retry" # Possible values, FailTask, Retry
    $hostScheduler.updateHostTime = Get-Date
    $hostScheduler.updateHostTimeSpecified = $false
    $hostScheduler.evacuationTimeout = 0
    $hostScheduler.evacuationTimeoutSpecified = $false
    $hostScheduler.evacuateOfflineVMs = $false
    $hostScheduler.evacuateOfflineVMsSpecified = $true
    $hostScheduler.preRemediationPowerAction = "DoNotChangeVMsPowerState" # Possible values, PowerOffVMs, SuspendVMs, DoNotChangeVMsPowerState
    $hostScheduler.retryDelay = 300
    $hostScheduler.retryDelaySpecified = $true
    $hostScheduler.numberOfRetries = 3
    $hostScheduler.numberOfRetriesSpecified = $true
    $hostScheduler.scheduledTaskName = "VUM Extra remediation."
    $hostScheduler.scheduledTaskDescription = "Test"
    $hostScheduler.disconnectRemovableDevices = $false
    $hostScheduler.disconnectRemovableDevicesSpecified = $true
    $hostScheduler.disableDpm = $true
    $hostScheduler.disableDpmSpecified = $true
    $hostScheduler.disableHac = $false
    $hostScheduler.disableHacSpecified = $true
    $hostScheduler.disableFt = $false
    $hostScheduler.disableFtSpecified = $true
    $hostScheduler.concurrentRemediationInCluster = $false
    $hostScheduler.concurrentRemediationInClusterSpecified = $true
    $hostScheduler.allowStatelessRemediation = $false
    $hostScheduler.allowStatelessRemediationSpecified = $true
    $hostScheduler.maxHostsForParallelRemediationInCluster = 1
    $hostScheduler.maxHostsForParallelRemediationInClusterSpecified = $true
    Write-Debug ("[Remediate-BaselineGroup]Host scheduler options set.")

    ## Initialise IntegrityApi.HostUpgradeOptionManagerOptions object and configure
    $hostUpgradeOptions = New-Object IntegrityApi.HostUpgradeOptionManagerOptions
    $hostUpgradeOptions.ignore3rdPartyModules = $false
    $hostUpgradeOptions.ignore3rdPartyModulesSpecified = $true
    Write-Debug ("[Remediate-BaselineGroup]Host upgrade options set.")


    ## Phase 2 remediation
    ## Initialise IntegrityApi.VcIntegrityRemediateOption object, consuming phase 1 objects as input
    ## Initialise IntegrityApi.UpdateManagerBaselineGroupUnit which specifies what baseline group and baselines we want to use
    $RemediateOption = New-Object IntegrityApi.VcIntegrityRemediateOption
    $RemediateOption.hostScheduler = $hostScheduler
    $RemediateOption.hostUpgradeOptions = $hostUpgradeOptions
    $BaselineGroupUnit = New-Object IntegrityApi.UpdateManagerBaselineGroupUnit
    $BaselineGroupUnit.baselinegroup = $BaselineGroup.Key
    Write-Debug ("[Remediate-BaselineGroup]Remediation option and group unit objects configured.")


    ## Phase 3 remediation
    ## Initialise IntegrityApi.UpdateManagerRemediationSpec object which consumes phase 2 objects as input
    $RemediationSpec = New-Object IntegrityApi.UpdateManagerRemediationSpec
    $RemediationSpec.baselineGroupUnit = $BaselineGroupUnit
    $RemediationSpec.option = $RemediateOption
    Write-Debug ("[Remediate-BaselineGroup]Remediation spec configured.")


    ## Phase 4 remediation
    ## The phase 3 object is the completed object we send to the API with Leaf and Entity objects to the UpdateManager
    ## The API will kick back a job object we can monitor for progress
    try {
        $MofTask = $vumCon.vumWebService.Remediate_Task($vumCon.vumServiceContent.updateManager, $ParentEntity, $LeafEntity, $RemediationSpec)
        Write-Debug ("[Remediate-BaselineGroup]Remediation task started.")
    } # try
    catch {
        Write-Debug ("[Remediate-BaselineGroup]Failed to start remediation task.")
        throw ("Failed to start remediation task. " + $_)
    } # catch


    ## Wait for remedaition jopb to complete
    $JobStatus = Get-Task -id ("Task-" + $MofTask.value)

    while ($JobStatus.State -eq "Running") {

        Write-Progress -Activity ("Applying Baseline Group to host " + $ESXiHost) -Status ($JobStatus.PercentComplete.ToString() + " percent complete.") -PercentComplete $JobStatus.PercentComplete

        Start-Sleep 10

        $JobStatus = Get-Task -id ("Task-" + $MofTask.value)
    } # while


    ## Check the job did not fail
    if ($JobStatus.state -eq "Error") {
        Write-Debug ("[Remediate-BaselineGroup]Remediation task failed.")
        throw ("Remediation task failed.")
    }

    Write-Debug ("Job finished running.")


    ## Logoff session
    $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)

} # function