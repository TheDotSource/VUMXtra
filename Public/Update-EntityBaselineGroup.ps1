function Update-EntityBaselineGroup {
    <#
    .SYNOPSIS
        Remediates a host against a baseline group.

    .DESCRIPTION
        Makes a call to the VC Integrity API to remediate a host or cluster against a baseline group.

    .PARAMETER baselineGroupName
        Name of the baseline group to remediate against.

    .PARAMETER entity
        Entity object to remediate against, either a host or a cluster.

    .INPUTS
        PSObject An entity object for either a cluster or a host.
        Must be of type VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl or  VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl

    .OUTPUTS
        None.

    .EXAMPLE
        $VMHost = Get-VMHost -name "esxi01"
        Update-EntityBaselineGroup -BaselineGroupName "Sample Baseline Group" -Entity $VMHost

        Remediates host esxi01 against baseline group Sample Baseline Group.

    .EXAMPLE
        $Cluster = Get-Cluster -name "vSAN"
        Update-EntityBaselineGroup -BaselineGroupName "Sample Baseline Group" -Entity $Cluster

        Remediates cluster vSAN against baseline group Sample Baseline Group.

    .EXAMPLE
        $vmHosts | Update-EntityBaselineGroup -baselineGroupName "Test-BaselineGroup01" -Verbose

        Remediates all hosts in $vmHosts, one at a time, to baseline group Test-Baselinegroup01

    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       13/11/18     Initial version.                                      A McNair
        02       23/12/19     Tidied up synopsis and added verbose output.          A McNair
                              Added pipeline input for entity.
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="High")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$baselineGroupName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [ValidateScript({($_.GetType().toString() -eq "VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl") -or ($_.GetType().toString() -eq "VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl")})]
        [PSObject]$entity
    )

    begin {

        Write-Verbose ("[Update-EntityBaselineGroup]Function start.")

        ## Get a VUM service connection object
        try {
            $vumCon = Connect-VUM -ErrorAction stop
            Write-Verbose ("[Update-EntityBaselineGroup]Got VUM connection.")
        } # try
        catch {
            Write-Debug ("[Update-EntityBaselineGroup]Failed to connect to VUM instance.")
            throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)
        } # catch


        ## Get the baseline group object
        for ($i=0; $i -le 255; $i++) {

            ## When baseline is found break out of loop to continue function
            if (($vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)).name -eq $baselineGroupName) {

                $BaselineGroup = $vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)
                Write-Verbose ("[Update-EntityBaselineGroup]Found baseline group " + $baselineGroupName)
                Break

            } # if

        } # for


        ## Check we have a baseline group to work with
        if (!$baselineGroup) {
            Write-Debug ("[Update-EntityBaselineGroup]Baseline group not found.")
            throw ("The specified baseline group was not found on this VUM instance.")
        } # if

    } # begin

    process {

        Write-Verbose ("[Update-EntityBaselineGroup]Processing entity " + $entity.name)


        ## Initiate a scan of the host
        try {
            Test-Compliance -Entity $Entity -ErrorAction Stop | Out-Null
        } # try
        catch {
            Write-Debug ("[Update-EntityBaselineGroup]Failed to scan entity.")
            throw ("Compliance scan failed on entity. " + $_)
        } # catch

        Write-Verbose ("[Update-EntityBaselineGroup]Completed compliance scan of entity.")


        ## Set parent and leaf objects
        $LeafTypeValue = $Entity.id.split("-",2)
        $LeafEntity = New-Object IntegrityApi.ManagedObjectReference
        $LeafEntity.type = $LeafTypeValue[0]
        $LeafEntity.Value = $LeafTypeValue[1]

        $ParentTypeValue = $Entity.ParentId.split("-",2)
        $ParentEntity = New-Object IntegrityApi.ManagedObjectReference
        $ParentEntity.type = $ParentTypeValue[0]
        $ParentEntity.Value = $ParentTypeValue[1]

        Write-Verbose ("[Update-EntityBaselineGroup]Entity object configured.")



        ## Query compliance status for specified baseline group
        try {
            $complianceStatus = $vumCon.vumWebService.QueryBaselineGroupComplianceStatus($vumCon.vumServiceContent.complianceStatusManager,$LeafEntity) | Where-Object {$_.key -eq $BaselineGroup.key}
            Write-Verbose ("[Update-EntityBaselineGroup]Obtained entity compliance status.")
        } # try
        catch {
            Write-Debug ("[Update-EntityBaselineGroup]Failed to get compliance status.")
            throw ("Failed to query compliance status of entity. " + $_)
        } # catch


        ## Check if this entity is compliant with baseline group or not
        if ($ComplianceStatus.status -eq "Compliant") {
            Write-Verbose ("[Update-EntityBaselineGroup]Entity is already compliant with baseline group.")
            Write-Warning ("Entity is already compliant with baseline group, no further action will be taken.")
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
        Write-Verbose ("[Update-EntityBaselineGroup]Host scheduler options set.")

        ## Initialise IntegrityApi.HostUpgradeOptionManagerOptions object and configure
        $hostUpgradeOptions = New-Object IntegrityApi.HostUpgradeOptionManagerOptions
        $hostUpgradeOptions.ignore3rdPartyModules = $false
        $hostUpgradeOptions.ignore3rdPartyModulesSpecified = $true
        Write-Verbose ("[Update-EntityBaselineGroup]Host upgrade options set.")


        ## Phase 2 remediation
        ## Initialise IntegrityApi.VcIntegrityRemediateOption object, consuming phase 1 objects as input
        ## Initialise IntegrityApi.UpdateManagerBaselineGroupUnit which specifies what baseline group and baselines we want to use
        $RemediateOption = New-Object IntegrityApi.VcIntegrityRemediateOption
        $RemediateOption.hostScheduler = $hostScheduler
        $RemediateOption.hostUpgradeOptions = $hostUpgradeOptions
        $BaselineGroupUnit = New-Object IntegrityApi.UpdateManagerBaselineGroupUnit
        $BaselineGroupUnit.baselinegroup = $BaselineGroup.Key
        Write-Verbose ("[Update-EntityBaselineGroup]Remediation option and group unit objects configured.")


        ## Phase 3 remediation
        ## Initialise IntegrityApi.UpdateManagerRemediationSpec object which consumes phase 2 objects as input
        $RemediationSpec = New-Object IntegrityApi.UpdateManagerRemediationSpec
        $RemediationSpec.baselineGroupUnit = $BaselineGroupUnit
        $RemediationSpec.option = $RemediateOption
        Write-Verbose ("[Update-EntityBaselineGroup]Remediation spec configured.")


        ## Phase 4 remediation
        ## The phase 3 object is the completed object we send to the API with Leaf and Entity objects to the UpdateManager
        ## The API will kick back a job object we can monitor for progress
        try {

            ## Apply shouldProcess
            if ($PSCmdlet.ShouldProcess($entity.name)) {

                $MofTask = $vumCon.vumWebService.Remediate_Task($vumCon.vumServiceContent.updateManager, $ParentEntity, $LeafEntity, $RemediationSpec)
            } # if

            Write-Verbose ("[Update-EntityBaselineGroup]Remediation task started.")
        } # try
        catch {
            Write-Debug ("[Update-EntityBaselineGroup]Failed to start remediation task.")
            throw ("Failed to start remediation task. " + $_)
        } # catch


        ## Wait 5 seconds to give task a chance to start
        Start-Sleep 5

        ## Wait for remedaition jopb to complete
        try {
            $jobStatus = Get-Task -id ("Task-" + $MofTask.value) -ErrorAction Stop
        } # try
        catch {
            throw ("Failed to get task object for task " + $MofTask.value)
        } # catch

        Write-Verbose ("[Update-EntityBaselineGroup]Waiting for task to complete.")

        while ($jobStatus.State -eq "Running") {

            Write-Progress -Activity ("Applying Baseline Group to host " + $ESXiHost) -Status ($JobStatus.PercentComplete.ToString() + " percent complete.") -PercentComplete $JobStatus.PercentComplete

            Write-Verbose ("[Update-EntityBaselineGroup]Current task status is " + $jobStatus.State)

            Start-Sleep 10

            try {
                $jobStatus = Get-Task -id ("Task-" + $MofTask.value) -ErrorAction Stop
            } # try
            catch {
                throw ("Failed to get task object for task " + $MofTask.value)
            } # catch

        } # while


        Write-Verbose ("[Update-EntityBaselineGroup]Task completed, verifying result.")


        ## Check the job did not fail
        if ($JobStatus.state -eq "Error") {
            Write-Debug ("[Update-EntityBaselineGroup]Remediation task failed.")
            throw ("Remediation task failed.")
        }

        Write-Verbose ("[Update-EntityBaselineGroup]Task completed successfully.")


        Write-Verbose ("[Update-EntityBaselineGroup]Completed entity " + $entity.name)

    } # process


    end {

        Write-Verbose ("[Update-EntityBaselineGroup]All entities completed.")

        ## Logoff session
        try {
            $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)
            Write-Verbose ("[Update-EntityBaselineGroup]Disconnected from VUM API.")
        } # try
        catch {
            Write-Warning ("[Update-EntityBaselineGroup]Failed to disconnect from VUM API.")
        } # catch


        Write-Verbose ("[Update-EntityBaselineGroup]Function completed.")

    } # end


} # function