. ./common/logger.ps1

# File paths
$configLocalFile = "./configs/config-local.txt"
$configGlobalFile = "./configs/config.txt"
$savesFile = "./configs/saves.txt"
$savesDir = "./saves"
$backupDir = "./backup"

# Ensure necessary directories exist
if (-not (Test-Path -Path $savesDir)) {
    New-Item -ItemType Directory -Path $savesDir
}
if (-not (Test-Path -Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir
}
if (-not (Test-Path -Path "./configs")) {
    New-Item -ItemType Directory -Path "./configs"
}

# Function to update or set a configuration value
function Set-ConfigValue {
    param (
        [string]$Key,       # The config key (e.g., "save_path", "gameId")
        [string]$Value,     # The value to set
        [string]$FilePath   # The path to the config file
    )

    # Read the config file if it exists, otherwise create an empty array
    if (Test-Path $FilePath) {
        $configLines = Get-Content $FilePath
    } else {
        $configLines = @()
    }

    # Check if the key already exists
    $keyExists = $false
    for ($i = 0; $i -lt $configLines.Count; $i++) {
        if ($configLines[$i] -match "^$Key=") {
            # Key exists, update the value
            $configLines[$i] = "$Key=$Value"
            $keyExists = $true
            break
        }
    }

    # If key does not exist, append it to the config file
    if (-not $keyExists) {
        $configLines += "$Key=$Value"
    }

    # Write the updated config back to the file
    $configLines | Set-Content $FilePath
}


# Function to get the save path from conf.txt
function Get-SavePath {
    $savePathLine = Get-Content $configLocalFile | Where-Object { $_ -match "^save_path=" }
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
function Sync-SavesLocally {
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
        }
        elseif ($localFile.LastWriteTime -gt $remoteFile.LastWriteTime) {
            # If the local file is newer, backup remote file first, then copy
            Backup-RemoteFile $remoteFile
            Copy-Item -Path $localFile.FullName -Destination $savePath -Force
            Write-Host "Backed up and copied newer local file '$($localFile.Name)' to save path."
            Log-Action "Backed up and copied newer local file '$($localFile.Name)' to $savePath"
        }
        elseif ($remoteFile.LastWriteTime -gt $localFile.LastWriteTime) {
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

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $filesAdded = git status --porcelain | Where-Object { $_ -match "^A" } | Measure-Object | Select-Object -ExpandProperty Count
    return "Commit from $env:UserName at $timestamp, $filesAdded file(s) added"
}

# Function to reset the folders after confirmation
function Reset-Folders {
    # Define the folders to be deleted
    $foldersToDelete = @(
        $savesDir,
        "./configs",
        "./logs",
        $backupDir
    )

    # Humorous confirmation text
    $confirmationPhrase = "delete my precious data"
    $confirmationPrompt = @"
Are you absolutely sure you want to delete all the following folders?
- Saves
- Configs
- Logs
- Backup

If you're sure, type the following confirmation exactly:
"$confirmationPhrase"
"@

    # Display the prompt
    Write-Host $confirmationPrompt

    # Get user input
    $userInput = Read-Host "Type your confirmation"

    # Check if the input matches the confirmation phrase
    if ($userInput -eq $confirmationPhrase) {
        # If confirmation matches, delete the folders
        foreach ($folder in $foldersToDelete) {
            if (Test-Path $folder) {
                Remove-Item -Recurse -Force $folder
                Write-Host "Deleted: $folder"
            } else {
                Write-Host "Folder not found: $folder"
            }
        }

        # Log the reset action
        Log-Action "Folders reset: saves, configs, logs, backup"
    } else {
        Write-Host "Confirmation failed. Reset aborted."
    }
}


function SetSavePath {
    $savePath = Read-Host "Enter save path"
    Set-ConfigValue "save_path" $savePath $configLocalFile
    Write-Host "Save path set."
    Log-Action "Set save path to $savePath"
}

function SetGameId {
    $gameID = Read-Host "Enter game ID (for satisfactory use: 526870)"
    Set-ConfigValue "gameId" $gameID $configGlobalFile
    Write-Host "Game ID set."
    Log-Action "Set game ID to $gameID"
}

function Push {
    git add .
    $commitMessage = Generate-CommitMessage
    git commit -m "$commitMessage"
    git push origin main
    Write-Host "Pushed to main with commit message: $commitMessage"
    Log-Action "Pushed to main with commit message: $commitMessage"
    
}

function AddSaveRegex {
    $saveName = Read-Host "Enter regex pattern to match save files, e.g., '^factory.*\.sav$'"
    $saveName | Add-Content $savesFile
    Write-Host "Save name added."
    Log-Action "Added save name $saveName"
}



function CopySaves {
    $savePath = Get-SavePath
        if (-not $savePath) {
            Write-Host "Save path not set. Use 'set-save-path' first."
        }
        else {
            $regexPatterns = Get-SaveRegexPatterns

            if ($regexPatterns.Count -eq 0) {
                Write-Host "No regex patterns found in saves.txt."
                Log-Action "No regex patterns found in saves.txt."
            }
            else {
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


function Setup {
    # 1. Set Game ID
    SetGameId
    # 2. Set Save Path
    SetSavePath
    # 3. Add Save Regex
    AddSaveRegex
    # 4. Copy Saves
    CopySaves
    # 5. Push
    Push
    Write-Host "Setup complete."
    Log-Action "Setup complete."

}

# Commands
switch ($args[0]) {
    "set-save-path" {
        SetSavePath
    }

    "set-game-id" {
        SetGameId
     
    }

    "add-save-regex" {
        AddSaveRegex
    }

    "push" {
        Push
    }

    "pull" {
        git pull origin main
        Log-Action "Pulled latest changes from main"
    }

    "copy-saves" {
       CopySaves
    }

    "sync-saves-locally" {
        Sync-SavesLocally
    }
    "sync-saves" {
        Sync-SavesLocally
        Push
        Write-Host "Synced saves with remote successfully."
        Log-Action "Synced saves with remote successfully."
    }

    "reset" {
        Reset-Folders
    }
    "setup" {
        Setup
    }


    Default {
        Write-Host "Invalid command. Use one of the following:"
        Write-Host "set-save-path, set-game-id, add-save-name, push, pull, copy-saves, sync-save-locally, sync-saves, reset, setup"
        Log-Action "Invalid command: $args[0]"
    }
}
