function New-BaselineGroup {
    <#
    .SYNOPSIS
        Creates a new baseline group.
    .DESCRIPTION
        This function is part of a module that addresses gaps in the VUM PowerCLI CMDlets.
        The VCItegrity private API is used.
        This function will create an empty Baseline Group on the target VUM server.
        Returns a Baseline Group object with associated ID.
    .EXAMPLE
        New-BaselineGroup -Name "Sample Baseline Group" -Description "Example Baseline Group"

        Create a new baseline group called Sample Baseline Group with description Example Baseline Group.
    .NOTES
        01       17/10/18     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$Name,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [String]$Description
    )

    Write-Debug ("[New-BaselineGroup]Function start.")

    ## Get a VUM service connection object
    try {
        $vumCon = Connect-VUM -ErrorAction stop
        Write-Debug ("[Remove-BaselineGroup]Got VUM connection.")
    } # try
    catch {
        Write-Debug ("[Remove-BaselineGroup]Failed to connect to VUM instance.")
        throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)  
    } # catch


    ## Check if this baseline group already exists
    $BaseLineGroupInfo = New-Object IntegrityApi.BaselineGroupManagerBaselineGroupInfo

    for ($i=0; $i -le 100; $i++) {
        
        if ($vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)) {

            $BaselineGroup = $vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)

            ## If baseline group name matches Name parameter add it and break the loop
            if ($Name -eq $BaselineGroup.name) {

                Write-Debug ("[New-BaselineGroup]Existing baseline group found.")

                ## This baseline group already exists, exit
                Throw ("This baseline group already exists on this VUM instance.")

            } # if

        } # if

    } # for


    ## Create a new baseline group
    try {
        $BaseLineGroupSpec = New-Object IntegrityApi.BaselineGroupManagerBaselineGroupSpec
        $BaseLineGroupSpec.name = $Name    
        $BaseLineGroupSpec.description = $Description
        $BaseLineGroupSpec.targetType = "HOST"
        $VCResult = $vumCon.vumWebService.CreateBaseLineGroup($vumCon.vumServiceContent.baselineGroupManager, $BaseLineGroupSpec)
    } # try
    catch {
        throw ("Error creating baseline group. " + $_)
    } # catch

    ## Generate return object
    $BLObject = @{"Name" = $Name; "Description" = $Description; "Id" = $VCResult}


    ## Logoff session
    $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)


    return $BLObject

} # function