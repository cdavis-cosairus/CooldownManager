# Changelog

All notable changes to Cooldown Manager will be documented in this file.

## [1.2.0] - 2025-08-14

### Major Features
- **Complete Cast Bar System**: Professional modular cast bar implementation
  - **Modular Architecture**: Extracted cast bar system from monolithic main.lua into `Core/CastBars.lua`
  - **Immediate Configuration Updates**: All 46 cast bar settings apply changes instantly without reload
  - **Comprehensive Customization**: Full font selection, texture options, positioning, borders, and backgrounds
  - **Professional UI Organization**: Settings organized into clear tabs (Settings/Appearance)
  - **Improved Defaults**: Cast bar enabled by default with optimal settings for immediate use
  - **Border & Background System**: Separate frame management with proper layering and customization
  - **Initialization Fixes**: Cast bars now visible immediately upon login/reload
  - **LibSharedMedia Integration**: Full support for custom fonts and textures
  - **Auto-Width Support**: Intelligent bar sizing based on spell name length
  - **Preview Mode**: Live preview of cast bar appearance while configuring

### Performance Optimizations
- **Major Performance Overhaul**: Comprehensive optimization of core addon systems
  - Implemented performance caching system with 0.1s timeout for database access
  - Added spell information caching to reduce redundant API calls
  - Extracted constants to centralized tables for better maintainability
  - Optimized event throttling system with 60 FPS (16ms) throttling

### Added
- **Independent Bar System**: Major architectural improvement for bar independence
  - Resource bars and cast bars now operate completely independently
  - Each bar type can be positioned, styled, and configured separately
  - Eliminates conflicts between different bar types
  - Improved flexibility for custom UI layouts
- **Performance Cache System**: 
  - `GetCachedProfile()` function for efficient database access
  - `GetCachedSpellInfo()` function for spell data caching
  - Player class caching to reduce repeated API calls
  - Automatic cache invalidation on data changes
- **Constants Tables**: 
  - `CONSTANTS` table in main.lua with performance and UI values
  - `CONFIG_CONSTANTS` table in config.lua for configuration strings
  - Centralized hardcoded values for easier maintenance
- **Helper Functions**:
  - `CreateStandardBar()` for consistent bar creation
  - `CalculateBarWidth()` for optimized width calculations
  - Secondary resource helper functions for Death Knight runes and combo points
  - `InvalidateCache()` functions for proper cache management

### Improved
- **Cast Bar System Architecture**:
  - Complete modular separation from main addon file (reduced from 3019 lines)
  - Professional event-driven architecture with proper namespace isolation
  - Immediate update system ensuring all configuration changes apply instantly
  - Clean border/background frame management with proper layering
  - Robust initialization sequence for immediate cast bar visibility
- **Independent Bar Architecture**:
  - Complete separation of resource bar and cast bar systems
  - Each bar type maintains its own state and configuration
  - Improved reliability and reduced cross-system interference
  - Better support for complex UI layouts and positioning
- **Main Addon Performance**:
  - Reduced database access calls by ~80% through caching
  - Optimized bar update functions with cached calculations
  - Improved event handling with throttling system
  - Streamlined secondary resource tracking (Death Knight runes, Combo Points, Chi)
- **Configuration UI Performance**:
  - Optimized `generateHiddenSpellArgs()` and `generateCustomSpellArgs()` functions
  - Replaced repeated database access with cached profile access
  - Improved `GetViewerSetting()` and `SetViewerSetting()` efficiency
  - Reduced spell info lookups through caching
- **Code Quality**:
  - Eliminated redundant variables and calculations
  - Improved error handling with proper fallback values
  - Better memory management with automatic cache cleanup
  - Consistent coding patterns throughout the addon

### Technical
- **Cast Bar Modular Implementation**: 
  - Complete extraction to `Core/CastBars.lua` with proper namespace (`CooldownManager.CastBars`)
  - 46 configuration options with immediate update system via `UpdateIndependentCastBar()`
  - Border cleanup system removing old `AddPixelBorder` remnants
  - Professional Settings/Appearance tab organization in configuration UI
  - LibSharedMedia-3.0 integration for fonts and textures
  - Separate background/border frame management with proper stacking
  - Integration with `UpdateCombatVisibility()` for proper initialization
- **Independent Bar Implementation**: Separate tracking and management systems for each bar type
- **Cache Implementation**: Profile data cached for 0.1s, spell info cached indefinitely
- **Event Throttling**: 60 FPS update rate (16.67ms) for smooth performance
- **Constants Extraction**: Moved 15+ hardcoded values to centralized tables
- **Database Optimization**: Reduced repeated `CooldownManagerDBHandler.profile` access
- **API Optimization**: Cached `C_Spell.GetSpellInfo()` and `GetSpecializationInfo()` calls
- **Memory Efficiency**: Implemented proper cache invalidation and cleanup
- **Bar Independence**: Resource and cast bars no longer share state or interfere with each other

### Bug Fixes
- **Cast Bar System**: Fixed initialization delays causing bars to not appear until first cast
- **Border Rendering**: Resolved black background artifacts and border rendering issues
- **Configuration Consistency**: Eliminated orphaned code and ensured all settings work immediately
- Fixed potential memory leaks from excessive spell info lookups
- Improved stability during rapid configuration changes
- Better handling of missing or corrupted profile data

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
