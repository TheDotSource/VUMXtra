function Update-EntityBaselineGroup {
    <#
    .SYNOPSIS
        Remediates a host against a baseline group.

        With thanks to Lyuboslav Asenov @ VMWare for providing assistance with new Update Manager API.

    .DESCRIPTION
        Makes a call to the VC Integrity API to remediate a host or cluster against a baseline group.

    .PARAMETER baselineGroupName
        Name of the baseline group to remediate against.

    .PARAMETER entity
        Entity object to remediate against, either a host or a cluster.

    .PARAMETER HostRemediationConfig
        Optional. Host remediation configuration object. If this is not specified, the default Update Manager host remediation settings are used.
        To override the default configuration at remediation runtime, generate a custom configuration object using the Update-HostRemediationConfig function.

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
        01       13/11/18     Initial version.                                             A McNair
        02       23/12/19     Tidied up synopsis and added verbose output.                 A McNair
                              Added pipeline input for entity.
        03       22/12/22     Reworked for PowerCLI 12.7 and new API.                      A McNair
                              Added support for clusters.
                              Added option to override default host remediation settings.
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Medium")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$baselineGroupName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [ValidateScript({($_.GetType().toString() -eq "VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl") -or ($_.GetType().toString() -eq "VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl")})]
        [PSObject]$entity,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [IntegrityApi.HostRemediationScheduleOption]$HostRemediationConfig
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

        ## Initialise array for leaf entities
        $leafEntities = @()


        ## Things work a little differently depending on cluster or host target entity
        switch ($entity) {

            {$_.GetType().toString() -eq "VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl"} {

                ## Leaf entity is the target host
                $leafTypeValue = $entity.id.split("-",2)
                $leafEntity = New-Object IntegrityApi.ManagedObjectReference
                $leafEntity.type = $leafTypeValue[0]
                $leafEntity.Value = $leafTypeValue[1]
                $leafEntities += $leafEntity

                ## Parent entity is the cluster this host belongs to.
                $parentTypeValue = $entity.ParentId.split("-",2)
                $parentEntity = New-Object IntegrityApi.ManagedObjectReference
                $parentEntity.type = $parentTypeValue[0]
                $parentEntity.Value = $parentTypeValue[1]

                ## Specify an entity that we want to check compliance on
                $complianceEntity = $leafEntity

            } # host

            {$_.GetType().toString() -eq "VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl"} {

                ## Get all hosts belonging to this cluster
                Write-Verbose ("Entity type is cluster. Getting hosts in this cluster.")

                try {
                    $vmHosts = $entity | Get-vmHost -ErrorAction Stop
                    Write-Verbose ("Got " + $vmHosts.count + " hosts.")
                } # try
                catch {
                    throw ("Failed to get hosts from tagret cluster. " + $_.Exception.Message)
                } # catch


                ## Leaf objects are hosts in this cluster. Create an array of these leaf entities
                foreach ($vmHost in $vmHosts) {

                    $leafTypeValue = $vmHost.id.split("-",2)
                    $leafEntity = New-Object IntegrityApi.ManagedObjectReference
                    $leafEntity.type = $leafTypeValue[0]
                    $leafEntity.Value = $leafTypeValue[1]

                    $leafEntities += $leafEntity

                } # foreach

                ## Parent entity is the target cluster
                $parentTypeValue = $entity.id.split("-",2)
                $parentEntity = New-Object IntegrityApi.ManagedObjectReference
                $parentEntity.type = $parentTypeValue[0]
                $parentEntity.Value = $parentTypeValue[1]

                ## Specify an entity that we want to check compliance on
                $complianceEntity = $parentEntity

            } # cluster

        } # switch


        ## Initiate a scan of the host or cluster
        try {
            Test-Compliance -Entity $entity -ErrorAction Stop | Out-Null
        } # try
        catch {
            throw ("Compliance scan failed on entity. " + $_.Exception.Message)
        } # catch


        ## Query compliance status for specified baseline group
        try {

            $reqType = New-Object IntegrityApi.QueryBaselineGroupComplianceStatusRequestType
            $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.complianceStatusManager
            $reqType.entity = $complianceEntity

            $svcRefVum = New-Object IntegrityApi.QueryBaselineGroupComplianceStatusRequest($reqType)
            $complianceStatus = ($vumCon.vumWebService.QueryBaselineGroupComplianceStatus($svcRefVum)).QueryBaselineGroupComplianceStatusResponse1 | Where-Object {$_.key -eq $baselineGroup.key}

            Write-Verbose ("Obtained entity compliance status.")
        } # try
        catch {
            throw ("Failed to query compliance status of entity. " + $_.Exception.Message)
        } # catch

        ## Check if this entity is compliant with baseline group or not
        if ($complianceStatus.status -eq "Compliant") {
            Write-Verbose ("Entity is already compliant with baseline group. No further action is required.")
            Break
        } # if


        ## Phase 1 remediation
        ## Initialise IntegrityApi.HostRemediationScheduleOption object and configure
        ## Check is a config object has been supplied, or if we need to pull the configuration from Update Manager defaults.
        if ($HostRemediationConfig) {

            Write-Verbose ("A host remediation configuration object has been specified and will be applied to this remediation.")
        } # if
        else {

            Write-Verbose ("Using Update Manager default host remediation configuration.")

            try {
                $HostRemediationConfig = Get-HostRemediationConfig -ErrorAction Stop
                Write-Verbose ("Successfully queried Update Manager for host remediation settings.")
            } # try
            catch {
                throw ("Failed to query Update Manager for host remediation settings. " + $_.Exception.Message)
            } # catch

        } # else


        ## Initialise IntegrityApi.HostUpgradeOptionManagerOptions object and configure
        $hostUpgradeOptions = New-Object IntegrityApi.HostUpgradeOptionManagerOptions
        $hostUpgradeOptions.ignore3rdPartyModules = $false
        $hostUpgradeOptions.ignore3rdPartyModulesSpecified = $true
        Write-Verbose ("Host upgrade options set.")


        ## Phase 2 remediation
        ## Initialise IntegrityApi.VcIntegrityRemediateOption object, consuming phase 1 objects as input
        ## Initialise IntegrityApi.UpdateManagerBaselineGroupUnit which specifies what baseline group and baselines we want to use
        $remediateOption = New-Object IntegrityApi.VcIntegrityRemediateOption
        $remediateOption.hostScheduler = $HostRemediationConfig
        $remediateOption.hostUpgradeOptions = $hostUpgradeOptions
        $baselineGroupUnit = New-Object IntegrityApi.UpdateManagerBaselineGroupUnit
        $baselineGroupUnit.baselinegroup = $baselineGroup.Key
        Write-Verbose ("Remediation option and group unit objects configured.")


        ## Phase 3 remediation
        ## Initialise IntegrityApi.UpdateManagerRemediationSpec object which consumes phase 2 objects as input
        $remediationSpec = New-Object IntegrityApi.UpdateManagerRemediationSpec
        $remediationSpec.baselineGroupUnit = $baselineGroupUnit
        $remediationSpec.option = $remediateOption
        Write-Verbose ("Remediation spec configured.")


        ## Phase 4 remediation
        ## The phase 3 object is the completed object we send to the API with Leaf and Entity objects to the UpdateManager
        ## The API will kick back a job object we can monitor for progress
        try {

            ## Apply shouldProcess
            if ($PSCmdlet.ShouldProcess($entity.name)) {

                $updateManager = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.updateManager

                $reqType = New-Object IntegrityApi.RemediateRequestType
                $reqType._this = $updateManager
                $reqType.entity = $parentEntity
                $reqType.leafEntity = $leafEntities
                $reqType.spec = $remediationSpec

                $mofTask = ($vumCon.vumWebService.Remediate_Task($reqType)).Remediate_TaskResponse.returnval

            } # if

            Write-Verbose ("Remediation task started.")

        } # try
        catch {
            throw ("Failed to start remediation task. " + $_.Exception.Message)
        } # catch


        ## Wait 5 seconds to give task a chance to start
        Start-Sleep 5

        ## Wait for remedaition job to complete
        try {
            $jobStatus = Get-Task -id ("Task-" + $MofTask.value) -ErrorAction Stop
        } # try
        catch {
            throw ("Failed to get task object for task " + $MofTask.value)
        } # catch

        Write-Verbose ("Waiting for task to complete.")

        while ($jobStatus.State -eq "Running") {

            Write-Progress -Activity ("Applying Baseline Group to entity " + $entity.name) -Status ($jobStatus.PercentComplete.ToString() + " percent complete.") -PercentComplete $jobStatus.PercentComplete

            Write-Verbose ("Current task status is " + $jobStatus.State)

            Start-Sleep 10

            try {
                $jobStatus = Get-Task -id ("Task-" + $MofTask.value) -ErrorAction Stop
            } # try
            catch {
                throw ("Failed to get task object for task " + $MofTask.value)
            } # catch

        } # while


        Write-Verbose ("Task completed, verifying result.")


        ## Check the job did not fail
        if ($JobStatus.state -eq "Error") {
            throw ("Remediation task failed.")
        }

        Write-Verbose ("Task completed successfully.")
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