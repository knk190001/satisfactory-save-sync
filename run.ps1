$appPath = Resolve-Path ".\app.ps1"

# Function to run the game
function Run-Game {
    # Pull the latest changes from the repository
    Write-Host "Pulling latest changes..."
    & git pull origin main

    # Sync the saves
    Write-Host "Syncing saves..."
    & powershell -File $appPath "sync-saves"



    # Get the game path from conf.txt
    $gameID = Get-GameId
    # Start the game process
    Write-Host "Starting the game..."

    $gameProcess = Start-Process steam://rungameid/$gameID -PassThru

    Write-Host "Game Process ID: $($gameProcess.Id)"
   


   
}


# Command execution
switch ($args[0]) {
    Default {
        Run-Game
    }
    "create-shortcut" {
        Create-RunGameShortcut
    }
}
