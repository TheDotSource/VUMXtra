function Import-VUMContent {
    <#
    .SYNOPSIS
        This function imports an ESXi image or patch to a VUM instance.
    .DESCRIPTION
        This function is part of a module that addresses gaps in the VUM PowerCLI CMDlets.
        The VCItegrity private API is used.
        The function will copy the file to either the Windows VUM host or the appliance path /storage/updatemgr/patch-store-temp
        A better method would be to use the VUM file import manager if this could be figured out.
    .EXAMPLE
        Import-ESXImage -ImageFile E:\VUM\Patches\ESXi650-201810001.zip -VUMType VCSA -ImportType Patch -VCSAVM VCSA60-02 -VCSACred (Get-Credential)

        Import a patch to a VCSA integrated VUM instance.
    .EXAMPLE
        Import-ESXImage -ImageFile E:\VUM\Patches\ESXi650-201810001.zip -VUMType Windows -ImportType Patch -WindowsHost WINVUM01 -WinCred (Get-Credential)

        Import a patch to a Windows VUM instance.
    .EXAMPLE
        Import-ESXImage -ImageFile E:\VUM\Images\VMware-VMvisor-Installer-6.0.0.update03-5050593.x86_64.iso -VUMType VCSA -ImportType Image -VCSAVM VCSA60-02 -VCSACred (Get-Credential)

        Import an image to a VCSA integrated VUM instance.
    .NOTES
        01       14/11/18     Initial version.                                                                                A McNair
        02       29/11/18     Changed file copy for Windows VUM from UNC to PS Drive so a credential can be specifed.         A McNair
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

                  ## Create an attributecollection object for the attribute we just created.
                  $attributeCollection1 = new-object System.Collections.ObjectModel.Collection[System.Attribute]
                  $attributeCollection2 = new-object System.Collections.ObjectModel.Collection[System.Attribute]

                  ## Add custom attribute
                  $attributeCollection1.Add($VCSAVMAtrrib)
                  $attributeCollection2.Add($VCSACredAtrrib)

                  ## Add our paramater specifying the attribute collection
                  $VCSAVM = New-Object System.Management.Automation.RuntimeDefinedParameter('VCSAVM', [string], $attributeCollection1)
                  $VCSACred = New-Object System.Management.Automation.RuntimeDefinedParameter('VCSACred', [PSObject], $attributeCollection2)

                  ## Expose the name of our parameter
                  $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                  $paramDictionary.Add('VCSAVM', $VCSAVM)
                  $paramDictionary.Add('VCSACred', $VCSACred)
            } # VCSA

        } # switch

        return $paramDictionary

    } # DynamicParam


    process {

        Write-Debug ("[Import-VUMContent]Function start.")

        ## Get a VUM service connection object
        try {
            $vumCon = Connect-VUM -ErrorAction stop
            Write-Debug ("[Remove-BaselineGroup]Got VUM connection.")
        } # try
        catch {
            Write-Debug ("[Remove-BaselineGroup]Failed to connect to VUM instance.")
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

                Write-Debug ("[Import-VUMContent]Copy file to Windows VUM.")

                Write-Debug("User: " + $WinCred.username)

                ## Create new PS Drive object to Windows UNC
                try {
                    New-PSDrive VUMIMPORT -PSProvider FileSystem -Root ("\\" + $WindowsHost.value + "\c$") -Credential $WinCred.value -ErrorAction Stop | Out-Null
                    Write-Debug ("[Import-VUMContent]Created new PS drive.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to create PS Drive to UNC.")
                    throw ("Failed to create PS drive to UNC. " + $_)
                } # catch


                ## Create remote VUMImport folder
                try {
                    New-Item -ItemType Directory -Path VUMIMPORT:\VUMImport -Force -ErrorAction Stop | Out-Null
                    Write-Debug ("[Import-VUMContent]VUM import folder created.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to create VUM import folder." + $_)
                    throw ("Failed to create VUM import folder. " + $_)
                } # catch


                ## Copy file to import folder
                try {
                    Copy-Item -Path $FilePath -Destination ("\\" + $WindowsHost.value + "\c$\VUMImport\" + $FileName) -Force -ErrorAction Stop | Out-Null
                    Write-Debug ("[Import-VUMContent]Image file copied.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to copy image file.")
                    throw ("Failed to copy image file. " + $_)
                } # catch


                ## Remove PS Drive
                try {
                    Remove-PSDrive -Name VUMIMPORT -ErrorAction Stop | Out-Null
                    Write-Debug ("[Import-VUMContent]Removed PS drive.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to remove PS drive.")
                    throw ("Failed to remove PS drive. " + $_)
                } # catch


                ## Set file import spec path for Windows
                $importSpec.FilePath = ("c:\VUMImport\" + $FileName)
            } # Windows

            "VCSA" {

                Write-Debug ("[Import-VUMContent]Copy file to VCSA VUM.")

                ## Get VM object for VCSA
                try {
                    $VCSAVMObject = Get-VM -Name $VCSAVM.value -Erroraction Stop
                    Write-Debug ("[Import-VUMContent]Got VM object for VCSA.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to get VM.")
                    throw ("Failed to get VM object for VCSA. " + $_)
                } # catch


                ## Copy file to VCSA path using VM tools
                try {
                    Copy-VMGuestFile -Source $FilePath -Destination "/storage/updatemgr/patch-store-temp/$($FileName)" -LocalToGuest -VM $VCSAVMObject -GuestCredential $VCSACred.value -force -ErrorAction Stop
                    Write-Debug ("[Import-VUMContent]File copied to VCSA.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to copy file to VCSA.")
                    throw ("Failed to copy file to VCSA. " + $_)
                } # catch


                ## Set file import spec path for VCSA
                $importSpec.FilePath = ("/storage/updatemgr/patch-store-temp/$($FileName)")
            } # VCSA

        } # switch


        ## Start import
        try {
            $taskMoRef = $vumCon.vumWebService.ImportFile_Task($vumCon.vumServiceContent.fileUploadManager, $importSpec)
            Write-Debug ("[Import-VUMContent]Import task started.")
        } # try
        catch {
            Write-Debug ("[Import-VUMContent]Failed to import image file.")
            throw ("Failed to import file. " + $_)
        } # catch


        ## Get task
        $taskId = $taskMoRef.type + "-" + $taskMoRef.value

        try {
            $Task = Get-Task -Id $taskId
            Write-Debug ("[Import-VUMContent]Got task.")
        } # try
        catch {
            Write-Debug ("[Import-VUMContent]Failed to get task.")
            throw ("Failed to get task object. " + $_)
        } # catch


        ## Wait for task to complete
        Wait-Task -Task $Task | Out-Null


        ## Get task result
        try {
            $Task = Get-Task -Id $taskId
            Write-Debug ("[Import-VUMContent]Got task.")
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


        ## If image import, no further work is necessary. If patch import, we need to confirm imported patches.
        if ($ImportType -eq "Patch") {

                Write-Debug ("[Import-VUMContent]Confirm patches.")
                
                ## Get vum task info
                try {
                    $taskInfo = $vumCon.vumWebService.getVUMTaskInfo($vumCon.vumServiceContent.taskManager, $taskMoRef)
                    Write-Debug ("[Import-VUMContent]Got VUM task.")
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


                Write-Debug ("[Import-VUMContent]Confirm spec set.")


                ## Confirm imported patches
                try {
                    $taskMoRef = $vumCon.vumWebService.ImportFile_Task($vumCon.vumServiceContent.fileUploadManager, $confirmSpec)
                    Write-Debug ("[Import-VUMContent]Confirm task started.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to import patch file.")
                    throw ("Failed to import file. " + $_)
                } # catch


               ## Get task
                $taskId = $taskMoRef.type + "-" + $taskMoRef.value

                try {
                    $Task = Get-Task -Id $taskId
                    Write-Debug ("[Import-VUMContent]Got task.")
                } # try
                catch {
                    Write-Debug ("[Import-VUMContent]Failed to get task.")
                    throw ("Failed to get task object. " + $_)
                } # catch


                ## Wait for task to complete
                Wait-Task -Task $Task | Out-Null


                ## Get task result
                try {
                    $Task = Get-Task -Id $taskId
                    Write-Debug ("[Import-VUMContent]Got task.")
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

        } # if

    } # process

    end {

        ## Logoff session
        $vumCon.vumWebService.VciLogout($vumCon.vumServiceContent.sessionManager)

    } # end

} # function