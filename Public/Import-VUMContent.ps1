function Import-VUMContent {
    <#
    .SYNOPSIS
        This function imports an ESXi image or patch to a VUM instance.

        With thanks to Lyuboslav Asenov @ VMWare for providing assistance with new Update Manager API.

    .DESCRIPTION
        This function uses a combination of file copy and VC Integrity API to perform content import on a VUM instance.
        The file is first copied to the VCSA to a known location on the local file system.
        File copy can either be by VM tools file copy or a CURL command for HTTP hosted content.
        The VC Integrity API is then used to import the content to VUM.

    .PARAMETER FilePath
        The path to the file to be imported to VUM. This may be a local path or an HTTP URL.

    .PARAMETER ImportType
        Use Image to import an ISO, and Patch to import patch content.

    .PARAMETER vcVM
        The VM name of the VCSA hosting VUM.

    .PARAMETER vcRootCredential
        Root credentials for the VCSA VM to allow VM tools to perform a file copy, or to allow CURL command to execute in case of HTTP hosted content.

    .PARAMETER vumVI
        Should be used if there is more than one VI connection.
        More than one VI connection can be used in scanarios where the VCSA does not manage it's own VM object.

    .EXAMPLE
        Import-VUMContent -FilePath E:\VUM\Patches\ESXi650-201810001.zip -ImportType Patch -vcVM VCSA60-02 -vcRootCredential $vcRootcreds

        Import a patch to VUM.

    .EXAMPLE
        Import-VUMContent -FilePath E:\VUM\Images\VMware-VMvisor-Installer-6.0.0.update03-5050593.x86_64.iso -ImportType Image -vcVM VCSA60-02 -vcRootCredential $vcRootcreds

        Import an ESXi image to VUM.

    .EXAMPLE
        Import-VUMContent -FilePath E:\VUM\Images\VMware-VMvisor-Installer-6.7.0.update03-14320388.x86_64.iso -ImportType Image -vcVM DEVVCSA -vcRootCredential $vcRootcreds -vumVI devvcsa.lab.local -Verbose

        This is an example of a content import to a VUM instance where the vCenter does not manage it's own VM object.
        This command is run in the context of having 2 VI connections, one to the VCSA that manages DEVVCSA, and another VI connection devvcsa.lab.local
        This allows VM tools to import to DEVVCSA, and the API call to be made to devvcsa.lab.local

    .EXAMPLE
        Import-VUMContent -FilePath http://vumcontent.local/VMware-VMvisor-Installer-6.7.0.update03-14320388.x86_64.iso -ImportType Image -vcVM DEVVCSA -vcRootCredential $vcRootcreds -vumVI devvcsa.lab.local -Verbose

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
        05       30/11/22     Reworked for PowerCLI 12.7 and new API.                                                         A McNair
                              Removed support for Windows hosted vCenter.
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$FilePath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("Patch","Image")]
        [string]$ImportType,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$vcVM,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$vcRootCredential,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [String]$vumVi
    )

    process {

        Write-Verbose ("Function start.")

        ## Get a VUM service connection object
        try {
            $vumCon = Connect-VUM -vumVI $vumVI -ErrorAction Stop
            Write-Verbose ("Got VUM connection.")
        } # try
        catch {
            throw ("Failed to connect to VUM instance. " + $_.Exception.Message)
        } # catch


        ## Create import spec object
        $importSpec = New-Object IntegrityApi.FileUploadManagerFileUploadSpec
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

        ## Get VM object for VCSA
        try {
            $VCSAVMObject = Get-VM -Name $vcVM -Erroraction Stop
            Write-Verbose ("Got VM object for VCSA.")
        } # try
        catch {
            throw ("Failed to get VM object for VCSA. " + $_.Exception.Message)
        } # catch


        ## If path starts with HTTP or HTTPS, we'll use a remote CURL command to pull down content.
        ## If not, we'll use VM tools to invoke a file copy.

        switch -Wildcard ($FilePath) {

            ## Is an HTTP URL, use CURL
            "http*" {

                ## Issue a CURL command via VM tools to download the ISO to the patch import folder
                Write-Verbose ("HTTP path detected. Downloading ISO to target appliance from " + $FilePath)

                $remoteCmd = ("curl " + $FilePath + " --output /storage/updatemgr/patch-store-temp/" + $FileName + " --fail")

                try {
                    $scriptOutput = Invoke-VMScript -ScriptText $remoteCmd -VM $VCSAVMObject -GuestCredential $vcRootCredential
                    Write-Verbose ("Remote script execution completed.")
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
                Write-Verbose ("Copying content via VM Tools.")

                try {
                    Copy-VMGuestFile -Source $FilePath -Destination "/storage/updatemgr/patch-store-temp/$($FileName)" -LocalToGuest -VM $VCSAVMObject -GuestCredential $vcRootCredential -force -ErrorAction Stop
                    Write-Verbose ("File copied to VCSA.")
                } # try
                catch {
                    throw ("Failed to copy file to VCSA. " + $_.exception.message)
                } # catch

            } # default

        } # switch

        ## Set file import spec path for VCSA
        $importSpec.FilePath = ("/storage/updatemgr/patch-store-temp/$($FileName)")


        ## Start import
        try {
            $reqType = New-Object IntegrityApi.ImportFileRequestType
            $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.fileUploadManager
            $reqType.fileSpec = $importSpec
            $svcRefVum = New-Object IntegrityApi.ImportFile_TaskRequest($reqType)

            $taskMoRef = ($vumCon.vumWebService.ImportFile_Task($svcRefVum)).ImportFile_TaskResponse.returnval
            Write-Verbose ("Import task started.")
        } # try
        catch {
            throw ("Failed to import file. " + $_.Exception.Message)
        } # catch


        ## Get task
        $taskId = $taskMoRef.type + "-" + $taskMoRef.value

        try {
            $Task = Get-Task -Id $taskId -ErrorAction Stop
            Write-Verbose ("Got task object for import.")
        } # try
        catch {
            throw ("Failed to get task object. " + $_.Exception.Message)
        } # catch


        ## Wait for task to complete
        Write-Verbose ("Waiting on import task to complete.")
        Wait-Task -Task $Task | Out-Null


        ## Get task result
        try {
            $Task = Get-Task -Id $taskId -ErrorAction Stop
            Write-Verbose ("Got task object, verifying status.")
        } # try
        catch {
            throw ("Failed to get task object. " + $_.Exception.Message)
        } # catch


        ## Get task result
        if ($Task.state -ne "Success") {
            throw ("Image import task failed with status " + $Task.State)
        } # if


        Write-Verbose ("Import task was successful.")

        ## If image import, no further work is necessary. If patch import, we need to confirm imported patches.
        if ($ImportType -eq "Patch") {

            Write-Verbose ("Content type is Patch, confirming import.")

            ## Get vum task info so we can get associated session ID
            try {
                $reqType = New-Object IntegrityApi.getVUMTaskInfoRequestType -ErrorAction Stop
                $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.taskManager
                $reqType.taskMO = $taskMoRef

                $svcRefVum = New-Object IntegrityApi.getVUMTaskInfoRequest($reqType) -ErrorAction Stop
                $taskInfo = ($vumCon.vumWebService.getVUMTaskInfo($svcRefVum)).getVUMTaskInfoResponse.returnval

                Write-Verbose ("Got VUM task.")
            } # try
            catch {
                throw ("Failed to get VUM task object. " + $_.Exception.Message)
            } # catch


            ## Configure confirm spec
            $fileImportResponse = $taskInfo.result
            $sessionId = $fileImportResponse.sessionId
            $confirmSpec = New-Object IntegrityApi.FileUploadManagerFileUploadSpec
            $confirmSpec.FilePath = ""
            $confirmSpec.FileFunctionalType = "Patch"
            $confirmSpec.OpType = "Confirm"
            $confirmSpec.SessionId = $sessionId


            Write-Verbose ("Confirm spec set.")


            ## Confirm imported patches
            try {
                $reqType = New-Object IntegrityApi.ImportFileRequestType
                $reqType._this = $vumCon.vumServiceContent.RetrieveVcIntegrityContentResponse.returnval.fileUploadManager
                $reqType.fileSpec = $confirmSpec
                $svcRefVum = New-Object IntegrityApi.ImportFile_TaskRequest($reqType)

                $taskMoRef = ($vumCon.vumWebService.ImportFile_Task($svcRefVum)).ImportFile_TaskResponse.returnval
                Write-Verbose ("Import task started.")
            } # try
            catch {
                throw ("Failed to import file. " + $_.Exception.Message)
            } # catch


            ## Get task
            $taskId = $taskMoRef.type + "-" + $taskMoRef.value

            try {
                $Task = Get-Task -Id $taskId -ErrorAction Stop
                Write-Verbose ("Got task.")
            } # try
            catch {
                throw ("Failed to get task object. " + $_.Exception.Message)
            } # catch


            ## Wait for task to complete
            Write-Verbose ("Waiting for confirm task to complete.")
            Wait-Task -Task $Task | Out-Null


            ## Get task result
            try {
                $Task = Get-Task -Id $taskId -ErrorAction Stop
                Write-Verbose ("Got task.")
            } # try
            catch {
                throw ("Failed to get task object. " + $_.Exception.Message)
            } # catch


            ## Get task result
            if ($Task.state -ne "Success") {
                throw ("Image import task failed with status " + $Task.State)
            } # if

            Write-Verbose ("Import has completed.")

        } # if

    } # process

    end {

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

    } # end

} # function