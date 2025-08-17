# Changelog

All notable changes to Cooldown Manager will be documented in this file.

## [1.3.0] - 2025-08-16

### Major Code Deduplication & Architecture Overhaul
- **Comprehensive Code Deduplication**: Eliminated over 1,500 lines of duplicate code
  - Reduced main.lua from ~1,600+ lines to 173 lines (89% reduction)
  - Systematic extraction of functionality into specialized Core modules
  - Enhanced code organization with clear separation of concerns

### New Core Modules
- **Core/IconManager.lua**: Complete icon management system
  - `LayoutCooldownIcons()`, `UpdateAllCustomIcons()`, `CreateCustomIcon()`
  - Centralized all icon layout, creation, and update functionality
- **Core/ViewerManager.lua**: Comprehensive viewer lifecycle management
  - `TrySkin()`, `ProtectViewer()`, `SkinViewer()`, `HookEditModeUpdates()`, `HandleTrinketChange()`
  - Complete viewer protection, styling, and edit mode integration
- **Core/BuffViewer.lua**: Specialized buff icon management
  - `HookBuffViewerLayout()`, `UpdateBuffIconVisibility()`
  - Dedicated buff viewer layout and visibility management
- **Enhanced Core/Utils.lua**: Expanded shared utilities
  - `IsSpellUsableByPlayerClass()`, `PixelPerfect()`, `AddPixelBorder()`
  - Consolidated utility functions for positioning and validation
- **Enhanced Core/ResourceBars.lua**: Advanced resource tracking
  - `UpdateAllResourceBars()` with essence tracking and 120 FPS updates
  - Centralized resource bar coordination and performance optimization

### Code Quality & Runtime Safety
- **Eliminated Specific Duplications**: Removed 1,505+ lines across:
  - Icon management functions (221 lines)
  - Viewer management functions (390 lines)
  - Event handling and buff management (94 lines)
  - Code cleanup: excessive spacing and comments (29 lines)
- **Runtime Safety Improvements**:
  - Added conditional function calls to prevent nil value errors during addon loading
  - Implemented defensive programming patterns for event handlers
  - Protected all Core module function calls from timing-based failures

### Technical Architecture
- **Global Function Exposure**: Maintained backward compatibility through careful global exposure
- **Loading Order Optimization**: Proper .toc file ensures Core modules load before main.lua
- **Module Independence**: Each Core module operates independently with clear interfaces

### Bug Fixes
- **Runtime Error Resolution**: Fixed "attempt to call global function (a nil value)" errors
- **Timing Issues**: Resolved function availability during addon loading sequence
- **Event Handler Safety**: Protected Core module function calls with conditional checks

## [1.2.0] - 2025-08-14

### Major Features
- **Complete Cast Bar System**: Professional modular cast bar implementation
  - Extracted cast bar system into dedicated `Core/CastBars.lua` module
  - 46 cast bar configuration options with instant updates (no reload required)
  - Comprehensive customization: fonts, textures, positioning, borders, backgrounds
  - Settings organized into clear tabs (Settings/Appearance)
  - Cast bars visible immediately upon login/reload
  - LibSharedMedia integration for custom fonts and textures
  - Auto-width support with intelligent bar sizing
  - Live preview mode for configuration changes

### Performance & Caching System
- **Performance Cache System**: Major optimization of database and API access
  - `GetCachedProfile()` - 0.1s timeout for database access (80% reduction in calls)
  - `GetCachedSpellInfo()` - Spell information caching to reduce API calls
  - Player class caching and automatic cache invalidation
  - Event throttling system optimized to 60 FPS (16ms)
- **Constants & Helper Functions**:
  - `CONSTANTS` table for performance and UI values
  - `CONFIG_CONSTANTS` table for configuration strings
  - `CreateStandardBar()`, `CalculateBarWidth()`, `InvalidateCache()` functions
  - Secondary resource helpers for Death Knight runes and combo points

### Independent Bar Architecture
- **Bar Independence**: Complete separation of resource and cast bar systems
  - Each bar type operates independently with separate state and configuration
  - Eliminates conflicts between different bar types
  - Improved flexibility for custom UI layouts
  - Better reliability and reduced cross-system interference

### Cast Bar Technical Implementation
- **Modular Architecture**: Professional namespace isolation (`CooldownManager.CastBars`)
- **Border & Background System**: Separate frame management with proper layering
- **Configuration Performance**: Optimized UI functions with cached database access
- **Memory Management**: Proper cache cleanup and automatic invalidation

### Bug Fixes
- **Cast Bar Initialization**: Fixed delays causing bars to not appear until first cast
- **Border Rendering**: Resolved black background artifacts
- **Memory Leaks**: Fixed excessive spell info lookups
- **Configuration Stability**: Improved handling during rapid setting changes

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
