# Viewer Combat Visibility Implementation Summary

## Overview
Successfully implemented per-viewer combat visibility feature for CooldownManager addon. This allows users to hide individual cooldown viewers when out of combat while maintaining independent control over each viewer.

## Changes Made

### 1. Configuration Options (config.lua)
- Added `hideOutOfCombat` toggle option to each viewer's layout configuration
- Located in: Viewers → Layout → [ViewerName] → "Hide Out of Combat"
- Each viewer can be independently configured to hide/show out of combat
- Setting triggers immediate visibility update via `UpdateCombatVisibility()`

### 2. Combat Visibility Logic (config.lua)
Enhanced `UpdateCombatVisibility()` function:
- Added viewer visibility handling before existing resource bar logic
- Iterates through all three viewers: EssentialCooldownViewer, UtilityCooldownViewer, BuffIconCooldownViewer
- Checks each viewer's `hideOutOfCombat` setting
- Shows/hides viewers based on combat state and individual settings
- **CRITICAL FIX**: Added icon refresh logic when viewers are shown after being hidden
- Tracks if viewers were previously hidden and triggers comprehensive icon updates
- Calls `UpdateAllCustomIcons()`, `UpdateBuffIconVisibility()`, `TrySkin()`, and `LayoutCooldownIcons()`
- Uses `C_Timer.After(0.1)` to ensure proper timing of icon refresh
- Maintains backward compatibility with existing resource bar combat visibility

### 3. Event Handling (main.lua)
- Enhanced combat event handling to call `UpdateCombatVisibility()` on PLAYER_REGEN_ENABLED/DISABLED
- Ensures immediate response to combat state changes
- Integrated with existing event system for clean code organization

### 4. Testing
- Created comprehensive test file: `Tests/test_viewer_combat_visibility.lua`
- Tests all scenarios: out of combat, in combat, and combat transitions
- Verifies correct behavior for mixed settings (some viewers hidden, others shown)
- **Added icon refresh testing** to ensure proper icon restoration
- Confirmed all syntax checks pass

## Feature Behavior

### Out of Combat
- Viewers with `hideOutOfCombat = true`: Hidden
- Viewers with `hideOutOfCombat = false`: Shown (default)
- Mixed settings work independently

### In Combat
- All viewers are shown regardless of `hideOutOfCombat` setting
- Ensures players never miss important cooldown information during combat

### Combat Transitions
- Entering combat: All viewers become visible
- Leaving combat: Viewers revert to their individual `hideOutOfCombat` settings

## Configuration Location
```
ESC → Options → AddOns → Cooldown Manager → Viewers → Layout → [Viewer Name] → Hide Out of Combat
```

## Technical Notes
- Uses existing combat event system (PLAYER_REGEN_ENABLED/DISABLED)
- Integrates with existing `UpdateCombatVisibility()` function
- **CRITICAL**: Properly triggers icon refresh when viewers are shown after being hidden
- Comprehensive icon management: `UpdateAllCustomIcons()`, `UpdateBuffIconVisibility()`, `TrySkin()`, `LayoutCooldownIcons()`
- No conflicts with individual icon visibility logic
- Maintains compatibility with resource bar combat visibility
- Clean separation between viewer and icon management
- **Fixed previous issue**: Now ensures all class abilities and custom spells appear when viewers are restored

## User Benefits
- Reduces UI clutter when not in combat
- Individual control over each viewer type
- Automatic display during combat when cooldowns matter most
- **All icons properly restored**: No missing abilities when transitioning in/out of combat
- No impact on functionality - purely visual quality of life improvement

This implementation successfully addresses the previous issues with hiding individual icons and provides a clean, user-friendly solution for managing viewer visibility based on combat state. The critical fix ensures that when viewers are shown after being hidden, all appropriate icons (both class abilities and custom spells) are properly restored and displayed.
