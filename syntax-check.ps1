#!/usr/bin/env pwsh
# CooldownManager Addon Syntax Checker
# Checks all main addon Lua files for syntax errors

Write-Host "*** CooldownManager Lua Syntax Checker ***" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Define the main addon files to check (excluding libraries)
$MainFiles = @(
    "main.lua",
    "config.lua",
    "Core/CastBars.lua",
    "Core/ResourceBars.lua", 
    "Core/ViewerManager.lua",
    "Core/IconManager.lua",
    "Core/EventHandler.lua",
    "Core/BuffViewer.lua",
    "Core/Utils.lua",
    "Core/PerformanceCache.lua"
)

$ErrorCount = 0
$CheckedCount = 0

foreach ($File in $MainFiles) {
    if (Test-Path $File) {
        Write-Host "Checking: " -NoNewline
        Write-Host $File -ForegroundColor Yellow -NoNewline
        
        # Run lua syntax check
        $LuaCommand = "local f, err = loadfile('$File'); if f then print('OK') else print('ERROR: ' .. err); os.exit(1) end"
        $Result = lua -e $LuaCommand 2>&1
        $ExitCode = $LASTEXITCODE
        
        if ($ExitCode -eq 0) {
            Write-Host " [OK]" -ForegroundColor Green
        } else {
            Write-Host " [ERROR]" -ForegroundColor Red
            Write-Host "   $Result" -ForegroundColor Red
            $ErrorCount++
        }
        $CheckedCount++
    } else {
        Write-Host "Skipping: " -NoNewline
        Write-Host $File -ForegroundColor Gray -NoNewline
        Write-Host " (not found)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan

if ($ErrorCount -eq 0) {
    Write-Host "SUCCESS: All $CheckedCount files passed syntax check!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "ERROR: $ErrorCount out of $CheckedCount files have syntax errors!" -ForegroundColor Red
    exit 1
}
