# Cooldown Manager

A comprehensive World of Warcraft addon that enhances and customizes the Blizzard Cooldown Manager system with advanced features and complete visual control.

## Features

### 🎯 **Enhanced Cooldown Tracking**
- **Three Specialized Viewers**: Essential, Utility, and Buff Icon cooldown viewers
- **Custom Spell Management**: Add/remove spells by Spell ID for each viewer
- **Spell Priority Sorting**: Organize spells by importance per specialization
- **Hidden Spell Control**: Hide unwanted spells from viewers
- **Trinket Tracking**: Optional cooldown tracking for equipped trinkets

### 🎨 **Complete Visual Customization**
- **Icon Reskinning Toggle**: Enable/disable custom styling vs original Blizzard look
- **Customizable Borders**: Adjustable thickness and color
- **Icon Zoom/Cropping**: Fine-tune icon appearance
- **Layout Control**: Icons per row, spacing, and sizing
- **Font Customization**: Cooldown and charge text sizing and positioning

### ⚔️ **Combat Features**
- **Combat Visibility**: Hide viewers when out of combat (per viewer)
- **Buff Duration Swipe**: Toggle for buff duration display
- **Range Indicators**: Visual feedback for spell range
- **Proc Glow Integration**: Spell activation overlays

### 📊 **Resource Bars**
- **Class-Specific Tracking**: Essence, Soul Shards, Holy Power, Chi, Combo Points, Runes, etc.
- **Smart Resource Detection**: Automatically detects relevant secondary power types
- **Visual Customization**: Height, texture, font size, colors
- **Class/Power Colors**: Use class colors or custom colors
- **Segmented Displays**: Tick marks for discrete resources

### 📋 **Cast Bars**
- **Per-Viewer Cast Bars**: Individual cast bars for each cooldown viewer
- **Full Customization**: Height, position, colors, textures, font size
- **Class Color Support**: Match your class theme or use custom colors
- **Real-time Updates**: Live casting progress with spell icons

### ⚙️ **Advanced Options**
- **Profile Support**: AceDB profile management
- **Edit Mode Integration**: Seamless integration with WoW's Edit Mode
- **Spec-Specific Settings**: Different configurations per specialization
- **Pixel-Perfect Positioning**: Precise alignment and scaling

## Installation

1. Download the latest release
2. Extract to your `World of Warcraft\_retail_\Interface\AddOns\` folder
3. Restart World of Warcraft or reload your UI (`/reload`)
4. Configure via `/cdm` or the Interface Options

## Usage

### Basic Commands
- **`/cdm`** - Open configuration panel

### Configuration Tabs
- **Main Options**: Global settings, icon reskinning toggle, borders, zoom
- **Viewer Layouts**: Per-viewer icon sizing, spacing, columns, font settings
- **Resource Bars**: Secondary power tracking configuration
- **Cast Bars**: Cast bar customization and combat visibility
- **Hide Spells**: Remove unwanted spells by Spell ID
- **Add Spells**: Add custom spells by Spell ID
- **Sort Spells**: Drag-and-drop spell priority ordering

### Pro Tips
- Use **Edit Mode** to position viewers perfectly
- **Spec-specific settings** automatically save different configurations
- **Hide Out of Combat** works great for PvP to reduce clutter
- **Trinket tracking** is perfect for tracking powerful cooldown items

## Dependencies

This addon uses the following libraries (included):
- Ace3 Framework (AceAddon, AceDB, AceConfig, AceGUI, etc.)
- LibSharedMedia-3.0
- LibStub
- Various supporting libraries for enhanced functionality

## Compatibility

- **World of Warcraft**: Retail (Dragonflight and later)
- **UI Scale**: Fully supports all UI scales with pixel-perfect rendering
- **Languages**: All client languages supported

## Support

If you encounter any issues or have suggestions:
1. Check that you're using the latest version
2. Try `/reload` to refresh the addon
3. Reset settings if needed through the Profiles tab

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is open source. Please respect the addon development community and give credit where appropriate.

---

**Enhance your cooldown management experience with complete control and customization!**
