. ./app.ps1


# Function to run the game
function Run-Game {
    # Pull the latest changes from the repository
    Write-Host "Pulling latest changes..."
    & git pull origin main

    # Sync the saves
    Write-Host "Syncing saves..."
    Sync-SavesLocally
    Write-Host "Pushing changes..."
    Push



    # Get the game path from conf.txt
    $gameID = Get-Content "conf.txt" | Where-Object { $_ -match "^game_id=" } | ForEach-Object { $_ -replace "^game_id=", "" }

    # Start the game process
    Write-Host "Starting the game..."
    Log-Action "Start-Process steam://rungameid/$gameID -PassThru"
    $gameProcess = Start-Process steam://rungameid/$gameID -PassThru

    Write-Host "Game Process ID: $($gameProcess.Id)"
    Log-Action "Game Process ID: $($gameProcess.Id)"


   
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
