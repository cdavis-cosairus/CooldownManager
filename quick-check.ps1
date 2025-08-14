#!/usr/bin/env pwsh
# Quick syntax checker - single line version
$files = @("main.lua", "config.lua", "Core/CastBars.lua", "Core/ResourceBars.lua", "Core/ViewerManager.lua", "Core/IconManager.lua", "Core/EventHandler.lua", "Core/BuffViewer.lua", "Core/Utils.lua")
$errors = 0
foreach ($f in $files) { 
    if (Test-Path $f) { 
        $cmd = "local file, err = loadfile('$f'); if file then print('OK') else print('ERROR'); os.exit(1) end"
        $result = lua -e $cmd 2>&1
        Write-Host "$f " -NoNewline
        if ($LASTEXITCODE -eq 0) { Write-Host "[OK]" -ForegroundColor Green } else { Write-Host "[ERROR]" -ForegroundColor Red; $errors++ }
    } else { 
        Write-Host "$f [MISSING]" -ForegroundColor Yellow 
    } 
}
if ($errors -eq 0) { Write-Host "All files passed!" -ForegroundColor Green } else { Write-Host "$errors files have errors!" -ForegroundColor Red }
