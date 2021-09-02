function Import-VUMContent {
    <#
    .SYNOPSIS
        This function imports an ESXi image or patch to a VUM instance.

    .DESCRIPTION
        This function uses a combination of file copy and VC Integrity API to perform content import on a VUM instance.
        The file is first copied to either a Windows instance or VCSA to a known location on the local file system.
        On Windows, this is done via UNC. On the VCSA, a VM tools file copy or a CURL command will be used to copy content.
        The VC Integrity API is then used to import the content to VUM.

    .PARAMETER VUMType
        Either Windows or VCSA. This will unlock a conditional parameter set to collect appropriate details for each.

    .PARAMETER FilePath
        The path to the file to be imported to VUM. This may be a local path or an HTTP URL (VCSA only).

    .PARAMETER ImportType
        Use Image to import an ISO, and Patch to import patch content.

    .PARAMETER WindowsHost
        Required if Windows was specified as VUM type. The hostname of the Windows system that hosts VUM.

    .PARAMETER WinCred
        Required if Windows was specified as VUM type. The credential object with appropriate permissions to perform a UNC copy.

    .PARAMETER VCSAVM
        Required if VCSA was specified as VUM type. The VM name of the VCSA hosting VUM.

    .PARAMETER VCSACred
        Required if VCSA was specified as VUM type. Root credentials for the VCSA VM to allow VM tools to perform a file copy.

    .PARAMETER vumVI
        Optional if VCSA was specified as VUM type. Should be used if there is more then one VI connection.
        More than one VI connection can be used in scanarios where the VCSA does not manage it's own VM object.

    .EXAMPLE
        Import-VUMContent -ImageFile E:\VUM\Patches\ESXi650-201810001.zip -VUMType VCSA -ImportType Patch -VCSAVM VCSA60-02 -VCSACred (Get-Credential)

        Import a patch to a VCSA integrated VUM instance.

    .EXAMPLE
        Import-VUMContent -ImageFile E:\VUM\Patches\ESXi650-201810001.zip -VUMType Windows -ImportType Patch -WindowsHost WINVUM01 -WinCred (Get-Credential)

        Import a patch to a Windows VUM instance.

    .EXAMPLE
        Import-VUMContent -ImageFile E:\VUM\Images\VMware-VMvisor-Installer-6.0.0.update03-5050593.x86_64.iso -VUMType VCSA -ImportType Image -VCSAVM VCSA60-02 -VCSACred (Get-Credential)

        Import an image to a VCSA integrated VUM instance.

    .EXAMPLE
        Import-VUMContent -VUMType VCSA -FilePath E:\VUM\Images\VMware-VMvisor-Installer-6.7.0.update03-14320388.x86_64.iso -ImportType Image -VCSAVM DEVVCSA -VCSACred $rootCred -vumVI devvcsa.lab.local -Verbose

        This is an example of a content import to a VUM instance where the vCenter does not manage it's own VM object.
        This command is run in the context of having 2 VI connections, one to the VCSA that manages DEVVCSA, and another VI connection devvcsa.lab.local
        This allows VM tools to import to DEVVCSA, and the API call to be made to devvcsa.lab.local

    .EXAMPLE
        Import-VUMContent -VUMType VCSA -FilePath http://vumcontent.local/VMware-VMvisor-Installer-6.7.0.update03-14320388.x86_64.iso -ImportType Image -VCSAVM DEVVCSA -VCSACred $rootCred -vumVI devvcsa.lab.local -Verbose

        This is an example of a content import to a VUM instance where the vCenter does not manage it's own VM object.
        This command is run in the context of having 2 VI connections, one to the VCSA that manages DEVVCSA, and another VI connection devvcsa.lab.local
        A remote script will be executed to CURL down the ISO file to the appliance where an it can then be imported.

    .LINK
        https://github.com/TheDotSource/VUMXtra

    .NOTES
        01       14/11/18     Initial version.                                                                                A McNair
        02       29/11/18     Changed file copy for Windows VUM from UNC to PS Drive so a credential can be specifed.         A McNair
        03       23/12/19     Tidied up synopsis and added verbose output.                                                    A McNair
                              Added additonal parameter vumVI to allow for content import to non-self managed VCSA's
        04       02/09/21     Added support for content from an HTTP location.                                                A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=0)]
        [ValidateSet("Windows","VCSA")]
        [string]$VUMType,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=1)]
        [String]$FilePath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=2)]
        [ValidateSet("Patch","Image")]
        [string]$ImportType
    )


    DynamicParam {

        ## Dynamic paramter set used to handle different sceanrios between Windows and VCSA

        switch ($VUMType) {

           "Windows" {
                  ## Create a new ParameterAttribute Object
                  $WinAtrrib = New-Object System.Management.Automation.ParameterAttribute
                  $WinAtrrib.Mandatory = $true
                  $WinAtrrib.Position = 3
                  $WinCredAttrib = New-Object System.Management.Automation.ParameterAttribute
                  $WinCredAttrib.Mandatory = $true
                  $WinCredAttrib.Position = 4

                  ## Create an attributecollection object for the attribute we just created.
                  $attributeCollection1 = new-object System.Collections.ObjectModel.Collection[System.Attribute]
                  $attributeCollection2 = new-object System.Collections.ObjectModel.Collection[System.Attribute]

                  ## Add custom attribute
                  $attributeCollection1.Add($WinAtrrib)
                  $attributeCollection2.Add($WinCredAttrib)

                  ## Add our paramater specifying the attribute collection
                  $WindowsHost = New-Object System.Management.Automation.RuntimeDefinedParameter('WindowsHost', [string], $attributeCollection1)
                  $WinCred = New-Object System.Management.Automation.RuntimeDefinedParameter('WinCred', [PSObject], $attributeCollection2)

                  ## Expose the name of our parameter
                  $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                  $paramDictionary.Add('WindowsHost', $WindowsHost)
                  $paramDictionary.Add('WinCred', $WinCred)
            } # Windows

            "VCSA" {
                  ## Create a new ParameterAttribute Object
                  $VCSAVMAtrrib = New-Object System.Management.Automation.ParameterAttribute
                  $VCSAVMAtrrib.Mandatory = $true
                  $VCSAVMAtrrib.Position = 3
                  $VCSACredAtrrib = New-Object System.Management.Automation.ParameterAttribute
                  $VCSACredAtrrib.Mandatory = $true
                  $VCSACredAtrrib.Position = 4
                  $vumVCSAAtrrib = New-Object System.Management.Automation.ParameterAttribute
                  $vumVCSAAtrrib.Mandatory = $false
                  $vumVCSAAtrrib.Position = 5


                  ## Create an attributecollection object for the attribute we just created.
                  $attributeCollection1 = new-object System.Collections.ObjectModel.Collection[System.Attribute]
                  $attributeCollection2 = new-object System.Collections.ObjectModel.Collection[System.Attribute]
                  $attributeCollection3 = new-object System.Collections.ObjectModel.Collection[System.Attribute]

                  ## Add custom attribute
                  $attributeCollection1.Add($VCSAVMAtrrib)
                  $attributeCollection2.Add($VCSACredAtrrib)
                  $attributeCollection3.Add($vumVCSAAtrrib)

                  ## Add our paramater specifying the attribute collection
                  $VCSAVM = New-Object System.Management.Automation.RuntimeDefinedParameter('VCSAVM', [string], $attributeCollection1)
                  $VCSACred = New-Object System.Management.Automation.RuntimeDefinedParameter('VCSACred', [PSObject], $attributeCollection2)
                  $vumVI = New-Object System.Management.Automation.RuntimeDefinedParameter('vumVI', [PSObject], $attributeCollection3)

                  ## Expose the name of our parameter
                  $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                  $paramDictionary.Add('VCSAVM', $VCSAVM)
                  $paramDictionary.Add('VCSACred', $VCSACred)
                  $paramDictionary.Add('vumVI', $vumVI)
            } # VCSA

        } # switch

        return $paramDictionary

    } # DynamicParam


    process {

        Write-Verbose ("[Import-VUMContent]Function start.")

        ## Get a VUM service connection object
        try {
            $vumCon = Connect-VUM -vumVI $vumVI.Value -ErrorAction Stop
            Write-Verbose ("[Import-VUMContent]Got VUM connection.")
        } # try
        catch {
            Write-Debug ("[Import-VUMContent]Failed to connect to VUM instance.")
            throw ("Failed to connect to VUM instance. The CMDlet returned " + $_)
        } # catch


        ## Create import spec object
        [IntegrityApi.FileUploadManagerFileUploadSpec] $importSpec = New-Object IntegrityApi.FileUploadManagerFileUploadSpec
        $importSpec.SessionId = ""


        ## Change if patch or image
        switch ($ImportType) {

            "Image" {
                $importSpec.FileFunctionalType = "Upgrade"
                $importSpec.OpType = "UploadAndConfirm"
            } # Image

            "Patch" {
                $importSpec.FileFunctionalType = "Patch"
                $importSpec.OpType = "Upload"
            } # Patch

        } # switch


        ## Get filename from path
        $FileName = Split-Path $FilePath -Leaf


        ## Copy image file to Windows or VCSA
        switch ($VUMType) {

            "Windows" {

                Write-Verbose ("[Import-VUMContent]Windows VUM instance has been specified. Copy will take place via UNC.")

                Write-Verbose ("Copy will performed under user account " + $WinCred.username)

                ## Create new PS Drive object to Windows UNC
                try {
                    New-PSDrive VUMIMPORT -PSProvider FileSystem -Root ("\\" + $WindowsHost.value + "\c$") -Credential $WinCred.value -ErrorAction Stop | Out-Null
                    Write-Verbose ("[Import-VUMContent]Created new PS drive.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to create PS Drive to UNC.")
                    throw ("Failed to create PS drive to UNC. " + $_)
                } # catch


                ## Create remote VUMImport folder
                try {
                    New-Item -ItemType Directory -Path VUMIMPORT:\VUMImport -Force -ErrorAction Stop | Out-Null
                    Write-Verbose ("[Import-VUMContent]VUM import folder created.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to create VUM import folder." + $_)
                    throw ("Failed to create VUM import folder. " + $_)
                } # catch


                ## Copy file to import folder
                try {
                    Copy-Item -Path $FilePath -Destination ("\\" + $WindowsHost.value + "\c$\VUMImport\" + $FileName) -Force -ErrorAction Stop | Out-Null
                    Write-Verbose ("[Import-VUMContent]Content file copied.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to copy content file.")
                    throw ("Failed to copy image file. " + $_)
                } # catch


                ## Remove PS Drive
                try {
                    Remove-PSDrive -Name VUMIMPORT -ErrorAction Stop | Out-Null
                    Write-Verbose ("[Import-VUMContent]Removed PS drive.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to remove PS drive.")
                    throw ("Failed to remove PS drive. " + $_)
                } # catch


                ## Set file import spec path for Windows
                $importSpec.FilePath = ("c:\VUMImport\" + $FileName)
            } # Windows

            "VCSA" {

                Write-Verbose ("[Import-VUMContent]VCSA VUM instance has been specified. File copy will take place via VM tools.")

                ## Get VM object for VCSA
                try {
                    $VCSAVMObject = Get-VM -Name $VCSAVM.value -Erroraction Stop
                    Write-Verbose ("[Import-VUMContent]Got VM object for VCSA.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to get VM.")
                    throw ("Failed to get VM object for VCSA. " + $_)
                } # catch


                ## If path starts with HTTP or HTTPS, we'll use a remote CURL command to pull down content.
                ## If not, we'll use VM tools to invoke a file copy.

                switch -Wildcard ($FilePath) {

                    ## Is an HTTP URL, use CURL
                    "http*" {

                        ## Issue a CURL command via VM tools to download the ISO to the patch import folder
                        Write-Verbose ("[Import-VUMContent]HTTP path detected. Downloading ISO to target appliance from " + $FilePath)

                        $remoteCmd = ("curl " + $FilePath + " --output /storage/updatemgr/patch-store-temp/" + $FileName + " --fail")

                        try {
                            $scriptOutput = Invoke-VMScript -ScriptText $remoteCmd -VM $VCSAVMObject -GuestCredential $VCSACred.value
                            Write-Verbose ("[Import-VUMContent]Remote script execution completed.")
                        } # try
                        catch {
                            throw ("Attempt to execute remote script failed. " + $_.exception.message)
                        } # catch

                        ## Check script exit code is 0, i.e. no errors thrown.
                        if ($scriptOutput.ExitCode -ne 0) {
                            throw ("Attempt to download ISO to appliance failed. CURL exit code was " + $scriptOutput.ExitCode + ". The script output was " + $scriptOutput.ScriptOutput)
                        } # if

                    } # http

                    ## Is a conventional path, use VM tools file copy
                    default {

                        ## Copy file to VCSA path using VM tools
                        try {
                            Copy-VMGuestFile -Source $FilePath -Destination "/storage/updatemgr/patch-store-temp/$($FileName)" -LocalToGuest -VM $VCSAVMObject -GuestCredential $VCSACred.value -force -ErrorAction Stop
                            Write-Verbose ("[Import-VUMContent]File copied to VCSA.")
                        } # try
                        catch {
                            Write-Debug ("[Import-VUMContent]Failed to copy file to VCSA.")
                            throw ("Failed to copy file to VCSA. " + $_.exception.message)
                        } # catch

                    } # default

                } # switch

                ## Set file import spec path for VCSA
                $importSpec.FilePath = ("/storage/updatemgr/patch-store-temp/$($FileName)")
            } # VCSA

        } # switch


        ## Start import
        try {
            $taskMoRef = $vumCon.vumWebService.ImportFile_Task($vumCon.vumServiceContent.fileUploadManager, $importSpec)
            Write-Verbose ("[Import-VUMContent]Import task started.")
        } # try
        catch {
            Write-Debug ("[Import-VUMContent]Failed to import image file.")
            throw ("Failed to import file. " + $_)
        } # catch


        ## Get task
        $taskId = $taskMoRef.type + "-" + $taskMoRef.value

        try {
            $Task = Get-Task -Id $taskId -ErrorAction Stop
            Write-Verbose ("[Import-VUMContent]Got task object for import.")
        } # try
        catch {
            Write-Debug ("[Import-VUMContent]Failed to get task.")
            throw ("Failed to get task object. " + $_)
        } # catch


        ## Wait for task to complete
        Write-Verbose ("Waiting on import task to complete.")
        Wait-Task -Task $Task | Out-Null


        ## Get task result
        try {
            $Task = Get-Task -Id $taskId -ErrorAction Stop
            Write-Verbose ("[Import-VUMContent]Got task object, verifying status.")
        } # try
        catch {
            Write-Debug ("[Import-VUMContent]Failed to get task.")
            throw ("Failed to get task object. " + $_)
        } # catch


        ## Get task result
        if ($Task.state -ne "Success") {
            Write-Debug ("[Import-VUMContent]Import task failed.")
            throw ("Image import task failed with status " + $Task.State)
        } # if


        Write-Verbose ("Import task was successful.")

        ## If image import, no further work is necessary. If patch import, we need to confirm imported patches.
        if ($ImportType -eq "Patch") {

                Write-Verbose ("[Import-VUMContent]Content type is Patch, confirming import.")

                ## Get vum task info so we can get associated session ID
                try {
                    $taskInfo = $vumCon.vumWebService.getVUMTaskInfo($vumCon.vumServiceContent.taskManager, $taskMoRef)
                    Write-Verbose ("[Import-VUMContent]Got VUM task.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to get VUM task.")
                    throw ("Failed to get VUM task object. " + $_)
                } # catch


                ## Configure confirm spec
		        $fileImportResponse = $taskInfo.result
		        $sessionId = $fileImportResponse.sessionId
	            [IntegrityApi.FileUploadManagerFileUploadSpec] $confirmSpec = New-Object IntegrityApi.FileUploadManagerFileUploadSpec
    	        $confirmSpec.FilePath = ""
		        $confirmSpec.FileFunctionalType = "Patch"
	            $confirmSpec.OpType = "Confirm"
		        $confirmSpec.SessionId = $sessionId


                Write-Verbose ("[Import-VUMContent]Confirm spec set.")


                ## Confirm imported patches
                try {
                    $taskMoRef = $vumCon.vumWebService.ImportFile_Task($vumCon.vumServiceContent.fileUploadManager, $confirmSpec)
                    Write-Verbose ("[Import-VUMContent]Confirm task started.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to import patch file.")
                    throw ("Failed to import file. " + $_)
                } # catch


               ## Get task
                $taskId = $taskMoRef.type + "-" + $taskMoRef.value

                try {
                    $Task = Get-Task -Id $taskId -ErrorAction Stop
                    Write-Verbose ("[Import-VUMContent]Got task.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to get task.")
                    throw ("Failed to get task object. " + $_)
                } # catch


                ## Wait for task to complete
                Write-Verbose ("Waiting for confirm task to complete.")
                Wait-Task -Task $Task | Out-Null


                ## Get task result
                try {
                    $Task = Get-Task -Id $taskId -ErrorAction Stop
                    Write-Verbose ("[Import-VUMContent]Got task.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to get task.")
                    throw ("Failed to get task object. " + $_)
                } # catch


                ## Get task result
                if ($Task.state -ne "Success") {
                    Write-Debug ("[Import-VUMContent]Import task failed.")
                    throw ("Image import task failed with status " + $Task.State)
                } # if

                Write-Verbose ("Import has completed.")

        } # if

    } # process

    end {

        ## Logoff session
        $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)

    } # end

} # function