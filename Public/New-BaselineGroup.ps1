function New-BaselineGroup {
    <#
    .SYNOPSIS
        Creates a new baseline group.

        With thanks to Lyuboslav Asenov @ VMWare for providing assistance with new Update Manager API.

    .DESCRIPTION
        Makes a call to the VC Integrity API to create a new baseline group.

    .PARAMETER name
        The name of the new baseline group.

    .PARAMETER description
        The description of the new baseline group. Optional.

    .INPUTS
        System.String. The name of the baseline group to create.

    .OUTPUTS
        System.Management.Automation.PSCustomObject. Object representing the baseline group.

    .EXAMPLE
        New-BaselineGroup -Name "Sample Baseline Group" -Description "Example Baseline Group"

        Create a new baseline group called Sample Baseline Group with description Example Baseline Group.

    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       17/10/18     Initial version.                                       A McNair
        02       23/12/19     Tidied up synopsis and added verbose output.           A McNair
                              Added pipeline input for baseline group name.
        03       30/11/22     Reworked for PowerCLI 12.7 and new API                 A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [String]$name,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [String]$description
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

    } # begin

    process {

        Write-Verbose ("Creating baseline group " + $name)

        $reqType = New-Object IntegrityApi.GetBaselineGroupInfoRequestType
        $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.baselineGroupManager


        ## Check if this baseline group already exists
        Write-Verbose ("Verifying baseline group does not already exist.")

        for ($i=0; $i -le 100; $i++) {

            $reqType.id = $i

            try {
                $svcRefVum = New-Object IntegrityApi.GetBaselineGroupInfoRequest($reqType) -ErrorAction Stop
                $result = $vumCon.vumWebService.GetBaselineGroupInfo($svcRefVum)

                $baselineGroup  = $result.GetBaselineGroupInfoResponse1

            } # try
            catch {
                throw ("Failed to query for baseline group. " + $_.Exception.message)
            } # catch


            if ($name -eq $baselineGroup.name) {

                Write-Verbose ("Existing baseline group found.")

                ## This baseline group already exists, exit
                throw ("This baseline group already exists on this VUM instance.")

            } # if

        } # for


        ## Create a new baseline group
        try {
            $baseLineGroupSpec = New-Object IntegrityApi.BaselineGroupManagerBaselineGroupSpec -ErrorAction Stop
            $baseLineGroupSpec.name = $name
            $baseLineGroupSpec.description = $description
            $baseLineGroupSpec.targetType = "HOST"

            ## Apply shouldProcess
            if ($PSCmdlet.ShouldProcess($name)) {

                $reqType = New-Object IntegrityApi.CreateBaselineGroupRequestType -ErrorAction Stop
                $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.baselineGroupManager
                $reqType.spec = $baseLineGroupSpec


                $svcRefVum = New-Object IntegrityApi.CreateBaselineGroupRequest($reqType) -ErrorAction Stop
                $vcResult = ($vumCon.vumWebService.CreateBaselineGroup($svcRefVum)).CreateBaselineGroupResponse.returnval

            } # if

        } # try
        catch {
            throw ("Error creating baseline group. " + $_.Exception.Message)
        } # catch


        ## Generate return object
        $blObject = [pscustomobject]@{"Name" = $name; "Description" = $description; "Id" = $VCResult}


        Write-Verbose ("Completed baseline group " + $name)


        ## Return object
        return $blObject


    } # process

    end {

        Write-Verbose ("All baseline groups created.")

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