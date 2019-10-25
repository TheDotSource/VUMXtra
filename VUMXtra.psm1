$public = @(Get-ChildItem -Path "$($PSScriptRoot)/public/*.ps1" -ErrorAction "SilentlyContinue")
$private = @(Get-ChildItem -Path "$($PSScriptRoot)/private/*.ps1" -ErrorAction "SilentlyContinue")

forEach ($import in ($public + $private))
{
    try
    {
        . $import.fullname
    }
    catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

Export-ModuleMember -Function $Public.Basename