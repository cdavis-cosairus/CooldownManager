# Brewmaster Monk Stagger Bar Implementation

## Overview
Added a new secondary resource display for Brewmaster Monks (specialization 1) that shows their stagger information in real-time.

## Features Implemented

### 1. Stagger Detection
- Monitors three stagger aura types:
  - Heavy Stagger (Spell ID: 124275) - Red color
  - Moderate Stagger (Spell ID: 124274) - Orange color  
  - Light Stagger (Spell ID: 124273) - Green color

### 2. Visual Display
- **Bar Fill**: Shows stagger amount as percentage of max health (scaled to 50% max for display)
- **Tick Display**: Shows approximate damage per tick (left side of bar)
- **Percentage Display**: Shows stagger as percentage of max health (right side of bar)
- **Color Coding**: 
  - Green: Light stagger (0-6% of max health)
  - Orange: Moderate stagger (6-15% of max health)  
  - Red: Heavy stagger (15%+ of max health)

### 3. Integration Points
- Added to secondary resource bar system
- Compatible with existing resource bar positioning and styling options
- Updates at ~120 FPS for smooth real-time feedback
- Responds to UNIT_AURA events for immediate updates

## Files Modified

### Core/ResourceBars.lua
- Added `UpdateBrewmasterStagger()` function
- Updated class detection to include Brewmaster monks (spec 1)
- Integrated stagger bar into OnUpdate and initial display logic

### Core/Utils.lua  
- Added stagger color constants to `CooldownManager.CONSTANTS.COLORS.STAGGER`

## Usage
1. Enable "Secondary Resource Bar" in addon config
2. Works automatically when playing as Brewmaster Monk (spec 1)
3. Bar appears below (or above) the configured viewer
4. Shows real-time stagger information with color-coded severity

## Technical Details
- Stagger amount extracted from aura point values
- Tick damage calculated as ~2% of total stagger per 0.5 seconds
- Bar scaling prevents visual overflow at extreme stagger values
- Brightness scaling based on fill percentage for visual feedback
- Text overlays use outline fonts for readability

## Testing
- All syntax checks pass
- Logic validated with test script
- Color thresholds match standard stagger breakpoints
- Compatible with existing secondary resource framework
