-- Core utilities and constants for CooldownManager
local AceDB = LibStub("AceDB-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- Make CooldownManager namespace global
CooldownManager = CooldownManager or {}

-- Performance Cache
local cachedProfile = nil
local lastProfileUpdate = 0

-- Constants
CooldownManager.CONSTANTS = {
    FONTS = {
        DEFAULT = "Interface\\AddOns\\CooldownManager\\Fonts\\FRIZQT__.TTF"
    },
    TEXTURES = {
        DEFAULT_STATUSBAR = "Interface\\TargetingFrame\\UI-StatusBar"
    },
    COLORS = {
        BACKGROUND = {0.1, 0.1, 0.1, 1},
        TEXT = {1, 1, 1},
        RUNE_SPECS = {
            [250] = {0.8, 0.1, 0.1}, -- Blood
            [251] = {0.2, 0.6, 1.0}, -- Frost  
            [252] = {0.1, 0.8, 0.1}  -- Unholy
        },
        COMBO_POINTS = {1, 0.85, 0.1},
        CHI = {0.4, 1, 0.6}
    },
    SIZES = {
        DEFAULT_RESOURCE_HEIGHT = 16,
        DEFAULT_CAST_HEIGHT = 22,
        DEFAULT_FONT_SIZE = 20
    }
}

-- Global variables that other modules need
CooldownManager.playerClass, CooldownManager.playerClassFile = UnitClass("player")

-- Viewer names
CooldownManager.viewers = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
}

-- Global storage for bars (accessible to other modules)
CooldownManagerResourceBars = CooldownManagerResourceBars or {}
CooldownManagerCastBars = CooldownManagerCastBars or {}

-- Performance tracking (debug mode)
local perfStats = {
    resourceBarUpdates = 0,
    totalTime = 0
}

-- Event throttling system
local eventThrottle = {}

-- Cached helper functions
function CooldownManager.GetCachedProfile()
    local now = GetTime()
    if not cachedProfile or (now - lastProfileUpdate) > 0.1 then
        cachedProfile = CooldownManagerDBHandler and CooldownManagerDBHandler.profile
        lastProfileUpdate = now
    end
    return cachedProfile
end

function CooldownManager.GetCachedPlayerClass()
    return CooldownManager.playerClass, CooldownManager.playerClassFile
end

function CooldownManager.ThrottleEvent(eventName, delay)
    local now = GetTime()
    if eventThrottle[eventName] and (now - eventThrottle[eventName]) < delay then
        return true -- throttled
    end
    eventThrottle[eventName] = now
    return false -- not throttled
end

function CooldownManager.TrackPerformance(funcName, func)
    return function(...)
        local start = debugprofilestop()
        local result = {func(...)}
        local elapsed = debugprofilestop() - start
        
        perfStats[funcName] = (perfStats[funcName] or 0) + 1
        perfStats.totalTime = perfStats.totalTime + elapsed
        
        -- Log performance if taking too long (> 1ms)
        if elapsed > 1 then
            print(string.format("CooldownManager: %s took %.2fms", funcName, elapsed))
        end
        
        return unpack(result)
    end
end

-- Pixel perfect calculations
local screenHeight = select(2, GetPhysicalScreenSize())
local perfect = 768 / screenHeight
local mult = perfect / UIParent:GetScale()

function PixelPerfect(v)
    local screenWidth, screenHeight = GetPhysicalScreenSize()
    local uiScale = UIParent:GetEffectiveScale()
    local pixelSize = 768 / screenHeight / uiScale
    return pixelSize * math.floor(v / pixelSize + 0.51)
end

-- Helper function to create standardized bars
function CooldownManager.CreateStandardBar(name, barType, settings)
    local bar = CreateFrame("StatusBar", name, UIParent)
    
    -- Set basic properties
    bar:SetMinMaxValues(0, barType == "cast" and 1 or 100)
    bar:SetValue(barType == "cast" and 0 or 100)
    
    -- Set texture
    local texture = settings.texture or CooldownManager.CONSTANTS.TEXTURES.DEFAULT_STATUSBAR
    if settings.textureName and LSM then
        texture = LSM:Fetch("statusbar", settings.textureName) or texture
    end
    bar:SetStatusBarTexture(texture)
    
    -- Set size
    local height = settings.height or (barType == "cast" and CooldownManager.CONSTANTS.SIZES.DEFAULT_CAST_HEIGHT or CooldownManager.CONSTANTS.SIZES.DEFAULT_RESOURCE_HEIGHT)
    bar:SetHeight(PixelPerfect(height))
    
    -- Create background
    bar.Background = bar:CreateTexture(nil, "BACKGROUND")
    bar.Background:SetAllPoints()
    bar.Background:SetColorTexture(unpack(CooldownManager.CONSTANTS.COLORS.BACKGROUND))
    
    -- Create text frame if needed
    if barType ~= "secondary" then
        bar.TextFrame = CreateFrame("Frame", nil, bar)
        bar.TextFrame:SetAllPoints(bar)
        bar.TextFrame:SetFrameLevel(bar:GetFrameLevel() + 10)
        
        bar.Text = bar.TextFrame:CreateFontString(nil, "OVERLAY")
        local fontSize = settings.fontSize or CooldownManager.CONSTANTS.SIZES.DEFAULT_FONT_SIZE
        bar.Text:SetFont(CooldownManager.CONSTANTS.FONTS.DEFAULT, fontSize, "OUTLINE")
        bar.Text:SetPoint("CENTER", bar.TextFrame, "CENTER", PixelPerfect(2), PixelPerfect(1))
        bar.Text:SetTextColor(unpack(CooldownManager.CONSTANTS.COLORS.TEXT))
    end
    
    return bar
end

-- Helper function for width calculations
function CooldownManager.CalculateBarWidth(settings, viewer)
    if not settings.autoWidth then
        return settings.width or 300
    end
    
    local width
    if viewer.Selection then
        width = viewer.Selection:GetWidth()
        if width == 0 or not width then
            -- Fallback calculation
            local viewerSettings = CooldownManager.GetCachedProfile().viewers[viewer:GetName()] or {}
            local size = viewerSettings.iconSize or 58
            local spacing = (viewerSettings.iconSpacing or -4) - 2
            local columns = viewerSettings.iconColumns or 14
            width = (size + spacing) * columns - spacing
        else
            local padding = 6
            width = width - (padding * 3)
        end
    else
        -- Fallback calculation if no Selection frame
        local viewerSettings = CooldownManager.GetCachedProfile().viewers[viewer:GetName()] or {}
        local size = viewerSettings.iconSize or 58
        local spacing = (viewerSettings.iconSpacing or -4) - 2
        local columns = viewerSettings.iconColumns or 14
        width = (size + spacing) * columns - spacing
    end
    
    return math.max(width or 300, 50)
end

-- Helper function for creating secondary resource components
function CooldownManager.CreateSecondaryResourceComponent(parent, texture, width, height)
    local component = CreateFrame("StatusBar", nil, parent)
    component:SetStatusBarTexture(texture)
    component:SetMinMaxValues(0, 1)
    component:SetHeight(PixelPerfect(height))
    component:SetWidth(PixelPerfect(width))
    return component
end

-- Utility functions for finding values in tables
function tIndexOf(t, val)
    for i, v in ipairs(t) do
        if v == val then return i end
    end
    return nil
end

-- Edit mode helper
function InEditMode()
    return (EditModeManagerFrame and EditModeManagerFrame:HasActiveChanges()) or (EditModeManagerFrame and EditModeManagerFrame.editModeActive)
end

-- Aura helper function
function GetAuraDataBySpellID(unit, spellID)
    if not UnitExists(unit) or (not UnitCanAssist("player", unit) and not UnitCanAttack("player", unit)) then
        return nil
    end

    -- Check buffs
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then break end
        if aura.spellId == spellID then
            return aura
        end
    end

    -- Check harmful auras applied by the player
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
        if not aura then break end
        if aura.spellId == spellID and aura.sourceUnit == "player" then
            return aura
        end
    end

    return nil
end

-- Add pixel border function
function AddPixelBorder(frame)
    if not frame then return end

    local dbProfile = CooldownManagerDBHandler.profile or {}
    local thickness = dbProfile.borderSize or 1
    local color = dbProfile.borderColor or { r = 0, g = 0, b = 0 }

    frame.__borderParts = frame.__borderParts or {}

    local anchor = frame.Icon or frame -- anchor to Icon if it exists, otherwise to frame itself
    local inset = PixelPerfect(-1)

    if #frame.__borderParts == 0 then
        local function CreateLine()
            local line = frame:CreateTexture(nil, "OVERLAY")
            return line
        end

        local top = CreateLine()
        top:SetPoint("TOPLEFT", anchor, "TOPLEFT", PixelPerfect(inset), PixelPerfect(-inset))
        top:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", PixelPerfect(-inset), PixelPerfect(-inset))
        
        local bottom = CreateLine()
        bottom:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", PixelPerfect(inset), PixelPerfect(inset))
        bottom:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", PixelPerfect(-inset), PixelPerfect(inset))
        
        local left = CreateLine()
        left:SetPoint("TOPLEFT", anchor, "TOPLEFT", PixelPerfect(inset), PixelPerfect(-inset))
        left:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", PixelPerfect(inset), PixelPerfect(inset))
        
        local right = CreateLine()
        right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", PixelPerfect(-inset), PixelPerfect(-inset))
        right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", PixelPerfect(-inset), PixelPerfect(inset))

        frame.__borderParts = { top, bottom, left, right }
    end

    local top, bottom, left, right = unpack(frame.__borderParts)
    if top and bottom and left and right then
        top:SetHeight(PixelPerfect(thickness))
        bottom:SetHeight(PixelPerfect(thickness))
        left:SetWidth(PixelPerfect(thickness))
        right:SetWidth(PixelPerfect(thickness))

        for _, line in ipairs(frame.__borderParts) do
            line:SetColorTexture(color.r, color.g, color.b, 1)
            line:SetShown(thickness > 0)
        end
    end
end

-- Expose essential functions globally for backward compatibility
PixelPerfect = PixelPerfect
AddPixelBorder = AddPixelBorder
GetAuraDataBySpellID = GetAuraDataBySpellID
tIndexOf = tIndexOf
InEditMode = InEditMode
