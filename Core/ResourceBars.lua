-- Resource Bar management for CooldownManager
local AceDB = LibStub("AceDB-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- Ensure CooldownManager namespace exists
CooldownManager = CooldownManager or {}
CooldownManager.ResourceBars = {}

-- Local references to global tables
local resourceBars = CooldownManagerResourceBars
local secondaryResourceBars = {}

-- Independent resource bar instances
local independentResourceBar = nil
local independentSecondaryResourceBar = nil

-- Secondary power types mapping
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

-- Essence tracking data
local essenceData = {
    current = 0,
    max = 0,
    lastUpdate = 0,
    partial = 0,
    active = false,
    rechargeTime = 5, -- default safe 5s fallback
}

-- Get relevant power type for current character
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

-- Get essence recharge time
local function GetEssenceRechargeTime()
    local regen = GetPowerRegenForPowerType(Enum.PowerType.Essence)
    if regen and regen > 0 then
        return 1 / regen
    end
    return 5 -- fallback 5 seconds
end

-- Check if resource bar should show based on combat settings
local function ShouldShowResourceBar(viewerName)
    if not CooldownManagerDBHandler.profile.viewers[viewerName] then return false end
    local settings = CooldownManagerDBHandler.profile.viewers[viewerName]
    
    -- First check if resource bar is enabled at all
    if not settings.showResourceBar then return false end
    
    -- Check combat visibility setting
    local hideResourceBarOutOfCombat = settings.hideResourceBarOutOfCombat
    if hideResourceBarOutOfCombat then
        -- Only show if in combat
        return InCombatLockdown()
    end
    
    -- Show if combat setting is disabled
    return true
end

-- Update essence tracking
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

-- Get essence recharge time
local function GetEssenceRechargeTime()
    local regen = GetPowerRegenForPowerType(Enum.PowerType.Essence)
    if regen and regen > 0 then
        return 1 / regen
    end
    return 5 -- fallback 5 seconds
end

-- Helper function for updating Death Knight runes
local function UpdateDeathKnightRunes(sbar, totalRunes, runeWidth, texture)
    sbar.Runes = sbar.Runes or {}
    local specID = GetSpecializationInfo(GetSpecialization() or 0)
    local color = CooldownManager.CONSTANTS.COLORS.RUNE_SPECS[specID] or {0.7, 0.7, 0.7}
    
    -- Gather rune states and sort by ready status
    local runeStates = {}
    for i = 1, totalRunes do
        local start, duration, ready = GetRuneCooldown(i)
        local value, statusColor
        
        if ready then
            value = 1
            statusColor = { color[1], color[2], color[3], 1 }
        elseif start and duration and duration > 0 then
            local elapsed = GetTime() - start
            value = math.min(elapsed / duration, 1)
            statusColor = { color[1] * 0.4, color[2] * 0.4, color[3] * 0.4, 1 }
        else
            value = 1
            statusColor = { color[1], color[2], color[3], 1 }
        end
        
        table.insert(runeStates, {
            ready = ready,
            value = value,
            color = statusColor
        })
    end
    
    -- Sort: ready runes first (left), then recharging (right)
    table.sort(runeStates, function(a, b)
        if a.ready ~= b.ready then
            return a.ready -- ready runes first
        end
        return false -- maintain relative order for same state
    end)
    
    -- Create and position runes with sorted states
    for i = 1, totalRunes do
        local rune = sbar.Runes[i]
        if not rune then
            rune = CooldownManager.CreateSecondaryResourceComponent(sbar, texture, runeWidth, sbar:GetHeight())
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
        
        -- Apply sorted state to visual rune
        local state = runeStates[i]
        rune:SetValue(state.value)
        rune:SetStatusBarColor(state.color[1], state.color[2], state.color[3], state.color[4])
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
            point = CooldownManager.CreateSecondaryResourceComponent(sbar, texture, pointWidth, sbar:GetHeight())
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

-- Update resource bar for a specific viewer
function CooldownManager.ResourceBars.UpdateResourceBar(viewer)
    if not viewer then return end

    local name = viewer:GetName()
    if not CooldownManagerDBHandler.profile.viewers[name] then return end

    local settings = CooldownManagerDBHandler.profile.viewers[name]
    local showResourceBar = settings.showResourceBar
    
    if not showResourceBar then
        if resourceBars[name] then resourceBars[name]:Hide() end
        if secondaryResourceBars[name] then secondaryResourceBars[name]:Hide() end
        return
    end

    if not resourceBars[name] then
        local bar = CreateFrame("StatusBar", nil, viewer)
        bar:SetStatusBarTexture(settings.resourceBarTexture or "Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetStatusBarColor(0, 0.6, 1, 1)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(100)
    
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
    
    -- Smart width calculation
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

    -- Resource value calculation
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

    -- Segment ticks for special power types
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

    -- Create secondary resource bars for specific classes
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
end

-- Update independent resource bar
function CooldownManager.ResourceBars.UpdateIndependentResourceBar()
    local profile = CooldownManager.GetCachedProfile()
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
        local bar = CooldownManager.CreateStandardBar("CooldownManagerIndependentResourceBar", "resource", settings)
        bar:SetStatusBarColor(0, 0.6, 1, 1)
        bar.Ticks = {}
        AddPixelBorder(bar)
        independentResourceBar = bar
    end

    local bar = independentResourceBar
    
    -- Update bar properties using helper function
    local width = CooldownManager.CalculateBarWidth(settings, viewer)
    width = PixelPerfect(width)
    local height = PixelPerfect(settings.height or CooldownManager.CONSTANTS.SIZES.DEFAULT_RESOURCE_HEIGHT)
    bar:SetSize(width, height)
    
    -- Update texture - use LSM if available, otherwise default
    local texture = settings.texture or CooldownManager.CONSTANTS.TEXTURES.DEFAULT_STATUSBAR
    if settings.textureName and LSM then
        texture = LSM:Fetch("statusbar", settings.textureName) or texture
    end
    bar:SetStatusBarTexture(texture)
    
    if bar.Text then
        local fontSize = settings.fontSize or CooldownManager.CONSTANTS.SIZES.DEFAULT_FONT_SIZE
        bar.Text:SetFont(CooldownManager.CONSTANTS.FONTS.DEFAULT, fontSize, "OUTLINE")
    end

    -- Position relative to viewer
    bar:ClearAllPoints()
    local offsetX = settings.offsetX or 0
    local offsetY = settings.offsetY or 20
    bar:SetPoint("TOP", viewer, "TOP", PixelPerfect(offsetX), PixelPerfect(offsetY))

    -- Update colors and power logic
    local class, classFile = CooldownManager.GetCachedPlayerClass()
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

    -- Handle ticks and power display logic
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

    -- Make this bar accessible globally for config.lua
    CooldownManagerResourceBars["Independent"] = bar
    
    -- Secondary Resource Bar Integration (if enabled)
    local _, class = UnitClass("player")
    local showSecondaryResource = settings.showSecondaryResource ~= false -- Default: enabled
    
    -- Independent secondary resource bar (class specific)
    if not independentSecondaryResourceBar then
        local sbar = CreateFrame("Frame", "CooldownManagerIndependentSecondaryResourceBar", UIParent)
        sbar.Background = sbar:CreateTexture(nil, "BACKGROUND")
        sbar.Background:SetAllPoints()
        sbar.Background:SetColorTexture(unpack(CooldownManager.CONSTANTS.COLORS.BACKGROUND))
        sbar:SetFrameLevel(bar:GetFrameLevel() + 1)
        AddPixelBorder(sbar)
        independentSecondaryResourceBar = sbar
    end
    
    local sbar = independentSecondaryResourceBar
    sbar:Hide() -- Hide by default, show only for applicable classes

    -- Only show secondary resource if enabled and class supports it
    if showSecondaryResource then
        sbar:ClearAllPoints()
        sbar:SetPoint("BOTTOM", bar, "TOP", 0, PixelPerfect(3))
        sbar:SetWidth(bar:GetWidth())
        sbar:SetHeight(math.max(bar:GetHeight() - 2, 8))

        -- Dedicated OnUpdate for 120 FPS secondary resource bar updates
        if not sbar._secondaryUpdateHooked then
            local updateInterval = 0.008
            local elapsed = 0
            sbar:SetScript("OnUpdate", function(self, delta)
                elapsed = elapsed + delta
                if elapsed < updateInterval then return end
                elapsed = 0
                if class == "DEATHKNIGHT" then
                    local totalRunes = 6
                    local runeWidth = PixelPerfect((self:GetWidth() - (totalRunes - 1)) / totalRunes)
                    UpdateDeathKnightRunes(self, totalRunes, runeWidth, texture)
                elseif class == "ROGUE" or (class == "DRUID" and GetSpecialization() == 2) then
                    local maxCP = UnitPowerMax("player", Enum.PowerType.ComboPoints) or 5
                    local currentCP = UnitPower("player", Enum.PowerType.ComboPoints) or 0
                    local pointWidth = PixelPerfect((self:GetWidth() - (maxCP - 1)) / maxCP)
                    UpdateComboPointsOrChi(self, maxCP, currentCP, pointWidth, texture, 
                        CooldownManager.CONSTANTS.COLORS.COMBO_POINTS, {0.3, 0.3, 0.3})
                elseif class == "MONK" and GetSpecialization() == 3 then
                    local maxChi = UnitPowerMax("player", Enum.PowerType.Chi) or 5
                    local currentChi = UnitPower("player", Enum.PowerType.Chi) or 0
                    local pointWidth = PixelPerfect((self:GetWidth() - (maxChi - 1)) / maxChi)
                    UpdateComboPointsOrChi(self, maxChi, currentChi, pointWidth, texture, 
                        CooldownManager.CONSTANTS.COLORS.CHI, {0.2, 0.4, 0.2})
                end
            end)
            sbar._secondaryUpdateHooked = true
        end

        -- Initial update (so it appears instantly)
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
                CooldownManager.CONSTANTS.COLORS.COMBO_POINTS, {0.3, 0.3, 0.3})
        elseif class == "MONK" and GetSpecialization() == 3 then
            sbar:Show()
            local maxChi = UnitPowerMax("player", Enum.PowerType.Chi) or 5
            local currentChi = UnitPower("player", Enum.PowerType.Chi) or 0
            local pointWidth = PixelPerfect((sbar:GetWidth() - (maxChi - 1)) / maxChi)
            UpdateComboPointsOrChi(sbar, maxChi, currentChi, pointWidth, texture, 
                CooldownManager.CONSTANTS.COLORS.CHI, {0.2, 0.4, 0.2})
        end
    else
        sbar:SetScript("OnUpdate", nil)
    end

    -- Make secondary bar accessible globally
    CooldownManagerResourceBars["IndependentSecondary"] = sbar
end

-- Update secondary resource bar for a viewer
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

-- Main update function for all resource bars
function CooldownManager.ResourceBars.UpdateAllResourceBars()
    -- Throttle resource bar updates to prevent excessive calls
    if CooldownManager.ThrottleEvent("resourceBarUpdate", 0.008) then -- ~120 FPS max
        return
    end
    
    UpdateEssenceTracking()

    -- Update independent resource bar
    CooldownManager.ResourceBars.UpdateIndependentResourceBar()

    for _, viewerName in ipairs(CooldownManager.viewers) do
        local viewer = _G[viewerName]
        if viewer then
            CooldownManager.ResourceBars.UpdateResourceBar(viewer)
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

        -- Update secondary bars
        local viewer = _G[name]
        if viewer then
            UpdateSecondaryBar(viewer)
        end
    end
end

-- Initialize essence tracking
function CooldownManager.ResourceBars.InitializeEssenceTracking()
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
                CooldownManager.ResourceBars.UpdateAllResourceBars()
            end

            lastEssence = current
        end
    end)

    -- Optimized Essence Recharge Partial Update
    local throttle = 0
    essenceFrame:SetScript("OnUpdate", function(self, elapsed)
        if not essenceData.active then return end

    throttle = throttle + elapsed
    -- Remove throttle for maximum smoothness (update every frame)
    -- if throttle < 0.016 then return end -- ~60 FPS max (matching original)
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
end

-- Expose essential functions and data globally for other modules
CooldownManager.ResourceBars.secondaryResourceBars = secondaryResourceBars
CooldownManager.ResourceBars.essenceData = essenceData
CooldownManager.ResourceBars.GetRelevantPowerType = GetRelevantPowerType

-- Global function exposures for backward compatibility
UpdateResourceBar = CooldownManager.ResourceBars.UpdateResourceBar
UpdateAllResourceBars = CooldownManager.ResourceBars.UpdateAllResourceBars
GetAuraDataBySpellID = GetAuraDataBySpellID
