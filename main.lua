local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDB = LibStub("AceDB-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- Performance Cache
local playerClass, playerClassFile = UnitClass("player")
local cachedProfile = nil
local lastProfileUpdate = 0

-- Constants
local CONSTANTS = {
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

-- Cached helper functions - make globally accessible for modules
function GetCachedProfile()
    local now = GetTime()
    if not cachedProfile or (now - lastProfileUpdate) > 0.1 then
        cachedProfile = CooldownManagerDBHandler and CooldownManagerDBHandler.profile
        lastProfileUpdate = now
    end
    return cachedProfile
end

local function GetCachedPlayerClass()
    return playerClass, playerClassFile
end

-- Event throttling system
local eventThrottle = {}
local function ThrottleEvent(eventName, delay)
    local now = GetTime()
    if eventThrottle[eventName] and (now - eventThrottle[eventName]) < delay then
        return true -- throttled
    end
    eventThrottle[eventName] = now
    return false -- not throttled
end

-- Performance tracking (debug mode)
local perfStats = {
    resourceBarUpdates = 0,
    totalTime = 0
}

local function TrackPerformance(funcName, func)
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

local viewers = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
}

LayoutCooldownIcons = LayoutCooldownIcons or function() end


local protectedViewers = {}

local function InEditMode()
    return (EditModeManagerFrame and EditModeManagerFrame:HasActiveChanges()) or (EditModeManagerFrame and EditModeManagerFrame.editModeActive)
end


local function AddSpellIDToTooltip(tooltip, data)
    local spellName, spellID = tooltip:GetSpell()
    if spellID then
        tooltip:AddLine(" ")
        tooltip:AddLine("Spell ID: " .. tostring(spellID), 1, 1, 1)
    end
end
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, AddSpellIDToTooltip)


local screenHeight = select(2, GetPhysicalScreenSize())
local perfect = 768 / screenHeight
local mult = perfect / UIParent:GetScale()

-- Make PixelPerfect function globally accessible for modules
function PixelPerfect(v)
    local screenWidth, screenHeight = GetPhysicalScreenSize()
    local uiScale = UIParent:GetEffectiveScale()
    local pixelSize = 768 / screenHeight / uiScale
    return pixelSize * math.floor(v / pixelSize + 0.51)
end

-- Helper function to create standardized bars
local function CreateStandardBar(name, barType, settings)
    local bar = CreateFrame("StatusBar", name, UIParent)
    
    -- Set basic properties
    bar:SetMinMaxValues(0, barType == "cast" and 1 or 100)
    bar:SetValue(barType == "cast" and 0 or 100)
    
    -- Set texture
    local texture = settings.texture or CONSTANTS.TEXTURES.DEFAULT_STATUSBAR
    if settings.textureName and LSM then
        texture = LSM:Fetch("statusbar", settings.textureName) or texture
    end
    bar:SetStatusBarTexture(texture)
    
    -- Set size
    local height = settings.height or (barType == "cast" and CONSTANTS.SIZES.DEFAULT_CAST_HEIGHT or CONSTANTS.SIZES.DEFAULT_RESOURCE_HEIGHT)
    bar:SetHeight(PixelPerfect(height))
    
    -- Create background
    bar.Background = bar:CreateTexture(nil, "BACKGROUND")
    bar.Background:SetAllPoints()
    bar.Background:SetColorTexture(unpack(CONSTANTS.COLORS.BACKGROUND))
    
    -- Create text frame if needed
    if barType ~= "secondary" then
        bar.TextFrame = CreateFrame("Frame", nil, bar)
        bar.TextFrame:SetAllPoints(bar)
        bar.TextFrame:SetFrameLevel(bar:GetFrameLevel() + 10)
        
        bar.Text = bar.TextFrame:CreateFontString(nil, "OVERLAY")
        local fontSize = settings.fontSize or CONSTANTS.SIZES.DEFAULT_FONT_SIZE
        bar.Text:SetFont(CONSTANTS.FONTS.DEFAULT, fontSize, "OUTLINE")
        bar.Text:SetPoint("CENTER", bar.TextFrame, "CENTER", PixelPerfect(2), PixelPerfect(1))
        bar.Text:SetTextColor(unpack(CONSTANTS.COLORS.TEXT))
    end
    
    return bar
end

-- Helper function for width calculations
local function CalculateBarWidth(settings, viewer)
    if not settings.autoWidth then
        return settings.width or 300
    end
    
    local width
    if viewer.Selection then
        width = viewer.Selection:GetWidth()
        if width == 0 or not width then
            -- Fallback calculation
            local viewerSettings = GetCachedProfile().viewers[viewer:GetName()] or {}
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
        local viewerSettings = GetCachedProfile().viewers[viewer:GetName()] or {}
        local size = viewerSettings.iconSize or 58
        local spacing = (viewerSettings.iconSpacing or -4) - 2
        local columns = viewerSettings.iconColumns or 14
        width = (size + spacing) * columns - spacing
    end
    
    return math.max(width or 300, 50)
end

-- Helper function for creating secondary resource components (runes, combo points, chi)
local function CreateSecondaryResourceComponent(parent, texture, width, height)
    local component = CreateFrame("StatusBar", nil, parent)
    component:SetStatusBarTexture(texture)
    component:SetMinMaxValues(0, 1)
    component:SetHeight(PixelPerfect(height))
    component:SetWidth(PixelPerfect(width))
    return component
end

-- Helper function for updating Death Knight runes
local function UpdateDeathKnightRunes(sbar, totalRunes, runeWidth, texture)
    sbar.Runes = sbar.Runes or {}
    local specID = GetSpecializationInfo(GetSpecialization() or 0)
    local color = CONSTANTS.COLORS.RUNE_SPECS[specID] or {0.7, 0.7, 0.7}
    
    for i = 1, totalRunes do
        local rune = sbar.Runes[i]
        if not rune then
            rune = CreateSecondaryResourceComponent(sbar, texture, runeWidth, sbar:GetHeight())
            sbar.Runes[i] = rune
        end
        
        rune:Show()
        rune:SetWidth(PixelPerfect(runeWidth))
        rune:ClearAllPoints()
        if i == 1 then
            rune:SetPoint("LEFT", sbar, "LEFT", 0, 0)
        else
            rune:SetPoint("LEFT", sbar.Runes[i-1], "RIGHT", PixelPerfect(1), 0)
        end
        
        -- Update rune state
        local start, duration, ready = GetRuneCooldown(i)
        if ready then
            rune:SetValue(1)
            rune:SetStatusBarColor(color[1], color[2], color[3], 1)
        elseif start and duration and duration > 0 then
            local elapsed = GetTime() - start
            rune:SetValue(math.min(elapsed / duration, 1))
            rune:SetStatusBarColor(color[1] * 0.4, color[2] * 0.4, color[3] * 0.4, 1)
        else
            rune:SetValue(1)
            rune:SetStatusBarColor(color[1], color[2], color[3], 1)
        end
    end
    
    -- Hide unused runes
    for i = totalRunes + 1, #sbar.Runes do
        if sbar.Runes[i] then sbar.Runes[i]:Hide() end
    end
end

-- Helper function for updating combo points/chi
local function UpdateComboPointsOrChi(sbar, maxPoints, currentPoints, pointWidth, texture, colorActive, colorInactive)
    sbar.Points = sbar.Points or {}
    
    for i = 1, maxPoints do
        local point = sbar.Points[i]
        if not point then
            point = CreateSecondaryResourceComponent(sbar, texture, pointWidth, sbar:GetHeight())
            sbar.Points[i] = point
        end
        
        point:Show()
        point:SetWidth(PixelPerfect(pointWidth))
        point:ClearAllPoints()
        if i == 1 then
            point:SetPoint("LEFT", sbar, "LEFT", 0, 0)
        else
            point:SetPoint("LEFT", sbar.Points[i - 1], "RIGHT", PixelPerfect(1), 0)
        end
        
        if i <= currentPoints then
            point:SetValue(1)
            point:SetStatusBarColor(colorActive[1], colorActive[2], colorActive[3], 1)
        else
            point:SetValue(0)
            point:SetStatusBarColor(colorInactive[1], colorInactive[2], colorInactive[3], 1)
        end
    end
    
    -- Hide unused points
    for i = maxPoints + 1, #sbar.Points do
        if sbar.Points[i] then sbar.Points[i]:Hide() end
    end
end





local secondaryPowerTypes = {
    ["EVOKER"] = Enum.PowerType.Essence,
    ["WARLOCK"] = Enum.PowerType.SoulShards,
    ["PALADIN"] = Enum.PowerType.HolyPower,
    ["PRIEST"] = function()
        local spec = GetSpecialization()
        if spec == 3 then -- Shadow
            return Enum.PowerType.Insanity
        end
        return Enum.PowerType.Mana
    end,
    ["SHAMAN"] = function()
        local spec = GetSpecialization()
        if spec == 1 then -- Elemental
            return Enum.PowerType.Maelstrom
        elseif spec == 2 then -- Enhancement
            return "MAELSTROM_WEAPON_BUFF"
        end
        return Enum.PowerType.Mana
    end,
    ["DRUID"] = function()
        local spec = GetSpecialization()
        if spec == 1 then -- Balance
            return Enum.PowerType.LunarPower
        end
        return Enum.PowerType.Mana
    end,
    ["MAGE"] = function()
        local specID = GetSpecializationInfo(GetSpecialization())
        if specID == 62 then -- Arcane
            return Enum.PowerType.ArcaneCharges
        elseif specID == 64 then -- Frost
            return "ICICLE_BUFF"
        end
        return Enum.PowerType.Mana
    end,
    
}



local function GetRelevantPowerType()
    local _, class = UnitClass("player")
    local secondary = secondaryPowerTypes[class]
    
    if type(secondary) == "function" then
        return secondary()
    elseif secondary then
        return secondary
    else
        return UnitPowerType("player")
    end
end

--
local essenceData = {
    current = 0,
    max = 0,
    lastUpdate = 0,
    partial = 0,
    active = false,
    rechargeTime = 5, -- default safe 5s fallback
}

local function GetAuraDataBySpellID(unit, spellID)
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







local function GetEssenceRechargeTime()
    local regen = GetPowerRegenForPowerType(Enum.PowerType.Essence)
    if regen and regen > 0 then
        return 1 / regen
    end
    return 5 -- fallback 5 seconds
end


local function UpdateEssenceTracking()
    local current = UnitPower("player", Enum.PowerType.Essence)
    local max = UnitPowerMax("player", Enum.PowerType.Essence)

    if not essenceData.current then
        essenceData.current = current
        essenceData.max = max
    end

    if current < max then
        if not essenceData.active then
            essenceData.active = true
            essenceData.lastUpdate = GetTime()
            essenceData.partial = 0
            essenceData.rechargeTime = GetEssenceRechargeTime()
        end
    else
        essenceData.active = false
        essenceData.partial = 0
    end

    essenceData.current = current
    essenceData.max = max
end

-- Make these global so config.lua can access them
CooldownManagerResourceBars = {}
local resourceBars = CooldownManagerResourceBars

-- Single independent resource bar instead of per-viewer bars
local independentResourceBar = nil
local independentSecondaryResourceBar = nil

local secondaryResourceBars = secondaryResourceBars or {}

local function UpdateResourceBar(viewer)
    if not viewer then return end

    local name = viewer:GetName()
    if not CooldownManagerDBHandler.profile.viewers[name] then return end

    local settings = CooldownManagerDBHandler.profile.viewers[name]
    local showResourceBar = settings.showResourceBar
    
    -- Don't interfere with combat visibility - only return if resource bar is completely disabled
    -- Let UpdateCombatVisibility() handle showing/hiding based on combat settings
    if not showResourceBar then
        -- Only hide if the bar exists and resource bar feature is completely disabled
        if resourceBars[name] then resourceBars[name]:Hide() end
        if secondaryResourceBars[name] then secondaryResourceBars[name]:Hide() end
        return
    end

    -- This function only creates/updates bars - UpdateCombatVisibility() handles visibility

    if not resourceBars[name] then
        local bar = CreateFrame("StatusBar", nil, viewer)
        bar:SetStatusBarTexture(settings.resourceBarTexture or "Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(0, 0.6, 1, 1)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(100)
    
        -- Set both size values
        local width = PixelPerfect(viewer:GetWidth())
        local height = PixelPerfect(settings.resourceBarHeight or 16)
        bar:SetSize(width, height)
    
        bar:SetPoint("TOP", viewer, "TOP", PixelPerfect(0), PixelPerfect(settings.resourceBarOffsetY or 14))
        bar.Ticks = {}
    
        bar.Background = bar:CreateTexture(nil, "BACKGROUND")
        bar.Background:SetAllPoints()
        bar.Background:SetColorTexture(0.1, 0.1, 0.1, 1)
    
        bar.TextFrame = CreateFrame("Frame", nil, bar)
        bar.TextFrame:SetAllPoints(bar)
        bar.TextFrame:SetFrameLevel(bar:GetFrameLevel() + 10)
    
        bar.Text = bar.TextFrame:CreateFontString(nil, "OVERLAY")
        bar.Text:SetFont("Interface\\AddOns\\CooldownManager\\Fonts\\FRIZQT__.TTF", settings.resourceBarFontSize or 20, "OUTLINE")
        bar.Text:SetPoint("CENTER", bar.TextFrame, "CENTER", PixelPerfect(2), PixelPerfect(1))
        bar.Text:SetTextColor(1, 1, 1)
    
        AddPixelBorder(bar)
        resourceBars[name] = bar
    end
    
    local bar = resourceBars[name]
    
    -- Don't automatically show - let UpdateCombatVisibility handle visibility
    -- bar:Show()  -- Removed this line to prevent overriding combat visibility
    
    -- Update dynamic settings
    local width = PixelPerfect(viewer:GetWidth())
    bar:SetSize(width, PixelPerfect(settings.resourceBarHeight or 16))
    bar:SetStatusBarTexture(settings.resourceBarTexture or "Interface\\TargetingFrame\\UI-StatusBar")
    if bar.Text then
        bar.Text:SetFont("Interface\\AddOns\\CooldownManager\\Fonts\\FRIZQT__.TTF", settings.resourceBarFontSize or 20, "OUTLINE")
    end
    bar:ClearAllPoints()
    bar:SetPoint("TOP", viewer, "TOP", PixelPerfect(0), PixelPerfect(settings.resourceBarOffsetY or 14))
    

    -- Coloring
    if settings.resourceBarClassColor then
        local classColor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
        if classColor then
            bar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 1)
        end
    elseif settings.resourceBarPowerColor then
        local powerColor = GetPowerBarColor(UnitPowerType("player"))
        if powerColor then
            bar:SetStatusBarColor(powerColor.r, powerColor.g, powerColor.b, 1)
        end
    else
        local c = settings.resourceBarCustomColor or { r = 0, g = 0.6, b = 1 }
        bar:SetStatusBarColor(c.r, c.g, c.b, 1)
    end
    

    -- Smart width
    local width
    if viewer.Selection then
        width = viewer.Selection:GetWidth()
        local padding = 6
        width = width - (padding * 3)
    else
        local size = settings.iconSize or 58
        local spacing = (settings.iconSpacing or -4) - 3
        local columns = settings.iconColumns or 14
        width = (size + spacing) * math.min(columns, 1) - spacing
    end

    bar:SetWidth(PixelPerfect(width))
    if bar._lastWidth ~= width then
        bar._lastWidth = width
        bar:SetWidth(PixelPerfect(width))
        local srb = secondaryResourceBars[name]
        if srb then srb:SetWidth(PixelPerfect(width)) end
    end

    local _, class = UnitClass("player")
    local powerType = GetRelevantPowerType()

    -- Hide ticks if not applicable
    if class ~= "EVOKER" and class ~= "MAGE" then
        for _, tick in ipairs(bar.Ticks) do tick:Hide() end
    end

-- Essence ticks
if class == "EVOKER" and powerType == Enum.PowerType.Essence then
    local maxEssence = UnitPowerMax("player", Enum.PowerType.Essence) or 6
    for _, tick in ipairs(bar.Ticks) do tick:Hide() end
    for i = 1, maxEssence - 1 do
        local tick = bar.Ticks[i] or bar:CreateTexture(nil, "OVERLAY")
        tick:SetColorTexture(0, 0, 0, 1)
        tick:SetWidth(PixelPerfect(1))
        tick:SetHeight(PixelPerfect(bar:GetHeight()))
        tick:SetPoint("LEFT", bar, "LEFT", PixelPerfect((i / maxEssence) * bar:GetWidth()), 0)
        tick:Show()
        bar.Ticks[i] = tick
    end

-- Arcane Charge ticks
elseif class == "MAGE" and powerType == Enum.PowerType.ArcaneCharges then
    local maxCharges = UnitPowerMax("player", Enum.PowerType.ArcaneCharges) or 4
    for _, tick in ipairs(bar.Ticks) do tick:Hide() end
    for i = 1, maxCharges - 1 do
        local tick = bar.Ticks[i] or bar:CreateTexture(nil, "OVERLAY")
        tick:SetColorTexture(0, 0, 0, 1)
        tick:SetWidth(PixelPerfect(1))
        tick:SetHeight(PixelPerfect(bar:GetHeight()))
        tick:SetPoint("LEFT", bar, "LEFT", PixelPerfect((i / maxCharges) * bar:GetWidth()), 0)
        tick:Show()
        bar.Ticks[i] = tick
    end

-- Holy Power (Paladin - Retribution)
elseif class == "PALADIN" then
    local maxHP = UnitPowerMax("player", Enum.PowerType.HolyPower) or 5
    for _, tick in ipairs(bar.Ticks) do tick:Hide() end
    for i = 1, maxHP - 1 do
        local tick = bar.Ticks[i] or bar:CreateTexture(nil, "OVERLAY")
        tick:SetColorTexture(0, 0, 0, 1)
        tick:SetWidth(PixelPerfect(1))
        tick:SetHeight(PixelPerfect(bar:GetHeight()))
        tick:SetPoint("LEFT", bar, "LEFT", PixelPerfect((i / maxHP) * bar:GetWidth()), 0)
        tick:Show()
        bar.Ticks[i] = tick
    end
end


-- Resource value
local current, max

if powerType == "MAELSTROM_WEAPON_BUFF" then
    local aura = GetAuraDataBySpellID("player", 344179)
    current = aura and aura.applications or 0
    max = 10
elseif powerType == "ICICLE_BUFF" then
    local aura = GetAuraDataBySpellID("player", 205473) -- Icicles
    current = aura and aura.applications or 0
    max = 5

elseif powerType == Enum.PowerType.Essence then
    current = essenceData.current + (essenceData.partial or 0)
    max = essenceData.max
elseif type(powerType) == "number" then
    current = UnitPower("player", powerType)
    max = UnitPowerMax("player", powerType)
else
    current = 0
    max = 0
end




-- Segment ticks for Maelstrom Weapon
if powerType == "MAELSTROM_WEAPON_BUFF" then
    bar.Ticks = bar.Ticks or {}
    for _, tick in ipairs(bar.Ticks) do tick:Hide() end
    for i = 1, 9 do -- 10 stacks = 9 dividers
        local tick = bar.Ticks[i] or bar:CreateTexture(nil, "OVERLAY")
        tick:SetColorTexture(0, 0, 0, 1)
        tick:SetWidth(PixelPerfect(1))
        tick:SetHeight(PixelPerfect(bar:GetHeight()))
        tick:SetPoint("LEFT", bar, "LEFT", PixelPerfect((i / 10) * bar:GetWidth()), 0)
        tick:Show()
        bar.Ticks[i] = tick
    end

elseif powerType == "ICICLE_BUFF" then
    bar.Ticks = bar.Ticks or {}
    for _, tick in ipairs(bar.Ticks) do tick:Hide() end
    for i = 1, 4 do -- 5 icicles = 4 dividers
        local tick = bar.Ticks[i] or bar:CreateTexture(nil, "OVERLAY")
        tick:SetColorTexture(0, 0, 0, 1)
        tick:SetWidth(PixelPerfect(1))
        tick:SetHeight(PixelPerfect(bar:GetHeight()))
        tick:SetPoint("LEFT", bar, "LEFT", PixelPerfect((i / 5) * bar:GetWidth()), 0)
        tick:Show()
        bar.Ticks[i] = tick
    end
end


-- Bar fill
if max > 0 then
    bar:SetMinMaxValues(0, max)
    bar:SetValue(current)
    if bar.Text then
        if powerType == Enum.PowerType.Mana then
            bar.Text:SetText(math.floor((current / max) * 100) .. "%")
        else
            bar.Text:SetText(math.floor(current))
        end
    end
end


    -- Rune Bar: Death Knights only
    if class == "DEATHKNIGHT" then
        if not secondaryResourceBars[name] then
            local runeBar = CreateFrame("Frame", nil, viewer)
            runeBar:SetPoint("BOTTOM", bar, "TOP", 0, PixelPerfect(3))
            runeBar.Background = runeBar:CreateTexture(nil, "BACKGROUND")
            runeBar.Background:SetAllPoints()
            runeBar.Background:SetColorTexture(0.1, 0.1, 0.1, 1)
            runeBar.Runes = {}
            AddPixelBorder(runeBar)
            secondaryResourceBars[name] = runeBar
        end

        local runeBar = secondaryResourceBars[name]
        runeBar:Show()
        runeBar:SetWidth(PixelPerfect(width))
        runeBar:SetHeight(PixelPerfect((settings.resourceBarHeight or 16) - 2))

        for _, rune in ipairs(runeBar.Runes) do
            rune:SetHeight(PixelPerfect(runeBar:GetHeight()))
        end

        local totalRunes = 6
        local runeWidth = PixelPerfect((runeBar:GetWidth() - (totalRunes - 1)) / totalRunes)
        for i = 1, totalRunes do
            local rune = runeBar.Runes[i]
            if not rune then
                rune = CreateFrame("StatusBar", nil, runeBar)
                rune:SetStatusBarTexture(settings.resourceBarTexture or "Interface\\TargetingFrame\\UI-StatusBar")
                rune:SetMinMaxValues(0, 1)
                rune:SetValue(1)
                rune:SetHeight(PixelPerfect(runeBar:GetHeight()))
                runeBar.Runes[i] = rune
            end
            rune:Show()
            rune:SetWidth(PixelPerfect(runeWidth))
            rune:ClearAllPoints()
            if i == 1 then
                rune:SetPoint("LEFT", runeBar, "LEFT", 0, 0)
            else
                rune:SetPoint("LEFT", runeBar.Runes[i-1], "RIGHT", PixelPerfect(1), 0)
            end
        end

    -- Combo Point Bar: Rogue / Feral
    elseif (class == "ROGUE" or (class == "DRUID" and GetSpecialization() == 2)) then
        local maxCP = UnitPowerMax("player", Enum.PowerType.ComboPoints) or 5
        local currentCP = UnitPower("player", Enum.PowerType.ComboPoints) or 0

        if not secondaryResourceBars[name] then
            local cpBar = CreateFrame("Frame", nil, viewer)
            cpBar:SetPoint("BOTTOM", bar, "TOP", 0, PixelPerfect(3))
            cpBar.Background = cpBar:CreateTexture(nil, "BACKGROUND")
            cpBar.Background:SetAllPoints()
            cpBar.Background:SetColorTexture(0.1, 0.1, 0.1, 1)
            cpBar.Points = {}
            AddPixelBorder(cpBar)
            secondaryResourceBars[name] = cpBar
        end

        local cpBar = secondaryResourceBars[name]
        cpBar:Show()
        cpBar:SetWidth(PixelPerfect(width))
        cpBar:SetHeight(PixelPerfect((settings.resourceBarHeight or 16) - 2))

        local pointWidth = PixelPerfect((cpBar:GetWidth() - (maxCP - 1)) / maxCP)
        for i = 1, maxCP do
            local point = cpBar.Points[i]
            if not point then
                point = CreateFrame("StatusBar", nil, cpBar)
                point:SetStatusBarTexture(settings.resourceBarTexture or "Interface\\TargetingFrame\\UI-StatusBar")
                point:SetMinMaxValues(0, 1)
                point:SetHeight(PixelPerfect(cpBar:GetHeight()))
                cpBar.Points[i] = point
            end

            point:Show()
            point:SetWidth(PixelPerfect(pointWidth))
            point:ClearAllPoints()
            if i == 1 then
                point:SetPoint("LEFT", cpBar, "LEFT", 0, 0)
            else
                point:SetPoint("LEFT", cpBar.Points[i - 1], "RIGHT", PixelPerfect(1), 0)
            end

            if i <= currentCP then
                point:SetValue(1)
                point:SetStatusBarColor(1, 0.85, 0.1, 1) -- yellow/gold
            else
                point:SetValue(0)
                point:SetStatusBarColor(0.3, 0.3, 0.3, 1) -- dim
            end
        end

        for i = maxCP + 1, #cpBar.Points do
            if cpBar.Points[i] then cpBar.Points[i]:Hide() end
        end

    elseif class == "MONK" and GetSpecialization() == 3 then
        local maxChi = UnitPowerMax("player", Enum.PowerType.Chi) or 5
        local currentChi = UnitPower("player", Enum.PowerType.Chi) or 0
    
        if not secondaryResourceBars[name] then
            local chiBar = CreateFrame("Frame", nil, viewer)
            chiBar:SetPoint("BOTTOM", bar, "TOP", 0, PixelPerfect(3))
            chiBar.Background = chiBar:CreateTexture(nil, "BACKGROUND")
            chiBar.Background:SetAllPoints()
            chiBar.Background:SetColorTexture(0.1, 0.1, 0.1, 1)
            chiBar.Points = {}
            AddPixelBorder(chiBar)
            secondaryResourceBars[name] = chiBar
        end
    
        local chiBar = secondaryResourceBars[name]
        chiBar:Show()
        chiBar:SetWidth(PixelPerfect(width))
        chiBar:SetHeight(PixelPerfect((settings.resourceBarHeight or 16) - 2))
    
        local pointWidth = PixelPerfect((chiBar:GetWidth() - (maxChi - 1)) / maxChi)
    
        for i = 1, maxChi do
            local point = chiBar.Points[i]
            if not point then
                point = CreateFrame("StatusBar", nil, chiBar)
                point:SetStatusBarTexture(settings.resourceBarTexture or "Interface\\TargetingFrame\\UI-StatusBar")
                point:SetMinMaxValues(0, 1)
                point:SetHeight(PixelPerfect(chiBar:GetHeight()))
                chiBar.Points[i] = point
            end
    
            point:Show()
            point:SetWidth(PixelPerfect(pointWidth))
            point:ClearAllPoints()
            if i == 1 then
                point:SetPoint("LEFT", chiBar, "LEFT", 0, 0)
            else
                point:SetPoint("LEFT", chiBar.Points[i - 1], "RIGHT", PixelPerfect(1), 0)
            end
    
            if i <= currentChi then
                point:SetValue(1)
                point:SetStatusBarColor(0.4, 1, 0.6, 1)
            else
                point:SetValue(0)
                point:SetStatusBarColor(0.2, 0.4, 0.2, 1)
            end
        end
    
        for i = maxChi + 1, #chiBar.Points do
            if chiBar.Points[i] then chiBar.Points[i]:Hide() end
        end
    
    elseif secondaryResourceBars[name] then
        secondaryResourceBars[name]:Hide()
    end

    -- Don't apply combat visibility here - let UpdateCombatVisibility() handle all visibility logic
    -- This function is only responsible for creating/updating bars, not showing/hiding them
end

-- NEW: Independent Resource Bar System
local function UpdateIndependentResourceBar()
    local profile = GetCachedProfile()
    if not profile or not profile.independentResourceBar or not profile.independentResourceBar.enabled then
        if independentResourceBar then 
            independentResourceBar:Hide() 
            independentResourceBar = nil
        end
        if independentSecondaryResourceBar then 
            independentSecondaryResourceBar:Hide() 
            independentSecondaryResourceBar = nil
        end
        return
    end

    local settings = profile.independentResourceBar
    local attachToViewer = settings.attachToViewer or "EssentialCooldownViewer"
    local viewer = _G[attachToViewer]
    
    if not viewer then return end

    -- Create main resource bar if it doesn't exist
    if not independentResourceBar then
        local bar = CreateStandardBar("CooldownManagerIndependentResourceBar", "resource", settings)
        bar:SetStatusBarColor(0, 0.6, 1, 1)
        bar.Ticks = {}
        AddPixelBorder(bar)
        independentResourceBar = bar
    end

    local bar = independentResourceBar
    
    -- Update bar properties using helper function
    local width = CalculateBarWidth(settings, viewer)
    width = PixelPerfect(width)
    local height = PixelPerfect(settings.height or CONSTANTS.SIZES.DEFAULT_RESOURCE_HEIGHT)
    bar:SetSize(width, height)
    
    -- Update texture - use LSM if available, otherwise default
    local texture = settings.texture or CONSTANTS.TEXTURES.DEFAULT_STATUSBAR
    if settings.textureName and LSM then
        texture = LSM:Fetch("statusbar", settings.textureName) or texture
    end
    bar:SetStatusBarTexture(texture)
    
    if bar.Text then
        local fontSize = settings.fontSize or CONSTANTS.SIZES.DEFAULT_FONT_SIZE
        bar.Text:SetFont(CONSTANTS.FONTS.DEFAULT, fontSize, "OUTLINE")
    end

    -- Position relative to viewer
    bar:ClearAllPoints()
    local offsetX = settings.offsetX or 0
    local offsetY = settings.offsetY or 20
    bar:SetPoint("TOP", viewer, "TOP", PixelPerfect(offsetX), PixelPerfect(offsetY))

    -- Update colors and power logic
    local class, classFile = GetCachedPlayerClass()
    local powerType = GetRelevantPowerType()

    -- Coloring
    if settings.classColor then
        local classColor = RAID_CLASS_COLORS[classFile]
        if classColor then
            bar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 1)
        end
    elseif settings.powerColor then
        local powerColor = GetPowerBarColor(UnitPowerType("player"))
        if powerColor then
            bar:SetStatusBarColor(powerColor.r, powerColor.g, powerColor.b, 1)
        end
    else
        local c = settings.customColor or { r = 0, g = 0.6, b = 1 }
        bar:SetStatusBarColor(c.r, c.g, c.b, 1)
    end

    -- Handle ticks and power display logic (simplified version)
    -- Hide ticks if not applicable
    if class ~= "EVOKER" and class ~= "MAGE" and class ~= "PALADIN" then
        for _, tick in ipairs(bar.Ticks) do tick:Hide() end
    end

    -- Resource value calculation
    local current, max
    if powerType == "MAELSTROM_WEAPON_BUFF" then
        local aura = GetAuraDataBySpellID("player", 344179)
        current = aura and aura.applications or 0
        max = 10
    elseif powerType == "ICICLE_BUFF" then
        local aura = GetAuraDataBySpellID("player", 205473)
        current = aura and aura.applications or 0
        max = 5
    elseif powerType == Enum.PowerType.Essence then
        current = essenceData.current + (essenceData.partial or 0)
        max = essenceData.max
    elseif type(powerType) == "number" then
        current = UnitPower("player", powerType)
        max = UnitPowerMax("player", powerType)
    else
        current = 0
        max = 0
    end

    -- Bar fill
    if max > 0 then
        bar:SetMinMaxValues(0, max)
        bar:SetValue(current)
        if bar.Text then
            if powerType == Enum.PowerType.Mana then
                bar.Text:SetText(math.floor((current / max) * 100) .. "%")
            else
                bar.Text:SetText(math.floor(current))
            end
        end
    end

    -- Combat visibility handled by UpdateCombatVisibility() in config.lua
    -- Make this bar accessible globally for config.lua
    CooldownManagerResourceBars["Independent"] = bar
    
    -- Independent secondary resource bar (class specific)
    -- Create secondary resource bar if it doesn't exist
    if not independentSecondaryResourceBar then
        local sbar = CreateFrame("Frame", "CooldownManagerIndependentSecondaryResourceBar", UIParent)
        sbar.Background = sbar:CreateTexture(nil, "BACKGROUND")
        sbar.Background:SetAllPoints()
        sbar.Background:SetColorTexture(unpack(CONSTANTS.COLORS.BACKGROUND))
        sbar:SetFrameLevel(bar:GetFrameLevel() + 1)
        AddPixelBorder(sbar)
        independentSecondaryResourceBar = sbar
    end
    
    local sbar = independentSecondaryResourceBar
    sbar:Hide() -- Hide by default, show only for applicable classes

    -- Position secondary bar above main bar
    sbar:ClearAllPoints()
    sbar:SetPoint("BOTTOM", bar, "TOP", 0, PixelPerfect(3))
    sbar:SetWidth(bar:GetWidth())
    sbar:SetHeight(math.max(bar:GetHeight() - 2, 8))

    -- Class-specific secondary resource logic
    if class == "DEATHKNIGHT" then
        sbar:Show()
        local totalRunes = 6
        local runeWidth = PixelPerfect((sbar:GetWidth() - (totalRunes - 1)) / totalRunes)
        UpdateDeathKnightRunes(sbar, totalRunes, runeWidth, texture)
        
    elseif class == "ROGUE" or (class == "DRUID" and GetSpecialization() == 2) then
        sbar:Show()
        local maxCP = UnitPowerMax("player", Enum.PowerType.ComboPoints) or 5
        local currentCP = UnitPower("player", Enum.PowerType.ComboPoints) or 0
        local pointWidth = PixelPerfect((sbar:GetWidth() - (maxCP - 1)) / maxCP)
        UpdateComboPointsOrChi(sbar, maxCP, currentCP, pointWidth, texture, 
                              CONSTANTS.COLORS.COMBO_POINTS, {0.3, 0.3, 0.3})
        
    elseif class == "MONK" and GetSpecialization() == 3 then
        sbar:Show()
        local maxChi = UnitPowerMax("player", Enum.PowerType.Chi) or 5
        local currentChi = UnitPower("player", Enum.PowerType.Chi) or 0
        local pointWidth = PixelPerfect((sbar:GetWidth() - (maxChi - 1)) / maxChi)
        UpdateComboPointsOrChi(sbar, maxChi, currentChi, pointWidth, texture, 
                              CONSTANTS.COLORS.CHI, {0.2, 0.4, 0.2})
    end

    -- Make secondary bar accessible globally
    CooldownManagerResourceBars["IndependentSecondary"] = sbar
end

-- Initialize events after login
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "CooldownManager" then
        if CooldownManager and CooldownManager.CastBars and CooldownManager.CastBars.InitializeEvents then
            C_Timer.After(1, CooldownManager.CastBars.InitializeEvents)
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

local function UpdateSecondaryBar(viewer)
    if not viewer then return end
    local name = viewer:GetName()
    local bar = secondaryResourceBars[name]
    if not bar or not bar:IsShown() then return end

    local _, class = UnitClass("player")
    local specID = GetSpecializationInfo(GetSpecialization() or 0)

    -- Rune Bar (Death Knight)
    if class == "DEATHKNIGHT" and bar.Runes then
        local runeStates = {}
        for runeID = 1, 6 do
            local start, duration, ready = GetRuneCooldown(runeID)
            table.insert(runeStates, {
                runeID = runeID,
                ready = ready,
                start = start or 0,
                duration = duration or 0,
            })
        end

        table.sort(runeStates, function(a, b)
            if a.ready ~= b.ready then
                return a.ready
            else
                return a.start < b.start
            end
        end)

        local color = { r = 0.7, g = 0.7, b = 0.7 } -- default gray
        if specID == 250 then color = { r = 0.8, g = 0.1, b = 0.1 }
        elseif specID == 251 then color = { r = 0.2, g = 0.6, b = 1.0 }
        elseif specID == 252 then color = { r = 0.1, g = 0.8, b = 0.1 } end

        for i = 1, 6 do
            local rune = bar.Runes[i]
            local state = runeStates[i]
            if rune and state then
                if state.ready then
                    rune:SetValue(1)
                    rune:SetStatusBarColor(color.r, color.g, color.b, 1)
                elseif state.start > 0 and state.duration > 0 then
                    local elapsed = GetTime() - state.start
                    rune:SetValue(math.min(elapsed / state.duration, 1))
                    rune:SetStatusBarColor(color.r * 0.4, color.g * 0.4, color.b * 0.4, 1)
                else
                    rune:SetValue(1)
                    rune:SetStatusBarColor(color.r, color.g, color.b, 1)
                end
            end
        end

    -- Combo Points (Rogue / Feral)
    elseif class == "ROGUE" or (class == "DRUID" and specID == 2) then
        if bar.Points then
            local maxCP = UnitPowerMax("player", Enum.PowerType.ComboPoints) or 5
            local currentCP = UnitPower("player", Enum.PowerType.ComboPoints) or 0

            for i = 1, maxCP do
                local point = bar.Points[i]
                if point then
                    if i <= currentCP then
                        point:SetValue(1)
                        point:SetStatusBarColor(1, 0.85, 0.1, 1)
                    else
                        point:SetValue(0)
                        point:SetStatusBarColor(0.3, 0.3, 0.3, 1)
                    end
                end
            end

            for i = maxCP + 1, #bar.Points do
                if bar.Points[i] then bar.Points[i]:Hide() end
            end
        end

    -- Chi (Monk - Windwalker)
    elseif class == "MONK" and specID == 269 then
        if bar.Points then
            local maxChi = UnitPowerMax("player", Enum.PowerType.Chi) or 5
            local currentChi = UnitPower("player", Enum.PowerType.Chi) or 0

            for i = 1, maxChi do
                local point = bar.Points[i]
                if point then
                    if i <= currentChi then
                        point:SetValue(1)
                        point:SetStatusBarColor(0.4, 1, 0.6, 1) -- greenish
                    else
                        point:SetValue(0)
                        point:SetStatusBarColor(0.2, 0.4, 0.2, 1)
                    end
                end
            end

            for i = maxChi + 1, #bar.Points do
                if bar.Points[i] then bar.Points[i]:Hide() end
            end
        end
    end
end


local function UpdateAllResourceBars()
    -- Throttle resource bar updates to prevent excessive calls
    if ThrottleEvent("resourceBarUpdate", 0.016) then -- ~60 FPS max
        return
    end
    
    UpdateEssenceTracking()

    -- Update independent resource bar
    UpdateIndependentResourceBar()
    
    -- Update independent cast bar
    if CooldownManager and CooldownManager.CastBars and CooldownManager.CastBars.UpdateIndependentCastBar then
        CooldownManager.CastBars.UpdateIndependentCastBar()
    end

    for _, viewerName in ipairs(viewers) do
        local viewer = _G[viewerName]
        if viewer then
            UpdateResourceBar(viewer)
        end
    end

    for name, bar in pairs(resourceBars) do
        if bar and bar:IsShown() then
            local powerType = GetRelevantPowerType()
            local current, max

            if powerType == "MAELSTROM_WEAPON_BUFF" then
                local aura = GetAuraDataBySpellID("player", 344179)
                current = aura and aura.applications or 0
                max = 10

            elseif powerType == "ICICLE_BUFF" then
                local aura = GetAuraDataBySpellID("player", 205473)
                current = aura and aura.applications or 0
                max = 5
            

            elseif powerType == Enum.PowerType.Essence then
                current = essenceData.current + (essenceData.partial or 0)
                max = essenceData.max
            else
                current = UnitPower("player", powerType)
                max = UnitPowerMax("player", powerType)
            end

            if max and max > 0 then
                bar:SetMinMaxValues(0, max)
                bar:SetValue(current)

                if bar.Text then
                    if powerType == Enum.PowerType.Mana then
                        local percent = math.floor((current / max) * 100)
                        bar.Text:SetText(percent .. "%")
                    else
                        bar.Text:SetText(math.floor(current))
                    end
                end
            end

            -- Holy Power Segment Ticks (Paladin - Retribution)
            local _, class = UnitClass("player")
            local specID = GetSpecializationInfo(GetSpecialization() or 0)
            if class == "PALADIN" and specID == 3 then
                for _, tick in ipairs(bar.Ticks or {}) do tick:Hide() end
                local maxHP = UnitPowerMax("player", Enum.PowerType.HolyPower) or 5
                for i = 1, maxHP - 1 do
                    local tick = bar.Ticks[i] or bar:CreateTexture(nil, "OVERLAY")
                    tick:SetColorTexture(0, 0, 0, 1)
                    tick:SetWidth(PixelPerfect(1))
                    tick:SetHeight(PixelPerfect(bar:GetHeight()))
                    tick:ClearAllPoints()
                    tick:SetPoint("LEFT", bar, "LEFT", PixelPerfect((i / maxHP) * bar:GetWidth()), 0)
                    tick:Show()
                    bar.Ticks[i] = tick
                end
            end
        end

        -- Rune Bar Update
        local runeBar = secondaryResourceBars[name]
        if runeBar and runeBar:IsShown() and runeBar.Runes then
            local runeStates = {}
            for runeID = 1, 6 do
                local start, duration, ready = GetRuneCooldown(runeID)
                table.insert(runeStates, {
                    runeID = runeID,
                    ready = ready,
                    start = start or 0,
                    duration = duration or 0,
                })
            end

            table.sort(runeStates, function(a, b)
                if a.ready ~= b.ready then
                    return a.ready
                else
                    return a.start < b.start
                end
            end)

            local specID = GetSpecializationInfo(GetSpecialization())
            local color
            if specID == 250 then -- Blood
                color = { r = 0.8, g = 0.1, b = 0.1 }
            elseif specID == 251 then -- Frost
                color = { r = 0.2, g = 0.6, b = 1.0 }
            elseif specID == 252 then -- Unholy
                color = { r = 0.1, g = 0.8, b = 0.1 }
            else
                color = { r = 0.7, g = 0.7, b = 0.7 }
            end

            for i = 1, 6 do
                local rune = runeBar.Runes[i]
                local state = runeStates[i]
                if rune and state then
                    if state.ready then
                        rune:SetValue(1)
                        rune:SetStatusBarColor(color.r, color.g, color.b, 1)
                    elseif state.start > 0 and state.duration > 0 then
                        local elapsed = GetTime() - state.start
                        rune:SetValue(math.min(elapsed / state.duration, 1))
                        rune:SetStatusBarColor(color.r * 0.4, color.g * 0.4, color.b * 0.4, 1)
                    else
                        rune:SetValue(1)
                        rune:SetStatusBarColor(color.r, color.g, color.b, 1)
                    end
                end
            end
        end

        -- Combo Point Update
        local cpBar = secondaryResourceBars[name]
        if cpBar and cpBar:IsShown() and cpBar.Points then
            local _, class = UnitClass("player")
            if class == "ROGUE" or (class == "DRUID" and GetSpecialization() == 2) then
                local maxCP = UnitPowerMax("player", Enum.PowerType.ComboPoints) or 5
                local currentCP = UnitPower("player", Enum.PowerType.ComboPoints) or 0

                for i = 1, maxCP do
                    local point = cpBar.Points[i]
                    if point then
                        if i <= currentCP then
                            point:SetValue(1)
                            point:SetStatusBarColor(1, 0.85, 0.1, 1)
                        else
                            point:SetValue(0)
                            point:SetStatusBarColor(0.3, 0.3, 0.3, 1)
                        end
                    end
                end

                for i = maxCP + 1, #cpBar.Points do
                    if cpBar.Points[i] then cpBar.Points[i]:Hide() end
                end
            end
        end
    end
    
    -- Update combat visibility for all bars after they're created/updated
    if UpdateCombatVisibility then
        UpdateCombatVisibility()
    end
end

local TRINKET_SLOTS = {13, 14}

local trinketUsabilityCache = {}

local function CreateTrinketIcon(viewer, slotID)
    local icon = CreateFrame("Button", nil, viewer)
    icon:SetSize(58, 58)
    icon.layoutIndex = slotID + 900000
    icon._trinketSlot = slotID

    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints()
    icon.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.Cooldown:SetAllPoints()
    icon.Cooldown:SetSwipeTexture("Interface\\Cooldown\\ping4")
    icon.Cooldown:SetDrawEdge(false)

    icon.Update = function()
        local itemID = GetInventoryItemID("player", slotID)
        local texture = GetInventoryItemTexture("player", slotID) or 134400
        local start, duration, enable = GetInventoryItemCooldown("player", slotID)
        local isUsable = itemID and IsUsableItem(itemID)

        icon.Icon:SetTexture(texture)

        if not itemID then
            icon:Hide()
            return
        end

        -- Cache usable state to avoid flickering
        if isUsable then
            trinketUsabilityCache[slotID] = GetTime()
        end

        local recentUsable = trinketUsabilityCache[slotID] and (GetTime() - trinketUsabilityCache[slotID] < 1.5)

        if (isUsable or recentUsable or (duration > 1 and enable == 1)) then
            icon:Show()
            icon:SetAlpha(1)

            if duration > 1 and start > 0 and enable == 1 then
                icon.Cooldown:SetCooldown(start, duration)
                icon.Icon:SetDesaturated(true)
            else
                icon.Cooldown:Clear()
                icon.Icon:SetDesaturated(false)
            end
        else
            icon.Cooldown:Clear()
            icon:Hide()
        end
    end

    return icon
end


local lastCustomUpdate = 0
local UPDATE_INTERVAL = 0.1

function UpdateAllCustomIcons()
    local now = GetTime()
    if now - lastCustomUpdate < UPDATE_INTERVAL then return end
    lastCustomUpdate = now

    for _, viewerName in ipairs(viewers) do
        local viewer = _G[viewerName]
        if viewer then
            for _, icon in ipairs({ viewer:GetChildren() }) do
                if icon and icon:IsShown() and icon.Update then
                    icon:Update()
                end
            end
            if viewer._customIcons then
                for _, icon in pairs(viewer._customIcons) do
                    if icon and icon:IsShown() and icon.Update then
                        icon:Update()
                    end
                end
            end
        end
    end
end


local function HookBuffViewerLayout()
    local viewer = _G["BuffIconCooldownViewer"]
    if not viewer then return end

    hooksecurefunc(viewer, "MarkDirty", function()
        if not viewer._layoutPending then
            viewer._layoutPending = true
            C_Timer.After(0.01, function()
                viewer._layoutPending = false
                LayoutCooldownIcons(viewer)
            end)
        end
    end)


    if not viewer._throttleUpdater then
        viewer._throttleUpdater = true
        local throttle = 0
        viewer:SetScript("OnUpdate", function(self, elapsed)
            if not self:IsVisible() or InEditMode() then return end
            throttle = throttle + elapsed
            if throttle > 0.1 then
                throttle = 0
                LayoutCooldownIcons(self)
            end
        end)
    end
end


local CLASS_SPELL_CACHE = {}

function IsSpellUsableByPlayerClass(spellID)
    if CLASS_SPELL_CACHE[spellID] ~= nil then
        return CLASS_SPELL_CACHE[spellID]
    end

    local name = C_Spell.GetSpellInfo(spellID)
    if not name then return false end

    for tabIndex = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local _, _, offset, numSpells = C_SpellBook.GetSpellBookSkillLineInfo(tabIndex)
        if offset and numSpells then
            for spellIndex = 1, numSpells do
                local sID = select(2, GetSpellBookItemInfo(offset + spellIndex, BOOKTYPE_SPELL))
                if sID == spellID then
                    CLASS_SPELL_CACHE[spellID] = true
                    return true
                end
            end
        end
    end

    CLASS_SPELL_CACHE[spellID] = false
    return false
end

local function tIndexOf(t, val)
    for i, v in ipairs(t) do
        if v == val then return i end
    end
    return nil
end

local function UpdateBuffIconVisibility()
    local viewer = _G["BuffIconCooldownViewer"]
    if not viewer then return end

    local changed = false
    local icons = {}

    -- Collect icons
    for _, icon in ipairs({ viewer:GetChildren() }) do
        if icon and icon._spellID then
            table.insert(icons, icon)
        end
    end
    if viewer._customIcons then
        for _, icon in pairs(viewer._customIcons) do
            if icon and icon._spellID then
                table.insert(icons, icon)
            end
        end
    end

    -- Process each icon
    for _, icon in ipairs(icons) do
        local spellID = icon._spellID
        local aura = GetAuraDataBySpellID("player", spellID) or GetAuraDataBySpellID("target", spellID)
        local shouldShow = aura ~= nil

        icon._auraUnit = aura and aura.unit or nil

        -- Show/hide logic
        if shouldShow then
            if not icon:IsShown() then
                icon:Show()
                changed = true
            end
        else
            if icon:IsShown() then
                icon:Hide()
                changed = true
            end
        end

        -- Update visuals
        if icon.Update then
            icon:Update()
        end
    end

    -- Trigger layout if changes occurred
    if changed then
        C_Timer.After(0.01, function()
            LayoutCooldownIcons(viewer)
        end)
    end
end






-- Viewer logic
local function GetViewerSetting(viewer, key, default)
    CooldownManagerDBHandler.profile.viewers = CooldownManagerDBHandler.profile.viewers or {}
    CooldownManagerDBHandler.profile.viewers[viewer] = CooldownManagerDBHandler.profile.viewers[viewer] or {}
    return CooldownManagerDBHandler.profile.viewers[viewer][key] or default
end

local function CreateCustomIcon(viewer, spellID)
    local viewerName = viewer:GetName()
    local icon = CreateFrame("Button", nil, viewer)
    icon:SetSize(PixelPerfect(58), PixelPerfect(58))

    icon.layoutIndex = spellID

    -- Icon
    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints()
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    icon.Icon:SetTexture((spellInfo and spellInfo.iconID) or 134400)
    icon.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Cooldown Frame
    icon.Cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.Cooldown:SetAllPoints()
    icon.Cooldown:SetSwipeTexture("Interface\\Cooldown\\ping4")
    icon.Cooldown:SetDrawEdge(false)
    icon.Cooldown:SetUseCircularEdge(false)

    local cooldownFontSize = GetViewerSetting(viewerName, "cooldownFontSize", 18)
    local regions = { icon.Cooldown:GetRegions() }
    for _, region in ipairs(regions) do
        if region:IsObjectType("FontString") then
            region:ClearAllPoints()
            region:SetPoint("CENTER", icon, "CENTER", PixelPerfect(0), PixelPerfect(0))

            region:SetFont("Interface\\AddOns\\CooldownManager\\Fonts\\FRIZQT__.TTF", cooldownFontSize, "OUTLINE")
            region:SetJustifyH("CENTER")
            region:SetJustifyV("MIDDLE")
            region:SetDrawLayer("OVERLAY", 7)
            icon._cooldownText = region
            break
        end
    end

    -- Overlay for text
    icon.OverlayFrame = CreateFrame("Frame", nil, icon)
    icon.OverlayFrame:SetAllPoints()
    icon.OverlayFrame:SetFrameStrata(icon:GetFrameStrata())
    icon.OverlayFrame:SetFrameLevel(icon:GetFrameLevel() + 10)

    icon._customCountText = icon.OverlayFrame:CreateFontString(nil, "OVERLAY")
    icon._customCountText:SetDrawLayer("OVERLAY", 7)
    icon._customCountText:SetTextColor(1, 1, 1, 1)
    icon._customCountText:SetJustifyH("RIGHT")
    icon._customCountText:SetJustifyV("BOTTOM")

    local fontSize = GetViewerSetting(viewerName, "chargeFontSize", 18)
    local offsetX = GetViewerSetting(viewerName, "chargeTextOffsetX", -4)
    local offsetY = GetViewerSetting(viewerName, "chargeTextOffsetY", 4)
    icon._customCountText:SetFont("Interface\\AddOns\\CooldownManager\\Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    icon._customCountText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", offsetX, offsetY)

    icon.Update = function()
        local viewerName = viewer:GetName()

        if viewerName == "BuffIconCooldownViewer" then
            local aura = GetAuraDataBySpellID("player", spellID) or GetAuraDataBySpellID("target", spellID)
        
            if aura then
                local start = aura.expirationTime - aura.duration
                local duration = aura.duration
        
                -- Ensure it uses a filling swipe like Blizzard
                if icon.Cooldown then
                    icon.Cooldown:SetReverse(true)
                    icon.Cooldown:SetCooldown(start, duration)
                end
        
                icon._cooldownStart = start
                icon._cooldownDuration = duration
        
                if aura.applications and aura.applications > 0 then
                    icon._customCountText:SetText(aura.applications)
                    icon._customCountText:Show()
                else
                    icon._customCountText:SetText("")
                    icon._customCountText:Hide()
                end
        
                icon.Icon:SetDesaturated(false)
            else
                if icon.Cooldown then
                    icon.Cooldown:Clear()
                end
                icon._cooldownStart = nil
                icon._cooldownDuration = nil
                icon._customCountText:SetText("")
                icon._customCountText:Hide()
                icon.Icon:SetDesaturated(true)
            end
        
        
        else
            local chargeInfo = C_Spell.GetSpellCharges(spellID)
            local startInfo = C_Spell.GetSpellCooldown(spellID)

            local currentCharges = chargeInfo and chargeInfo.currentCharges or 0
            local maxCharges = chargeInfo and chargeInfo.maxCharges or 0
            local chargeStart = chargeInfo and chargeInfo.chargeStart or 0
            local chargeDuration = chargeInfo and chargeInfo.chargeDuration or 0
            local start = startInfo and startInfo.startTime or 0
            local duration = startInfo and startInfo.duration or 0

            icon.cooldownChargesCount = currentCharges
            icon.cooldownChargeMaxDisplay = maxCharges

            if maxCharges > 0 then
                if currentCharges == 0 and start > 0 and duration > 1 then
                    icon.Cooldown:SetCooldown(start, duration)
                    icon.Icon:SetDesaturated(true)
                elseif currentCharges < maxCharges and chargeStart > 0 and chargeDuration > 1 then
                    icon.Cooldown:SetCooldown(chargeStart, chargeDuration)
                    icon.Icon:SetDesaturated(false)
                else
                    icon.Cooldown:Clear()
                    icon.Icon:SetDesaturated(false)
                end
            else
                if start > 0 and duration > 1 then
                    icon.Cooldown:SetCooldown(start, duration)
                    icon.Icon:SetDesaturated(true)
                else
                    icon.Cooldown:Clear()
                    icon.Icon:SetDesaturated(false)
                end
            end

            if icon.cooldownChargesCount > 0 and icon.cooldownChargeMaxDisplay > 0 then
                icon._customCountText:SetText(icon.cooldownChargesCount)
                icon._customCountText:Show()
            else
                icon._customCountText:SetText("")
                icon._customCountText:Hide()
            end

            if C_Spell.IsSpellInRange(spellID, "target") == false then
                icon.Icon:SetVertexColor(0.55, 0.1, 0.1)
            else
                icon.Icon:SetVertexColor(1, 1, 1)
            end
        end

        if IsSpellOverlayed(spellID) then
            ActionButton_ShowOverlayGlow(icon)
        else
            ActionButton_HideOverlayGlow(icon)
        end
    end

    return icon
end


local function AdjustIconVisualPadding(viewer)
    local padding = 5
    local icons = { viewer:GetChildren() }

    for _, icon in ipairs(icons) do
        if icon and icon.Icon then
            icon.Icon:ClearAllPoints()
            icon.Icon:SetPoint("TOPLEFT", icon, "TOPLEFT", PixelPerfect(padding), PixelPerfect(-padding))
            icon.Icon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", PixelPerfect(-padding), PixelPerfect(padding))
        end
    end
    if viewer.editModeManagerAnchor then
        viewer:ClearAllPoints()
        viewer:SetPoint("TOPLEFT", viewer.editModeManagerAnchor, "TOPLEFT", PixelPerfect(0), PixelPerfect(0))

    end
    
end

function LayoutCooldownIcons(viewer)
    local name = viewer:GetName()
    local db = CooldownManagerDBHandler.profile.viewers[name] or {}
    local settings = db

    local spacing = (settings.iconSpacing or -4) - 3
    local size = settings.iconSize or 58
    local columns = math.max(1, math.floor((settings.iconColumns or 14) + 0.1))
    local hiddenSpells = (db.hiddenCooldowns and db.hiddenCooldowns[name]) or {}

    local specID = GetSpecializationInfo(GetSpecialization())
    local customSpells = {}
    if db.customSpells and db.customSpells[specID] then
        for id in pairs(db.customSpells[specID]) do
            customSpells[id] = true
        end
    end

    local spellPriority = {}
    if db.spellPriorityBySpec and db.spellPriorityBySpec[specID] then
        -- Filter out hidden spells
        for _, id in ipairs(db.spellPriorityBySpec[specID]) do
            if not hiddenSpells[id] then
                table.insert(spellPriority, id)
            end
        end
    end
    
    -- Clean up spellPriority to remove any hidden spells
local cleanedPriority = {}
for _, spellID in ipairs(spellPriority) do
    if not hiddenSpells[spellID] then
        table.insert(cleanedPriority, spellID)
    end
end
spellPriority = cleanedPriority
db.spellPriority = cleanedPriority -- Save cleaned list back

    local padding = 5
    local borderSize = settings.borderSize or 1
    local cooldownFontSize = settings.cooldownFontSize or 18
    local chargeFontSize = settings.chargeFontSize or 18
    local offsetX = settings.chargeTextOffsetX or -4
    local offsetY = settings.chargeTextOffsetY or 4

    local allIcons = { viewer:GetChildren() }
    local icons = {}
    viewer._customIcons = viewer._customIcons or {}

    for _, icon in ipairs(allIcons) do
        if icon and icon.Icon then
            local cooldownID, spellID

            local cooldownID, spellID

            -- Try to fetch cooldownID first (Blizzard icons or custom)
            if icon.GetCooldownID then
                cooldownID = icon:GetCooldownID()
            end
            
            -- Try to get spellID from BuffViewer-specific field first
            if name == "BuffIconCooldownViewer" then
                spellID = icon.auraSpellID or (cooldownID and (C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID) or {}).spellID)
            else
                if cooldownID then
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
                    spellID = info and info.spellID
                end
            end
            

            if icon.layoutIndex then
                icon.layoutIndex = cooldownID or spellID or math.random(100000, 999999)
            end

            if spellID then
                icon._spellID = spellID
            
                if hiddenSpells[spellID] then
                    icon:Hide()
                else
                    -- For BuffIconCooldownViewer, only show if there's an active aura
                    if name == "BuffIconCooldownViewer" then
                        local aura = GetAuraDataBySpellID("player", spellID) or GetAuraDataBySpellID("target", spellID)
                        if aura then
                            icon:Show()
                        else
                            icon:Hide()
                        end
                    else
                        icon:Show()
                    end
                end
            
                if icon:IsShown() then
                    table.insert(icons, icon)
                end
            
                if CooldownManagerDBHandler.profile.useAuraForCooldown == false and name ~= "BuffIconCooldownViewer" then
                    icon.auraSpellID = nil
                    icon.auraInstanceID = nil
                    icon.GetAuraData = function() return nil end
                    icon.GetAuraInfo = function() return nil end
                end

                -- Strip Blizzard's proc glow
                local regions = { icon:GetRegions() }
                for _, region in ipairs(regions) do
                    if region:IsObjectType("Texture") and region.GetAtlas then
                        if region:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
                            region:SetTexture("")
                            region:Hide()
                            region.Show = function() end
                        end
                    end
                end
            else
                icon:Hide()
                icon:SetParent(nil)
            end
        end
    end

    for spellID, frame in pairs(viewer._customIcons) do
        if frame and not customSpells[spellID] then
            frame:Hide()
            frame:SetParent(nil)
            viewer._customIcons[spellID] = nil
        end
    end

    for spellID in pairs(customSpells) do
        local show = name == "BuffIconCooldownViewer" or IsPlayerSpell(spellID)
        if show then
            local icon = viewer._customIcons[spellID]
            if not icon then
                icon = CreateCustomIcon(viewer, spellID)
                icon._spellID = spellID
                viewer._customIcons[spellID] = icon
            end
            icon:SetParent(viewer)

            if name == "BuffIconCooldownViewer" then
                local aura = GetAuraDataBySpellID("player", spellID) or GetAuraDataBySpellID("target", spellID)
                icon:SetShown(aura ~= nil)
            else
                icon:Show()
            end
            

            if icon:IsShown() then
                table.insert(icons, icon)
            end
            
        end
    end

    if db.showTrinkets then
        local TRINKET_SLOTS = {13, 14}
        for _, slotID in ipairs(TRINKET_SLOTS) do
            local itemID = GetInventoryItemID("player", slotID)
    
            if itemID then
                local key = "trinket" .. slotID
                local icon = viewer._customIcons[key]
                if not icon then
                    icon = CreateTrinketIcon(viewer, slotID)
                    icon.layoutIndex = 1000000 + slotID
                    icon._isCustom = true
                    viewer._customIcons[key] = icon
                end
                icon:SetParent(viewer)
                icon:Update() -- important
                if icon:IsShown() then
                    table.insert(icons, icon)
                end
            else
                local key = "trinket" .. slotID
                local icon = viewer._customIcons[key]
                if icon then
                    icon:Hide()
                    icon:SetParent(nil)
                    viewer._customIcons[key] = nil
                end
            end
        end
    end
    

    table.sort(icons, function(a, b)
        return (tIndexOf(spellPriority, a._spellID) or 9999) < (tIndexOf(spellPriority, b._spellID) or 9999)
    end)

    local total = #icons
    local rows = math.ceil(total / columns)
    local rowIcons = {}
    for i = 1, rows do rowIcons[i] = {} end
    for i, icon in ipairs(icons) do
        table.insert(rowIcons[math.floor((i - 1) / columns) + 1], icon)
    end

    for rowIndex, row in ipairs(rowIcons) do
        local rowWidth = #row * size + (#row - 1) * spacing
        for colIndex, icon in ipairs(row) do
            icon:SetSize(PixelPerfect(size), PixelPerfect(size))

            local x = (colIndex - 1) * (size + spacing) - (rowWidth / 2) + (size / 2)
            local y = -((rowIndex - 1) * (size + spacing))

            icon:ClearAllPoints()
            icon:SetPoint("TOP", viewer, "TOP", PixelPerfect(x), PixelPerfect(y))

            if icon.Icon then
                icon.Icon:ClearAllPoints()
                icon.Icon:SetPoint("TOPLEFT", icon, "TOPLEFT", PixelPerfect(padding), PixelPerfect(-padding))
                icon.Icon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", PixelPerfect(-padding), PixelPerfect(padding))
            end

            if icon.Cooldown then
                icon.Cooldown:ClearAllPoints()
                icon.Cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", PixelPerfect(padding), PixelPerfect(-padding))
                icon.Cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", PixelPerfect(-padding), PixelPerfect(padding))
                icon.Cooldown:SetSwipeTexture("Interface\\Cooldown\\ping4")

                for _, region in ipairs({ icon.Cooldown:GetRegions() }) do
                    if region:IsObjectType("FontString") then
                        region:ClearAllPoints()
                        region:SetPoint("CENTER", icon, "CENTER", 0, 0)
                        region:SetFont("Interface\\AddOns\\CooldownManager\\Fonts\\FRIZQT__.TTF", cooldownFontSize, "OUTLINE")
                        region:SetJustifyH("CENTER")
                        region:SetJustifyV("MIDDLE")
                    end
                end
            end

            if icon.OutOfRange then
                icon.OutOfRange:ClearAllPoints()
                icon.OutOfRange:SetPoint("TOPLEFT", icon, "TOPLEFT", PixelPerfect(padding), PixelPerfect(-padding))
                icon.OutOfRange:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", PixelPerfect(-padding), PixelPerfect(padding))
            end

            if icon.overlay then
                icon.overlay:Hide()
                icon.overlay.Show = function() end
            end

            -- Count text logic
            local chargeText = (icon.GetApplicationsFontString and icon:GetApplicationsFontString()) 
            or (icon.ChargeCount and icon.ChargeCount.Current)

            if chargeText then
                chargeText:ClearAllPoints()
                chargeText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", offsetX, offsetY)
                chargeText:SetFont("Interface\\AddOns\\CooldownManager\\Fonts\\FRIZQT__.TTF", chargeFontSize, "OUTLINE")
                chargeText:SetJustifyH("RIGHT")
                chargeText:SetJustifyV("BOTTOM")
                chargeText:SetAlpha(1)
            
                if name == "BuffIconCooldownViewer" and icon._spellID then
                    local aura = GetAuraDataBySpellID("player", icon._spellID)
                    local count = aura and aura.applications or 0
                    chargeText:SetText(count > 1 and tostring(count) or "")
                    chargeText:SetShown(count > 1) -- or just Show() if always visible
                end
            end

            if icon.Update then icon:Update() end

            if icon.GetBackdrop then
                local backdrop = icon:GetBackdrop()
                if backdrop and backdrop.edgeFile then
                    icon:SetBackdrop({
                        edgeFile = backdrop.edgeFile,
                        edgeSize = borderSize,
                        bgFile = backdrop.bgFile,
                        insets = backdrop.insets,
                    })
                end
            end
        end
    end

    local totalWidth = (size + spacing) * math.min(columns, total) - spacing
    local totalHeight = (size + spacing) * rows - spacing

    viewer:SetSize(totalWidth, totalHeight)


    if viewer.editModeManagerAnchor then
        viewer:ClearAllPoints()
        viewer:SetPoint("TOPLEFT", viewer.editModeManagerAnchor, "TOPLEFT", 0, 0)
    end

    if viewer.Selection then
        viewer.Selection:SetPoint("TOPLEFT", viewer, "TOPLEFT", 0, 0)
        viewer.Selection:SetPoint("BOTTOMRIGHT", viewer, "BOTTOMRIGHT", 0, 0)
    end

    -- Ensure bars exist but don't override combat visibility - just create them if needed
    local viewerName = viewer:GetName()
    if CooldownManagerDBHandler.profile.viewers[viewerName] then
        local settings = CooldownManagerDBHandler.profile.viewers[viewerName]
        
        -- Create resource bar if enabled but doesn't exist  
        if settings.showResourceBar and not CooldownManagerResourceBars[viewerName] then
            UpdateResourceBar(viewer)
        end
    end
end




function AddPixelBorder(frame)
    if not frame then return end

    local dbProfile = CooldownManagerDBHandler.profile or {}
    local thickness = dbProfile.borderSize or 1
    local color = dbProfile.borderColor or { r = 0, g = 0, b = 0 }

    frame.__borderParts = frame.__borderParts or {}

    local anchor = frame.Icon or frame -- 🛠 anchor to Icon if it exists, otherwise to frame itself
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





function ProtectViewer(viewer)
    if protectedViewers[viewer] then return end
    protectedViewers[viewer] = true

    hooksecurefunc(viewer, "SetSize", function(self, width, height)
        if not CooldownManagerDBHandler then return end

        local name = self:GetName()
        local config = CooldownManagerDBHandler.profile.viewers[name]
        if not config then return end

        local spacing = (config.iconSpacing or -4) - 2
        local size = config.iconSize or 58
        local columns = config.iconColumns or 14

        local icons = {}
        for _, child in ipairs({ self:GetChildren() }) do
            if child and child:IsShown() and child.Icon then
                table.insert(icons, child)
            end
        end

        local totalIcons = #icons
        local rows = math.ceil(totalIcons / columns)

        -- Calculate expected layout dimensions
        local expectedWidth = (size + spacing) * math.min(columns, totalIcons) - spacing
        local expectedHeight = (size + spacing) * rows - spacing

        -- Only override Blizzard if they try to forcibly resize incorrectly
        if math.abs(width - expectedWidth) > 1 or math.abs(height - expectedHeight) > 1 then
            self:SetSize(expectedWidth, expectedHeight)
        end
    end)
end




function SkinViewer(viewerName)
    local viewer = _G[viewerName]
    if not viewer then return end

    -- Disable Blizzard auto-layout behavior


    -- Override GetLayoutChildren to prevent phantom rows
    viewer.GetLayoutChildren = function()
        local icons = {}
    
        -- Only count icons we explicitly inserted into the layout
        local visibleIcons = viewer._visibleLayoutIcons or {}
    
        for _, icon in ipairs(visibleIcons) do
            if icon and icon:IsShown() and type(icon.layoutIndex) == "number" then
                table.insert(icons, icon)
            end
        end
    
        return icons
    end
    

    -- Optional: hook MarkDirty to reapply layout when Edit Mode tweaks the viewer
    hooksecurefunc(viewer, "MarkDirty", function()
        C_Timer.After(0, function()
            LayoutCooldownIcons(viewer)
        end)
    end)

    -- Layout and styling
    ProtectViewer(viewer)
    LayoutCooldownIcons(viewer)
    AdjustIconVisualPadding(viewer)

    -- Skin each icon
    local children = { viewer:GetChildren() }
    for _, child in ipairs(children) do
        if child and child.Icon then
            local z = CooldownManagerDBHandler.profile.iconZoom or 0.25
            child.Icon:SetTexCoord(z, 1 - z, z, 1 - z)
            AddPixelBorder(child)
        end
    end

    -- Ensure anchoring remains aligned to Edit Mode manager
    if viewer.editModeManagerAnchor then
        viewer:ClearAllPoints()
        viewer:SetPoint("TOPLEFT", viewer.editModeManagerAnchor, "TOPLEFT", 0, 0)
    end

    if viewer.Selection then
        local sel = viewer.Selection
    
        -- Make the label text smaller and dimmer
        if sel.Label then
            sel.Label:SetFont("Interface\\AddOns\\CooldownManager\\Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            sel.Label:SetTextColor(1, 1, 1, 0.5)
        end
    
        -- Reduce alpha on the whole thing
        sel:SetAlpha(0.5)

        -- Optionally hide textures
        for _, region in ipairs({ sel:GetRegions() }) do
            if region:IsObjectType("Texture") then
                region:SetAlpha(0.5)
            end
        end
    end
    
end



function TrySkin()
    -- Check if icon reskinning is enabled
    if not CooldownManagerDBHandler or not CooldownManagerDBHandler.profile then
        return
    end
    if CooldownManagerDBHandler.profile.enableIconReskinning == false then
        return
    end
    
    for _, name in ipairs(viewers) do
        SkinViewer(name)
    end
end

local wasVisible = true
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", function()
    local nowVisible = UIParent:IsVisible()
    if nowVisible and not wasVisible then
        C_Timer.After(0.1, TrySkin)
    end
    wasVisible = nowVisible
end)




local originalTrySkin = TrySkin
TrySkin = function(...)
    originalTrySkin(...)
end


-- Event registration
local eventFrame = CreateFrame("Frame")
for _, ev in pairs({
    "UNIT_AURA", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE",
    "PLAYER_ENTERING_WORLD", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
    "RUNE_POWER_UPDATE", "RUNE_TYPE_UPDATE",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED"
}) do
    eventFrame:RegisterEvent(ev)
end


eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        UpdateBuffIconVisibility()
        UpdateAllCustomIcons()
        C_Timer.After(1.5, TrySkin)
        return
    end

    if event == "UNIT_AURA" and (unit == "player" or unit == "target")

    or event == "PLAYER_ENTERING_WORLD"
    or event == "PLAYER_TALENT_UPDATE"
    or event == "PLAYER_SPECIALIZATION_CHANGED"
    or event == "PLAYER_REGEN_ENABLED"
    or event == "PLAYER_REGEN_DISABLED" then
        UpdateBuffIconVisibility()
        UpdateAllCustomIcons()
    end
    

    if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES"
        or event == "SPELL_ACTIVATION_OVERLAY_SHOW"
        or event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
        UpdateAllCustomIcons()
        C_Timer.After(0, UpdateAllCustomIcons)
        return
    end

    if event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE" then
        UpdateAllResourceBars()
        return
    end

    if unit == "player" then
        UpdateAllResourceBars()
        UpdateAllCustomIcons()
    end
    
end)


local secondaryThrottle = 0
watcher:SetScript("OnUpdate", function(self, delta)
    secondaryThrottle = secondaryThrottle + delta
    if secondaryThrottle >= 0.1 then
        secondaryThrottle = 0
        for _, viewerName in ipairs(viewers) do
            local viewer = _G[viewerName]
            if viewer then
                UpdateSecondaryBar(viewer)
            end
        end
    end
end)

local lastFullTickTime = 0
local estimatedRecharge = 4 -- fallback
local lastEssence = UnitPower("player", Enum.PowerType.Essence)

local essenceFrame = CreateFrame("Frame")
essenceFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")

-- Event: Essence changed
essenceFrame:SetScript("OnEvent", function(_, _, unit, powerType)
    if powerType == "ESSENCE" and unit == "player" then
        local now = GetTime()
        local current = UnitPower("player", Enum.PowerType.Essence)
        local max = UnitPowerMax("player", Enum.PowerType.Essence)

        if current > lastEssence then
            estimatedRecharge = now - lastFullTickTime
            lastFullTickTime = now
            essenceData.current = current
            essenceData.max = max
            essenceData.rechargeTime = estimatedRecharge
            essenceData.lastUpdate = now
            essenceData.partial = 0
            essenceData.active = (current < max)
            UpdateAllResourceBars()
        end

        lastEssence = current
    end
end)

-- Optimized Essence Recharge Partial Update
local throttle = 0
essenceFrame:SetScript("OnUpdate", function(self, elapsed)
    if not essenceData.active then return end

    throttle = throttle + elapsed
    if throttle < 0.05 then return end -- only run every ~20fps max
    throttle = 0

    local now = GetTime()
    local elapsedSinceLast = now - essenceData.lastUpdate
    essenceData.partial = math.min(elapsedSinceLast / essenceData.rechargeTime, 1)

    if (essenceData.current + essenceData.partial) >= essenceData.max then
        essenceData.active = false
        essenceData.partial = 0
    end

    -- Only update essence bar instead of all viewers
    for name, bar in pairs(resourceBars) do
        if bar and bar:IsShown() then
            local powerType = GetRelevantPowerType()
            if powerType == Enum.PowerType.Essence then
                local value = essenceData.current + (essenceData.partial or 0)
                bar:SetValue(value)
                if bar.Text then
                    bar.Text:SetText(math.floor(value))
                end
            end
        end
    end
end)



-- Edit Mode hooks
local function HookEditModeUpdates()
    if EditModeManagerFrame then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() C_Timer.After(0.1, TrySkin) end)
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            C_Timer.After(0.1, function()
                TrySkin()
                UpdateAllResourceBars()
                UpdateAllCustomIcons()
            end)
        end)
    end
end

local function HandleTrinketChange(slot)
    if slot == 13 or slot == 14 then
        -- Call TrySkin or whatever your full refresh function is
        C_Timer.After(1, TrySkin) -- slight delay ensures texture updates
    end
end

local trinketWatchFrame = CreateFrame("Frame")
trinketWatchFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
trinketWatchFrame:SetScript("OnEvent", function(_, _, slotID)
    HandleTrinketChange(slotID)
end)


--  Login & Profile Load Setup
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
loginFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
loginFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
loginFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        SetCVar("cooldownViewerEnabled", "1")
        CooldownManagerDBHandler = AceDB:New("CooldownManagerDB", {
            profile = {
                borderSize = 1,
                borderColor = { r = 0, g = 0, b = 0 },
                iconZoom = 0.08,
                viewers = {},
                defaultResourceBar = {
                    resourceBarHeight = 16,
                    resourceBarOffsetY = 14,
                    resourceBarTextureName = "Blizzard",
                    resourceBarTexture = "Interface\\TargetingFrame\\UI-StatusBar",
                    resourceBarFontSize = 20,
                },
            }
        }, true)

        HookBuffViewerLayout()

        -- Hook profile changes
        local function RefreshConfig()
            TrySkin()
            if SetupOptions then
                SetupOptions()
            end
            AceConfigRegistry:NotifyChange("CooldownBorders")
        end
        CooldownManagerDBHandler:RegisterCallback("OnProfileChanged", RefreshConfig)
        CooldownManagerDBHandler:RegisterCallback("OnProfileCopied", RefreshConfig)
        CooldownManagerDBHandler:RegisterCallback("OnProfileReset", RefreshConfig)

        -- GUI setup + hooks
        C_Timer.After(0, function()
            if SetupOptions then
                SetupOptions()
            end
            HookEditModeUpdates()
        end)

    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
        C_Timer.After(0, TrySkin)

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
        UpdateAllResourceBars()
        UpdateAllCustomIcons()
        TrySkin()
    end
end)

--[[
OPTIMIZATION SUMMARY:
1. Performance Cache: Cached frequently accessed values (player class, profile data)
2. Constants: Extracted hardcoded values to a centralized CONSTANTS table
3. Helper Functions: Created reusable functions for bar creation and width calculation
4. Event Throttling: Added throttling system to prevent excessive update calls
5. Code Deduplication: Reduced repeated code in resource bar creation
6. Performance Tracking: Optional debug system to monitor function execution times
7. Memory Optimization: Reduced redundant UnitClass() and database calls
8. Secondary Resource Optimization: Streamlined Death Knight rune, combo point, and chi handling
]]
