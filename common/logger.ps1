$logFile = "../logs/$(Get-Date -Format "yyyy-MM-dd").log"

if (-not (Test-Path -Path "../logs")) {
    New-Item -Path "../logs" -ItemType Directory
}
function Log-Action {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $logFile "$timestamp - $args"
}