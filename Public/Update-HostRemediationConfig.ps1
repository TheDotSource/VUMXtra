function Update-HostRemediationConfig {
    <#
    .SYNOPSIS
        Change a configuration item on a host remediation configuration object.

    .DESCRIPTION
        Change a configuration item on a host remediation configuration object.
        The base configuration object is generate from Get-HostRemediationConfig and can be piped to this function (see examples).
        This can then be used to set the default Update Manager configuration, or at remediation runtime to override Update Manager defaults.

    .PARAMETER HostRemediationConfig
        A host remediation configuration object of type IntegrityApi.HostRemediationScheduleOption.
        This object is generated by Get-HostRemediationConfig (see examples).

    .PARAMETER HostFailureAction
        Optional. Configure action when host maintenance mode fails.
        If specified must also be accompanied by retryDelay and retryAttempts.

    .PARAMETER HostRetryDelaySeconds
        Optional. Set the retry delay for failureAction.

    .PARAMETER HostNumberOfRetries
        Optional. Set the number of retry attempts for failureAction.

    .PARAMETER HostPreRemediationPowerAction
        Optional. Set the action for powered on VMs when a host goes into maintenance mode.

    .PARAMETER ClusterDisableDistributedPowerManagement
        Optional. Temporarily disbale cluster DPM before remediation. After remediation, it will be re-enabled.

    .PARAMETER ClusterDisableHighAvailability
        Optional. Temporarily disbale cluster High Availability before remediation. After remediation, it will be re-enabled.

    .PARAMETER ClusterDisableFaultTolerance
        Optional. Temporarily disbale cluster Fault Tolerance before remediation. After remediation, it will be re-enabled.

    .PARAMETER HostEnablePXEbootHostPatching
        Optional. Enable PXE booting ESXi hosts patching.

    .PARAMETER HostEvacuateOfflineVMs
        Optional. Migrate powered off and suspended VMs to other hosts in the cluster.

    .PARAMETER HostDisableMediaDevices
        Optional. Temporarily disable any media devices that might prevent the specified hosts from entering maintenance mode.

    .PARAMETER HostEnableQuickBoot
        Optional. Enable host quick boot on supported platforms.

    .PARAMETER ClusterEnableParallelRemediation
        Optional. Enable parallel remediation for the specified cluster.

    .PARAMETER ClusterMaxConcurrentRemediations
        Optional. The number of hosts to remediate in parallel. If 0 or not specified, the maximum concurrent remediations will be configured to "automatic".

    .INPUTS
        IntegrityApi.HostRemediationScheduleOption. Host remediation configuration object.

    .OUTPUTS
        IntegrityApi.HostRemediationScheduleOption. Updated host remediation configuration object.

    .EXAMPLE
        $remediationConfig = Get-HostRemediationConfig | Set-HostRemediationConfig -ClusterEnableParallelRemediation $true -ClusterMaxConcurrentRemediations 2

        Create a remediation configuration object. Fetch the current config, then enable parallel remediation specifying a maximum of 2 hosts concurrently.

    .EXAMPLE
        $remediationConfig = Get-HostRemediationConfig | Set-HostRemediationConfig -HostFailureAction Retry -HostRetryDelaySeconds 20 -HostNumberOfRetries 2 -HostEnableQuickBoot $true

        Create a remediation configuration object. Fetch the current config, then set host failure action to retry with a delay of 20 seconds and 2 retries. Enable host Quick Boot.

    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       13/12/22     Initial version.                                      A McNair
    #>

    [OutputType([IntegrityApi.HostRemediationScheduleOption])]
    [CmdletBinding(DefaultParameterSetName="minimalInput")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [IntegrityApi.HostRemediationScheduleOption]$HostRemediationConfig,
        [Parameter(ParameterSetName="retryConfig",Mandatory=$false,ValueFromPipeline=$false)]
        [ValidateSet("Retry","FailTask")]
        [string]$HostFailureAction,
        [Parameter(ParameterSetName="retryConfig",Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateRange(1,6000)]
        [int]$HostRetryDelaySeconds,
        [Parameter(ParameterSetName="retryConfig",Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateRange(1,100)]
        [int]$HostNumberOfRetries,
        [Parameter(ParameterSetName="vmPowerAction",Mandatory=$false,ValueFromPipeline=$false)]
        [ValidateSet("DoNotChangeVMsPowerState","SuspendVMs","PowerOffVMs")]
        [string]$HostPreRemediationPowerAction,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [bool]$ClusterDisableDistributedPowerManagement,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [bool]$ClusterDisableHighAvailability,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [bool]$ClusterDisableFaultTolerance,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [bool]$HostEnablePXEbootHostPatching,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [bool]$HostEvacuateOfflineVMs,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [bool]$HostDisableMediaDevices,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [bool]$HostEnableQuickBoot,
        [Parameter(ParameterSetName="parallelRemediation",Mandatory=$false,ValueFromPipeline=$false)]
        [bool]$ClusterEnableParallelRemediation,
        [Parameter(ParameterSetName="parallelRemediation",Mandatory=$false,ValueFromPipeline=$false)]
        [ValidateRange(0,64)]
        [int]$ClusterMaxConcurrentRemediations
    )

    begin {

        Write-Verbose ("Function start.")

    } # begin


    process {

        ## Examine each parameter in turn and configure object as necessary

        switch ($HostFailureAction) {

            "Retry" {

                Write-Verbose ("Configuring failure action to Retry with a delay of " + $HostRetryDelaySeconds + " seconds and " + $HostNumberOfRetries + " retry attempts.")

                ## Set failure action to Retry
                $hostRemediationConfig.failureAction = "Retry"

                ## We also need to set the retry delay and retry attempts
                Write-Verbose ("Setting Retry Delay to " + $HostRetryDelaySeconds)
                $hostRemediationConfig.retryDelay = $HostRetryDelaySeconds
                $hostRemediationConfig.retryDelaySpecified = $true

                Write-Verbose ("Setting Retry Attempts to " + $HostNumberOfRetries)
                $hostRemediationConfig.numberOfRetries = $HostNumberOfRetries
                $hostRemediationConfig.numberOfRetriesSpecified = $true

            } # retry

            "FailTask" {
                Write-Verbose ("Configuring failure action to Fail Task.")

                ## Set failure action to FailTask
                $hostRemediationConfig.failureAction = "FailTask"

                $hostRemediationConfig.retryDelaySpecified = $false
                $hostRemediationConfig.numberOfRetriesSpecified = $false

            } # failTask

        } # switch


        ## Check if a VM power action has been specified
        if ($HostPreRemediationPowerAction) {

            $hostRemediationConfig.preRemediationPowerAction = $HostPreRemediationPowerAction
            Write-Verbose ("VM power action has been set to " + $HostPreRemediationPowerAction)

        } # if


        ## Check if disable DPM has been specified.
        if ($null -ne $ClusterDisableDistributedPowerManagement) {

            Write-Verbose ("Setting Disable DPM to " + $ClusterDisableDistributedPowerManagement)
            $hostRemediationConfig.disableDpm = $ClusterDisableDistributedPowerManagement
            $hostRemediationConfig.disableDpmSpecified = $true

        } # if


        ## Check if disable HAC has been specified.
        if ($null -ne $ClusterDisableHighAvailability) {

            Write-Verbose ("Setting Disable DPM to " + $ClusterDisableHighAvailability)
            $hostRemediationConfig.disableHac = $ClusterDisableHighAvailability
            $hostRemediationConfig.disableHacSpecified = $true

        } # if


        ## Check if disable FT has been specified.
        if ($null -ne $ClusterDisableFaultTolerance) {

            Write-Verbose ("Setting Disable DPM to " + $ClusterDisableFaultTolerance)
            $hostRemediationConfig.disableFt = $ClusterDisableFaultTolerance
            $hostRemediationConfig.disableFtSpecified = $true

        } # if


        ## Check if allow PXE booted hosts has been specified.
        if ($null -ne $HostEnablePXEbootHostPatching) {

            Write-Verbose ("Setting Allow PXE Booted Hosts to " + $HostEnablePXEbootHostPatching)
            $hostRemediationConfig.allowStatelessRemediation = $HostEnablePXEbootHostPatching
            $hostRemediationConfig.allowStatelessRemediationSpecified = $true

        } # if


        ## Check if evacuateOfflineVMs has been specified.
        if ($null -ne $HostEvacuateOfflineVMs) {

            Write-Verbose ("Setting Evacuate Powered Off and Suspended VMs to " + $HostEvacuateOfflineVMs)
            $hostRemediationConfig.evacuateOfflineVMs = $HostEvacuateOfflineVMs
            $hostRemediationConfig.evacuateOfflineVMsSpecified = $true

        } # if


        ## Check if disconnectRemovableDevices has been specified.
        if ($null -ne $HostDisableMediaDevices) {

            Write-Verbose ("Setting Disconnect Removable Devices to " + $HostDisableMediaDevices)
            $hostRemediationConfig.disconnectRemovableDevices = $HostDisableMediaDevices
            $hostRemediationConfig.disconnectRemovableDevicesSpecified = $true

        } # if


        ## Check if enableQuickBoot has been specified.
        if ($null -ne $HostEnableQuickBoot) {

            Write-Verbose ("Setting Enable Quick Boot to " + $HostEnableQuickBoot)
            $hostRemediationConfig.enableLoadEsx = $HostEnableQuickBoot
            $hostRemediationConfig.enableLoadEsxSpecified = $true

        } # if


        ## Check if parallelRemediation has been specified.
        if ($null -ne $ClusterEnableParallelRemediation) {

            Write-Verbose ("Setting Parallel Remediation to " + $ClusterEnableParallelRemediation)
            $hostRemediationConfig.concurrentRemediationInCluster = $ClusterEnableParallelRemediation
            $hostRemediationConfig.concurrentRemediationInClusterSpecified = $true
            $hostRemediationConfig.enableParallelRemediateOfMMHosts = $ClusterEnableParallelRemediation
            $hostRemediationConfig.enableParallelRemediateOfMMHostsSpecified = $true

            ## Check ClusterMaxConcurrentRemediations. If it's not specified, or the value is 0, we set to automatic.
            if ((!$ClusterMaxConcurrentRemediations) -or ($ClusterMaxConcurrentRemediations -eq 0)) {

                $hostRemediationConfig.maxHostsForParallelRemediationInCluster = 0
                $hostRemediationConfig.maxHostsForParallelRemediationInClusterSpecified = $true

            } # if
            else {

                $hostRemediationConfig.maxHostsForParallelRemediationInCluster = $ClusterMaxConcurrentRemediations
                $hostRemediationConfig.maxHostsForParallelRemediationInClusterSpecified = $true

            } # else

        } # if


        ## We are done, return completed configuration object
        return $hostRemediationConfig

    } # process

    end {

        Write-Verbose ("Function completed.")

    } # end

} # function