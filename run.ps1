# Define the path to the original script
$originalScriptPath = "./app.ps1"

# Ensure the original script exists
if (-not (Test-Path -Path $originalScriptPath)) {
    Write-Host "The original script could not be found at '$originalScriptPath'."
    exit
}

# Function to run the game
function Run-Game {
    # Pull the latest changes from the repository
    Write-Host "Pulling latest changes..."
    & git pull origin main

    # Sync the saves
    Write-Host "Syncing saves..."
    & powershell -File $originalScriptPath "sync-saves"

    # Push changes
    Write-Host "Pushing changes..."
    & powershell -File $originalScriptPath "push"

    # Get the game path from conf.txt
    $gamePath = Get-Content "conf.txt" | Where-Object { $_ -match "^game_path=" } | ForEach-Object { $_ -replace "^game_path=", "" }

    if (-not (Test-Path -Path $gamePath)) {
        Write-Host "Game path does not exist: $gamePath"
        exit
    }

    # Start the game process
    Write-Host "Starting the game..."
    $gameProcess = Start-Process -FilePath $gamePath -PassThru

    # Monitor the folder for changes while the game is running
    $savePath = Get-Content "conf.txt" | Where-Object { $_ -match "^save_path=" } | ForEach-Object { $_ -replace "^save_path=", "" }

    if (-not (Test-Path -Path $savePath)) {
        Write-Host "Save path not set. Use 'set-save-path' first."
        exit
    }

    # Set up file system watcher for the save path
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $savePath
    $watcher.IncludeSubdirectories = $false
    $watcher.Filter = "*.*"
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName, [System.IO.NotifyFilters]::LastWrite

    # Event triggered when a file is changed in the save path
    $changedEvent = Register-ObjectEvent $watcher 'Changed' -Action {
        Write-Host "File changed in save path: $($Event.SourceEventArgs.Name)"
        Log-Action "File changed in save path: $($Event.SourceEventArgs.Name)"

        # Sync the saves after a change
        & powershell -File $originalScriptPath "sync-saves"

        # Push the changes
        & powershell -File $originalScriptPath "push"
    }

    # Start watching
    $watcher.EnableRaisingEvents = $true

    # Wait for the game process to exit
    $gameProcess.WaitForExit()

    # Cleanup
    $watcher.EnableRaisingEvents = $false
    Unregister-Event -SourceIdentifier $changedEvent.Name
    Write-Host "Game has exited. Stopping monitoring."
}

# Command execution
switch ($args[0]) {
    "run-game" {
        Run-Game
    }
    Default {
        Write-Host "Invalid command. Use 'run-game'."
    }
}
