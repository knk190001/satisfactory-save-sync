# File paths
$confFile = "conf.txt"
$savesFile = "saves.txt"
$savesDir = "./saves"
$backupDir = "./backup"
$logFile = "log.txt"

# Ensure necessary directories exist
if (-not (Test-Path -Path $savesDir)) {
    New-Item -ItemType Directory -Path $savesDir
}
if (-not (Test-Path -Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir
}

# Logging function
function Log-Action {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $logFile "$timestamp - $args"
}

# Function to get the save path from conf.txt
function Get-SavePath {
    $savePathLine = Get-Content $confFile | Where-Object { $_ -match "^save_path=" }
    return $savePathLine -replace "^save_path=", ""
}

# Function to load regex patterns from saves.txt
function Get-SaveRegexPatterns {
    if (Test-Path -Path $savesFile) {
        return Get-Content $savesFile
    }
    return @()
}

# Function to check if a file matches any regex from saves.txt
function Matches-AnyRegex($fileName, $regexes) {
    foreach ($regex in $regexes) {
        if ($fileName -match $regex) {
            return $true
        }
    }
    return $false
}

# Backup remote files before copying
function Backup-RemoteFile {
    param ($remoteFile)

    # Create timestamped backup folder inside the main backup directory
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFolderPath = Join-Path $backupDir "backup_$timestamp"

    if (-not (Test-Path -Path $backupFolderPath)) {
        New-Item -ItemType Directory -Path $backupFolderPath
    }

    # Copy the remote file to the timestamped backup folder
    Copy-Item -Path $remoteFile.FullName -Destination $backupFolderPath -Force
    Write-Host "Backed up remote file '$($remoteFile.Name)' to $backupFolderPath"
    Log-Action "Backed up remote file '$($remoteFile.Name)' to $backupFolderPath"
}

# Sync each save file by comparing modification times
function Sync-Saves {
    $savePath = Get-SavePath
    if (-not $savePath) {
        Write-Host "Save path not set. Use 'set-save-path' first."
        return
    }

    $regexPatterns = Get-SaveRegexPatterns

    if ($regexPatterns.Count -eq 0) {
        Write-Host "No regex patterns found in saves.txt."
        Log-Action "No regex patterns found in saves.txt."
        return
    }

    # Get all files from both local (saves) and remote (save path) matching the regex
    $localFiles = Get-ChildItem -Path $savesDir -File | Where-Object { Matches-AnyRegex $_.Name $regexPatterns }
    $remoteFiles = Get-ChildItem -Path $savePath -File | Where-Object { Matches-AnyRegex $_.Name $regexPatterns }

    # Sync each file individually
    foreach ($localFile in $localFiles) {
        $remoteFile = $remoteFiles | Where-Object { $_.Name -eq $localFile.Name }

        if ($null -eq $remoteFile) {
            # If the file exists locally but not remotely, copy it to remote
            Copy-Item -Path $localFile.FullName -Destination $savePath -Force
            Write-Host "Copied local file '$($localFile.Name)' to save path."
            Log-Action "Copied local file '$($localFile.Name)' to $savePath"
        } elseif ($localFile.LastWriteTime -gt $remoteFile.LastWriteTime) {
            # If the local file is newer, backup remote file first, then copy
            Backup-RemoteFile $remoteFile
            Copy-Item -Path $localFile.FullName -Destination $savePath -Force
            Write-Host "Backed up and copied newer local file '$($localFile.Name)' to save path."
            Log-Action "Backed up and copied newer local file '$($localFile.Name)' to $savePath"
        } elseif ($remoteFile.LastWriteTime -gt $localFile.LastWriteTime) {
            # If the remote file is newer, copy it to local
            Copy-Item -Path $remoteFile.FullName -Destination $savesDir -Force
            Write-Host "Copied newer remote file '$($remoteFile.Name)' to saves folder."
            Log-Action "Copied newer remote file '$($remoteFile.Name)' to $savesDir"
        }
    }

    # Check for remote files not present locally and copy them to the local folder
    foreach ($remoteFile in $remoteFiles) {
        $localFile = $localFiles | Where-Object { $_.Name -eq $remoteFile.Name }

        if ($null -eq $localFile) {
            # If the file exists remotely but not locally, copy it to local
            Copy-Item -Path $remoteFile.FullName -Destination $savesDir -Force
            Write-Host "Copied remote file '$($remoteFile.Name)' to saves folder."
            Log-Action "Copied remote file '$($remoteFile.Name)' to $savesDir"
        }
    }
}

# Function to generate commit message
function Generate-CommitMessage {
    $hostname = (Get-ComputerInfo).CsName
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $filesAdded = git status --porcelain | Where-Object { $_ -match "^A" } | Measure-Object | Select-Object -ExpandProperty Count
    return "Commit from $hostname at $timestamp, $filesAdded file(s) added"
}


# Commands
switch ($args[0]) {
    "set-save-path" {
        $savePath = Read-Host "Enter save path"
        "save_path=$savePath" | Out-File -FilePath $confFile -Encoding UTF8
        Write-Host "Save path set."
        Log-Action "Set save path to $savePath"
    }

    "set-game-path" {
        $gamePath = Read-Host "Enter game path"
        "game_path=$gamePath" | Add-Content $confFile
        Write-Host "Game path set."
        Log-Action "Set game path to $gamePath"
    }

    "add-save-name" {
        $saveName = Read-Host "Enter save name"
        $saveName | Add-Content $savesFile
        Write-Host "Save name added."
        Log-Action "Added save name $saveName"
    }

    "push" {
        git add .
        $commitMessage = Generate-CommitMessage
        git commit -m "$commitMessage"
        git push origin main
        Write-Host "Pushed to main with commit message: $commitMessage"
        Log-Action "Pushed to main with commit message: $commitMessage"
    }

    "pull" {
        git pull origin main
        Log-Action "Pulled latest changes from main"
    }

    "copy-saves" {
        $savePath = Get-SavePath
        if (-not $savePath) {
            Write-Host "Save path not set. Use 'set-save-path' first."
        } else {
            $regexPatterns = Get-SaveRegexPatterns

            if ($regexPatterns.Count -eq 0) {
                Write-Host "No regex patterns found in saves.txt."
                Log-Action "No regex patterns found in saves.txt."
            } else {
                $filesCopied = 0

                Get-ChildItem -Path $savePath -File | ForEach-Object {
                    if (Matches-AnyRegex $_.Name $regexPatterns) {
                        Copy-Item -Path $_.FullName -Destination $savesDir -Force
                        $filesCopied++
                    }
                }

                Write-Host "$filesCopied file(s) copied to script location."
                Log-Action "Copied $filesCopied file(s) matching regex from $savePath to $savesDir"
            }
        }
    }

    "sync-saves" {
        Sync-Saves
    }

    Default {
        Write-Host "Invalid command. Use one of the following:"
        Write-Host "set-save-path, set-game-path, add-save-name, push, pull, copy-saves, sync-saves"
        Log-Action "Invalid command: $args[0]"
    }
}
