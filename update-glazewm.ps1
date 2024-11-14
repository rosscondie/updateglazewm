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
            return "Not Installed"
        }
    } catch {
        Write-Host ("An error occurred while checking installed version for " + $programName + ": " + $_.Exception.Message)
        return "Unknown"
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

        # Check if update is available
        if ($installedVersion -and ($installedVersion -eq $latestVersion)) {
            Write-Host "$programName is already up to date (version $installedVersion). Skipping installation."
            return $true
        }

        # Display version information
        Write-Host "Latest $programName version is: $latestVersion"
        Write-Host "Installed version: $installedVersion"

        # Define where to save the downloaded file
        $downloadPath = "$env:TEMP\${programName}_installer.$installer_type"

        # Download the file
        $downloadedBytes = 0
        $totalBytes = $asset.size
        Write-Host "Downloading $programName $latestVersion..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -WebRequestSessionOption 'UserAgent=PowerShell' -Progress

        # Check if download succeeded
        if (-not (Test-Path $downloadPath)) {
            Write-Host "Error: Download failed or file not found at $downloadPath"
            return $false
        }

        # Install
        if ($installer_type -eq "msi") {
            # MSI installation with verbose logging
            $msiLogPath = "$env:TEMP\$programName-install.log"
            $installCommand = "/i `"$downloadPath`" /quiet /log `"$msiLogPath`""  # MSI installation command
            Start-Process msiexec.exe -ArgumentList $installCommand -Wait
            Write-Host "MSI installation log created at: $msiLogPath"
        } else {
            # EXE installation
            Start-Process $downloadPath -ArgumentList "/SILENT" -Wait
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
Write-Host "Starting update process for GlazeWM..."

# Update GlazeWM
$glazeSuccess = Install-Program -repo "glzr-io/glazewm" `
                              -filePattern "glazewm-*.exe" `
                              -programName "GlazeWM" `
                              -installer_type "exe"

# Final status report
Write-Host "`nUpdate Summary:"
Write-Host "GlazeWM: $(if ($glazeSuccess) { 'Updated successfully' } else { 'Update failed' })"
Write-Host "`nAll done!"
