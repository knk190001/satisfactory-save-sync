# Define the path to the original script
$originalScriptPath = "./app.ps1"
. ./logger.ps1

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
    $gameID = Get-Content "conf.txt" | Where-Object { $_ -match "^game_id=" } | ForEach-Object { $_ -replace "^game_id=", "" }

    # Start the game process
    Write-Host "Starting the game..."
    Log-Action "Start-Process steam://rungameid/$gameID -PassThru"
    $gameProcess = Start-Process steam://rungameid/$gameID -PassThru


   
}

# Command execution
switch ($args[0]) {
    Default {
        Run-Game
    }
}
