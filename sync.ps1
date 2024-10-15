$appPath = Resolve-Path ".\app.ps1"
powershell -File $appPath "sync-saves"   
