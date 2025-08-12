# Changelog

All notable changes to Cooldown Manager will be documented in this file.

## [1.1.0] - 2025-08-12

### Added
- **Icon Reskinning Toggle**: New option to enable/disable custom styling
  - Located in main options panel
  - Allows users to choose between custom styling or original Blizzard appearance
  - Maintains all functionality while giving visual choice
- **Combat Visibility Feature**: Hide viewers when out of combat
  - Per-viewer toggle in Cast Bars tab
  - Automatically shows/hides based on combat state
  - Great for reducing UI clutter in non-combat situations
- **Class Power Color Option**: New resource bar coloring option
  - "Use Class Power Color" toggle in Resource Bars tab
  - Colors resource bars based on your class's power type color
  - Provides authentic power type theming alongside existing class color option

### Improved
- Updated `.toc` file with better organization and metadata
- Enhanced code organization and documentation
- Better error handling in core functions

### Technical
- Added `enableIconReskinning` profile setting (defaults to enabled)
- Added `hideOutOfCombat` per-viewer setting
- Added `resourceBarPowerColor` per-viewer setting
- Implemented `UpdateCombatVisibility()` function with event handling
- Combat events: `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED`

## [1.0.0] - Previous Release

### Features
- Complete cooldown viewer customization
- Resource bar tracking for all classes
- Cast bar integration
- Custom spell management
- Visual styling options
- Edit Mode integration
- Profile management
- Trinket cooldown tracking
