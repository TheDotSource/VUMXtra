function New-BaselineGroup {
    <#
    .SYNOPSIS
        Creates a new baseline group.

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

        Write-Verbose ("[New-BaselineGroup]Function start.")

        ## Get a VUM service connection object
        try {
            $vumCon = Connect-VUM -ErrorAction stop
            Write-Verbose ("[New-BaselineGroup]Got VUM connection.")
        } # try
        catch {
            Write-Debug ("[New-BaselineGroup]Failed to connect to VUM instance.")
            throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)
        } # catch

    } # begin

    process {

        Write-Verbose ("[New-BaselineGroup]Creating baseline group " + $name)

        ## Check if this baseline group already exists
        for ($i=0; $i -le 100; $i++) {

            if ($vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)) {

                $BaselineGroup = $vumCon.vumWebService.GetBaselineGroupInfo($vumCon.vumServiceContent.baselineGroupManager,$i)

                ## If baseline group name matches Name parameter add it and break the loop
                if ($Name -eq $BaselineGroup.name) {

                    Write-Verbose ("[New-BaselineGroup]Existing baseline group found.")

                    ## This baseline group already exists, exit
                    Throw ("This baseline group already exists on this VUM instance.")

                } # if

            } # if

        } # for


        ## Create a new baseline group
        try {
            $BaseLineGroupSpec = New-Object IntegrityApi.BaselineGroupManagerBaselineGroupSpec
            $BaseLineGroupSpec.name = $name
            $BaseLineGroupSpec.description = $description
            $BaseLineGroupSpec.targetType = "HOST"

            ## Apply shouldProcess
            if ($PSCmdlet.ShouldProcess($name)) {

                $VCResult = $vumCon.vumWebService.CreateBaseLineGroup($vumCon.vumServiceContent.baselineGroupManager, $BaseLineGroupSpec)
            } # if

        } # try
        catch {
            throw ("Error creating baseline group. " + $_)
        } # catch


        ## Generate return object
        $blObject = [pscustomobject]@{"Name" = $name; "Description" = $description; "Id" = $VCResult}


        Write-Verbose ("[New-BaselineGroup]Completed baseline group " + $name)


        ## Return object
        return $blObject


    } # process

    end {

        Write-Verbose ("[New-BaselineGroup]All baseline groups created.")

        ## Logoff session
        try {
            $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)
            Write-Verbose ("[New-BaselineGroup]Disconnected from VUM API.")
        } # try
        catch {
            Write-Warning ("[New-BaselineGroup]Failed to disconnect from VUM API.")
        } # catch


        Write-Verbose ("[New-BaselineGroup]Function completed.")

    } # end

} # function