function Set-HostRemediationConfig {
    <#
    .SYNOPSIS
        Apply a host remediation configuration to an Update Manager.

        With thanks to Lyuboslav Asenov @ VMWare for providing assistance with new Update Manager API.

    .DESCRIPTION
        Apply a host remediation configuration to an Update Manager.
        The configuration object can be fetched and updated with the Get-HostRemediationConfig and Update-HostRemediation functions respectively.

    .INPUTS
        IntegrityApi.HostRemediationScheduleOption. Host remediation configuration object to apply to the Update Manager instance.

    .OUTPUTS
        None.

    .EXAMPLE
        Set-HostRemediationConfig -HostRemediationConfig $newConfig

        Configure the default VUM host remediation settings as per the configuration object (see Get-HostRemediationConfig and Update-HostRemediation functions).

    .EXAMPLE
        Get-HostRemediationConfig | Update-HostRemediationConfig -HostFailureAction FailTask | Set-HostRemediationConfig

        Use the pipeline to reconfigure VUM default host remediation configuration.

    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       03/01/23     Initial version.                                      A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [IntegrityApi.HostRemediationScheduleOption]$HostRemediationConfig
    )

    Write-Verbose ("Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Verbose ("Got VUM connection.")
    } # try
    catch {
        throw ("Failed to connect to VUM instance. " + $_.Exception.Message)
    } # catch



    ## In addition to the host remediation config, we also need to set guest remediation config.
    ## Since we aren't specifying that here, get the current configuration

    Write-Verbose ("Configuring property collector object.")
    try {
        $sourceObject = New-Object IntegrityApi.ManagedObjectReference -ErrorAction Stop
        $sourceObject.type = "VcIntegrity"
        $sourceObject.Value = "Integrity.VcIntegrity"

        $propertyPaths = "config"

        $objSpec = New-Object IntegrityApi.ObjectSpec -ErrorAction Stop
        $objSpec.obj = $sourceObject
        $propSpec = New-Object IntegrityApi.PropertySpec -ErrorAction Stop
        $propSpec.pathSet = $propertyPaths
        $propSpec.type = $sourceObject.type


        $filterSpec = New-Object IntegrityApi.PropertyFilterSpec -ErrorAction Stop
        $filterSpec.objectSet = $objSpec
        $filterSpec.propSet = $propSpec
    } # try
    catch {
        throw ("Failed to configure property collector object. " + $_.Exception.Message)
    } # catch


    try {
        $propertyCollector = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.propertyCollector
        $reqType = New-Object IntegrityApi.RetrievePropertiesRequestType -ErrorAction Stop
        $reqType._this = $propertyCollector
        $reqType.specSet = $filterSpec

        $svcrefVum = New-Object IntegrityApi.RetrievePropertiesRequest($reqType) -ErrorAction Stop

        ## Get current Update Manager config and append new host remediation config
        $vumConfig  = ($vumCon.vumWebService.RetrieveProperties($svcRefVum)).RetrievePropertiesResponse1.propSet.val
        $vumConfig.hostRemediationScheduleOption = $HostRemediationConfig
    } # try
    catch {
        throw ("Failed to query update manager. " + $_.Exception.Message)
    } # catch

    ## Create the configuration request object
    try {
        $mo = New-Object IntegrityApi.ManagedObjectReference -ErrorAction Stop
        $mo.type = "VcIntegrity"
        $mo.value = "Integrity.VcIntegrity"

        $reqType = New-Object IntegrityApi.SetConfigRequestType
        $reqType._this = $mo
        $reqType.config = $vumConfig
    } # try
    catch {
        throw ("Failed to create the configuration request object. " + $_.Exception.Message)
    } # catch


    ## Send configuration request
    try {
        $svcrefVum = New-Object IntegrityApi.SetConfigRequest($reqType)
        $vumCon.vumWebService.SetConfig($svcrefVum) | Out-Null
    } # try
    catch {
        throw ("Failed to apply configuration. " + $_.Exception.Message)
    } # catch


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

} # function