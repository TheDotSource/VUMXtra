function Get-HostRemediationConfig {
    <#
    .SYNOPSIS
        Get the host remediation configuration from Update Manager.

    .DESCRIPTION
        Get the host remediation configuration from Update Manager.

    .PARAMETER name
        Name of the baseline group to remove.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE


    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       13/12/22     Initial version.                                      A McNair
    #>

    [CmdletBinding()]
    Param
    (
    )

    Write-Verbose ("Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Verbose ("Got VUM connection.")
    } # try
    catch {
        throw ("Failed to connect to VUM instance. The CMDlet returned " + $_.Exception.Message)
    } # catch


    ## Query the "config" property path
    ## This gives us configuration objects for Host Remediation, Guest Remediation Rollback and 3rd party modules

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


    Write-Verbose ("Querying Update Manager for current Host Remediation Settings.")
    
    try {
        $propertyCollector = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.propertyCollector
        $reqType = New-Object IntegrityApi.RetrievePropertiesRequestType -ErrorAction Stop
        $reqType._this = $propertyCollector
        $reqType.specSet = $filterSpec
        
        $svcrefVum = New-Object IntegrityApi.RetrievePropertiesRequest($reqType) -ErrorAction Stop

        $hostRemediationConfig = (($vumCon.vumWebService.RetrieveProperties($svcRefVum)).RetrievePropertiesResponse1.propSet | Where-Object {$_.name -eq "config"}).val.hostRemediationScheduleOption
    } # try
    catch {
        throw ("Failed to query update manager. " + $_.Exception.Message)
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

    ## Return host config
    return $hostRemediationConfig

} # function