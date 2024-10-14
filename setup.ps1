# File paths
$confFile = "conf.txt"
$savesFile = "saves.txt"
$savesDir = "./saves"
$logFile = "log.txt"

# Ensure saves directory exists
if (-not (Test-Path -Path $savesDir)) {
    New-Item -ItemType Directory -Path $savesDir
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

# Function to get the game path from conf.txt
function Get-GamePath {
    $gamePathLine = Get-Content $confFile | Where-Object { $_ -match "^game_path=" }
    return $gamePathLine -replace "^game_path=", ""
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
        $commitMessage = Read-Host "Enter commit message"
        git commit -m "$commitMessage"
        git push origin main
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
            Copy-Item -Path "$savePath\*" -Destination $savesDir -Recurse -Force
            Write-Host "Saves copied to script location."
            Log-Action "Copied saves from $savePath to $savesDir"
        }
    }

    "sync-saves" {
        $savePath = Get-SavePath
        if (-not $savePath) {
            Write-Host "Save path not set. Use 'set-save-path' first."
        } else {
            $scriptLastModified = Get-ChildItem -Path $savesDir -File | Sort-Object LastWriteTime | Select-Object -Last 1
            $externalLastModified = Get-ChildItem -Path $savePath -File | Sort-Object LastWriteTime | Select-Object -Last 1

            if ($externalLastModified.LastWriteTime -gt $scriptLastModified.LastWriteTime) {
                Copy-Item -Path "$savePath\*" -Destination $savesDir -Recurse -Force
                Write-Host "Saves synced from save path to script."
                Log-Action "Synced saves from $savePath to $savesDir"
            } else {
                Copy-Item -Path "$savesDir\*" -Destination $savePath -Recurse -Force
                Write-Host "Saves synced from script to save path."
                Log-Action "Synced saves from $savesDir to $savePath"
            }
        }
    }

    Default {
        Write-Host "Invalid command. Use one of the following:"
        Write-Host "set-save-path, set-game-path, add-save-name, push, pull, copy-saves, sync-saves"
        Log-Action "Invalid command: $args[0]"
    }
}
