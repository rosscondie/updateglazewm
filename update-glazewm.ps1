# PowerShell script to automatically download and install the latest GlazeWM and Zebar versions

# Function to get the installed version of a program
function Get-InstalledVersion {
    param (
        [string]$programName
    )

    try {
        # Query installed programs for the version
        $installedProgram = Get-CimInstance Win32_Product | Where-Object { $_.Name -like "$programName*" } | Select-Object -First 1
        if ($installedProgram) {
            return $installedProgram.Version
        } else {
            return $null
        }
    } catch {
        Write-Host ("An error occurred while checking installed version for " + $programName + ": " + $_.Exception.Message)
        return $null
    }
}

# Function to handle downloading and installing a program
function Install-Program {
    param (
        [string]$repo,
        [string]$filePattern,
        [string]$programName,
        [string]$installer_type  # Added parameter for installer type
    )

    Write-Host "`nChecking for latest $programName version..."
    try {
        # Get latest release info from GitHub
        $releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest"
        $latestVersion = $releaseInfo.tag_name -replace '^v', ''  # Remove 'v' prefix from version

        # Find the correct asset for download
        $asset = $releaseInfo.assets | Where-Object { $_.name -like $filePattern } | Select-Object -First 1
        $downloadUrl = $asset.browser_download_url

        if (-not $downloadUrl) {
            Write-Host "Error: Couldn't find the download link for $programName"
            return $false
        }

        # Get the installed version of the program
        $installedVersion = Get-InstalledVersion -programName $programName

        if ($installedVersion -and ($installedVersion -eq $latestVersion)) {
            Write-Host "$programName is already up to date (version $installedVersion). Skipping installation."
            return $true
        }

        Write-Host "Latest $programName version is: $latestVersion"
        if ($installedVersion) {
            Write-Host "Installed version: $installedVersion"
        } else {
            Write-Host "$programName is not installed."
        }

        # Define where to save the downloaded file
        $downloadPath = "$env:TEMP\${programName}_installer.$installer_type"

        Write-Host "Downloading $programName $latestVersion..."

        # Download the file
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
        Write-Host "Download complete!"

        # Check if download succeeded
        if (-not (Test-Path $downloadPath)) {
            Write-Host "Error: Download failed or file not found at $downloadPath"
            return $false
        }

        # Install
        Write-Host "Installing $programName..."
        if ($installer_type -eq "msi") {
            # MSI installation with verbose logging
            $msiLogPath = "$env:TEMP\$programName-install.log"
            $installCommand = "/i `"$downloadPath`" /quiet /log `"$msiLogPath`""
            Write-Host "Executing MSI install command: msiexec.exe $installCommand"
            Start-Process msiexec.exe -ArgumentList $installCommand -Wait
            Write-Host "MSI installation log created at: $msiLogPath"
        } else {
            # EXE installation
            $installCommand = "/SILENT"
            Write-Host "Executing EXE install command: $downloadPath $installCommand"
            Start-Process $downloadPath -ArgumentList $installCommand -Wait
        }

        # Clean up the installer
        Remove-Item $downloadPath

        # Remove desktop shortcut if it exists
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path $desktopPath "$programName.lnk"
        if (Test-Path $shortcutPath) {
            Remove-Item $shortcutPath -Force
            Write-Host "Desktop shortcut removed."
        }

        Write-Host "$programName installation complete!"
        return $true
    } catch {
        Write-Host ("An error occurred while installing " + $programName + ": " + $_.Exception.Message)
        if (Test-Path $downloadPath) {
            Remove-Item $downloadPath
        }
        return $false
    }
}

# Main script execution
Write-Host "Starting update process for GlazeWM and Zebar..."

# Update GlazeWM
$glazeSuccess = Install-Program -repo "glzr-io/glazewm" `
                              -filePattern "glazewm-*.exe" `
                              -programName "GlazeWM" `
                              -installer_type "exe"

# Update Zebar
$zebarSuccess = Install-Program -repo "glzr-io/zebar" `
                              -filePattern "zebar-*-x64.msi" `
                              -programName "Zebar" `
                              -installer_type "msi"

# Final status report
Write-Host "`nUpdate Summary:"
Write-Host "GlazeWM: $(if ($glazeSuccess) { 'Updated successfully' } else { 'Update failed' })"
Write-Host "Zebar: $(if ($zebarSuccess) { 'Updated successfully' } else { 'Update failed' })"

Write-Host "`nAll done!"
