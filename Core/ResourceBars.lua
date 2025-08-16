-- Resource Bar management for CooldownManager
local LSM = LibStub("LibSharedMedia-3.0")

-- Ensure CooldownManager namespace exists
CooldownManager = CooldownManager or {}
CooldownManager.ResourceBars = {}

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

-- Helper function to calculate brightness based on fill percentage
local function CalculateBrightnessMultiplier(fillPercentage)
    -- Base brightness at 20% or less: 0.4 (40% brightness)
    -- Full brightness at 100%: 1.0 (100% brightness)
    -- Gradual increase from 20% to 100%
    
    if fillPercentage <= 0.2 then
        return 0.4 -- Base brightness for 20% or less
    else
        -- Linear interpolation from 0.4 (at 20%) to 1.0 (at 100%)
        local progress = (fillPercentage - 0.2) / 0.8 -- Normalize 20%-100% to 0-1
        return 0.4 + (0.6 * progress) -- 0.4 + 60% increase over the range
    end
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
            
            -- Apply brightness multiplier based on fill percentage
            local brightness = CalculateBrightnessMultiplier(value)
            statusColor = { color[1] * brightness, color[2] * brightness, color[3] * brightness, 1 }
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
    
    -- Sort by recharge progress: most recharged (highest value) on left, least recharged on right
    table.sort(runeStates, function(a, b)
        -- First compare by value (recharge progress)
        if a.value ~= b.value then
            return a.value > b.value -- Higher recharge progress goes left
        end
        -- If values are equal, prefer ready runes
        return a.ready and not b.ready
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
        rune:SetHeight(PixelPerfect(sbar:GetHeight())) -- Update height to match parent
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

-- Helper function for updating combo points/chi with individual point brightness
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
        point:SetHeight(PixelPerfect(sbar:GetHeight())) -- Update height to match parent
        point:ClearAllPoints()
        if i == 1 then
            point:SetPoint("LEFT", sbar, "LEFT", 0, 0)
        else
            point:SetPoint("LEFT", sbar.Points[i - 1], "RIGHT", PixelPerfect(1), 0)
        end
        
        if i <= currentPoints then
            point:SetValue(1)
            -- Each active point gets brighter based on its position (older points are brighter)
            -- Point 1 is the oldest, point N is the newest
            local pointAge = (i - 1) / math.max(currentPoints - 1, 1) -- 0 for first point, 1 for last point
            if currentPoints == 1 then pointAge = 1 end -- Single point should be full brightness
            local brightness = CalculateBrightnessMultiplier(0.2 + (pointAge * 0.8)) -- Range from 20% to 100%
            point:SetStatusBarColor(colorActive[1] * brightness, colorActive[2] * brightness, colorActive[3] * brightness, 1)
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

-- Viewer resource bars removed - functionality consolidated to independent resource bar only

-- Update independent secondary resource bar
function CooldownManager.ResourceBars.UpdateIndependentSecondaryResourceBar()
    local profile = CooldownManager.GetCachedProfile()
    if not profile or not profile.independentSecondaryResourceBar or not profile.independentSecondaryResourceBar.enabled then
        if independentSecondaryResourceBar then 
            independentSecondaryResourceBar:Hide() 
            independentSecondaryResourceBar = nil
        end
        return
    end

    local settings = profile.independentSecondaryResourceBar
    local _, class = UnitClass("player")
    
    -- Only show for classes that have secondary resources
    local hasSecondaryResource = (class == "DEATHKNIGHT") or 
                                (class == "ROGUE") or 
                                (class == "DRUID" and GetSpecialization() == 2) or 
                                (class == "MONK" and GetSpecialization() == 3) or 
                                (class == "DEMONHUNTER" and GetSpecialization() == 2)
    
    if not hasSecondaryResource then
        if independentSecondaryResourceBar then 
            independentSecondaryResourceBar:Hide() 
            independentSecondaryResourceBar = nil
        end
        return
    end

    -- Create secondary resource bar if it doesn't exist
    if not independentSecondaryResourceBar then
        local sbar = CreateFrame("Frame", "CooldownManagerIndependentSecondaryResourceBar", UIParent)
        sbar.Background = sbar:CreateTexture(nil, "BACKGROUND")
        sbar.Background:SetAllPoints()
        sbar.Background:SetColorTexture(unpack(CooldownManager.CONSTANTS.COLORS.BACKGROUND))
        AddPixelBorder(sbar)
        independentSecondaryResourceBar = sbar
    end

    local sbar = independentSecondaryResourceBar
    
    -- Calculate width - try to match viewer width if available or use manual setting
    local attachToViewer = settings.attachToViewer or "EssentialCooldownViewer"
    local viewer = _G[attachToViewer]
    local width
    
    if viewer and viewer:IsShown() and CooldownManager.CalculateBarWidth and settings.autoWidth then
        -- Use viewer-based width calculation if viewer is available and auto width is enabled
        width = CooldownManager.CalculateBarWidth(settings, viewer)
    else
        -- Fall back to manual width setting
        width = settings.width or CooldownManager.CONSTANTS.SIZES.DEFAULT_BAR_WIDTH
    end
    
    -- Safety check to ensure width is never nil
    if not width or width <= 0 then
        width = CooldownManager.CONSTANTS.SIZES.DEFAULT_BAR_WIDTH or 300
    end
    
    width = PixelPerfect(width)
    local height = PixelPerfect(settings.height or CooldownManager.CONSTANTS.SIZES.DEFAULT_RESOURCE_HEIGHT)
    sbar:SetSize(width, height)
    
    -- Update texture - use LSM if available, otherwise default
    local texture = settings.texture or CooldownManager.CONSTANTS.TEXTURES.DEFAULT_STATUSBAR
    if settings.textureName and LSM then
        texture = LSM:Fetch("statusbar", settings.textureName) or texture
    end

    -- Position relative to viewer if available, otherwise independently
    sbar:ClearAllPoints()
    local offsetX = settings.offsetX or 0
    local offsetY = settings.offsetY or -30  -- Default below instead of above
    
    if viewer and viewer:IsShown() and settings.attachToViewer ~= "Independent" then
        -- Position relative to viewer
        sbar:SetPoint("TOP", viewer, "TOP", PixelPerfect(offsetX), PixelPerfect(offsetY))
    else
        -- Independent positioning
        offsetY = settings.offsetY or -130  -- Different default for independent mode
        sbar:SetPoint("CENTER", UIParent, "CENTER", PixelPerfect(offsetX), PixelPerfect(offsetY))
    end

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
                local frameWidth = self:GetWidth() or 300
                if frameWidth <= 0 then frameWidth = 300 end
                local runeWidth = PixelPerfect((frameWidth - (totalRunes - 1)) / totalRunes)
                UpdateDeathKnightRunes(self, totalRunes, runeWidth, texture)
            elseif class == "ROGUE" or (class == "DRUID" and GetSpecialization() == 2) then
                local maxCP = UnitPowerMax("player", Enum.PowerType.ComboPoints) or 5
                local currentCP = UnitPower("player", Enum.PowerType.ComboPoints) or 0
                local frameWidth = self:GetWidth() or 300
                if frameWidth <= 0 then frameWidth = 300 end
                local pointWidth = PixelPerfect((frameWidth - (maxCP - 1)) / maxCP)
                UpdateComboPointsOrChi(self, maxCP, currentCP, pointWidth, texture, 
                    CooldownManager.CONSTANTS.COLORS.COMBO_POINTS, {0.3, 0.3, 0.3})
            elseif class == "MONK" and GetSpecialization() == 3 then
                local maxChi = UnitPowerMax("player", Enum.PowerType.Chi) or 5
                local currentChi = UnitPower("player", Enum.PowerType.Chi) or 0
                local frameWidth = self:GetWidth() or 300
                if frameWidth <= 0 then frameWidth = 300 end
                local pointWidth = PixelPerfect((frameWidth - (maxChi - 1)) / maxChi)
                UpdateComboPointsOrChi(self, maxChi, currentChi, pointWidth, texture, 
                    CooldownManager.CONSTANTS.COLORS.CHI, {0.2, 0.4, 0.2})
            elseif class == "DEMONHUNTER" and GetSpecialization() == 2 then
                -- Vengeance Demon Hunter Soul Fragments
                local maxFragments = 5
                local fragmentAura = GetAuraDataBySpellID("player", 203981)
                local currentFragments = fragmentAura and fragmentAura.applications or 0
                local frameWidth = self:GetWidth() or 300
                if frameWidth <= 0 then frameWidth = 300 end
                local pointWidth = PixelPerfect((frameWidth - (maxFragments - 1)) / maxFragments)
                UpdateComboPointsOrChi(self, maxFragments, currentFragments, pointWidth, texture, {0.7, 0.2, 1}, {0.3, 0.3, 0.3})
            end
        end)
        sbar._secondaryUpdateHooked = true
    end

    -- Initial update (so it appears instantly)
    if class == "DEATHKNIGHT" then
        sbar:Show()
        local totalRunes = 6
        local frameWidth = sbar:GetWidth() or 300
        if frameWidth <= 0 then frameWidth = 300 end
        local runeWidth = PixelPerfect((frameWidth - (totalRunes - 1)) / totalRunes)
        UpdateDeathKnightRunes(sbar, totalRunes, runeWidth, texture)
    elseif class == "ROGUE" or (class == "DRUID" and GetSpecialization() == 2) then
        sbar:Show()
        local maxCP = UnitPowerMax("player", Enum.PowerType.ComboPoints) or 5
        local currentCP = UnitPower("player", Enum.PowerType.ComboPoints) or 0
        local frameWidth = sbar:GetWidth() or 300
        if frameWidth <= 0 then frameWidth = 300 end
        local pointWidth = PixelPerfect((frameWidth - (maxCP - 1)) / maxCP)
        UpdateComboPointsOrChi(sbar, maxCP, currentCP, pointWidth, texture, 
            CooldownManager.CONSTANTS.COLORS.COMBO_POINTS, {0.3, 0.3, 0.3})
    elseif class == "MONK" and GetSpecialization() == 3 then
        sbar:Show()
        local maxChi = UnitPowerMax("player", Enum.PowerType.Chi) or 5
        local currentChi = UnitPower("player", Enum.PowerType.Chi) or 0
        local frameWidth = sbar:GetWidth() or 300
        if frameWidth <= 0 then frameWidth = 300 end
        local pointWidth = PixelPerfect((frameWidth - (maxChi - 1)) / maxChi)
        UpdateComboPointsOrChi(sbar, maxChi, currentChi, pointWidth, texture, 
            CooldownManager.CONSTANTS.COLORS.CHI, {0.2, 0.4, 0.2})
    elseif class == "DEMONHUNTER" and GetSpecialization() == 2 then
        sbar:Show()
        local maxFragments = 5
        local fragmentAura = GetAuraDataBySpellID("player", 203981)
        local currentFragments = fragmentAura and fragmentAura.applications or 0
        local frameWidth = sbar:GetWidth() or 300
        if frameWidth <= 0 then frameWidth = 300 end
        local pointWidth = PixelPerfect((frameWidth - (maxFragments - 1)) / maxFragments)
        UpdateComboPointsOrChi(sbar, maxFragments, currentFragments, pointWidth, texture, {0.7, 0.2, 1}, {0.3, 0.3, 0.3})
    end

    -- Make secondary bar accessible globally
    CooldownManagerResourceBars["IndependentSecondary"] = sbar
end

-- Update independent resource bar
function CooldownManager.ResourceBars.UpdateIndependentResourceBar()
    local profile = CooldownManager.GetCachedProfile()
    if not profile or not profile.independentResourceBar or not profile.independentResourceBar.enabled then
        if independentResourceBar then 
            independentResourceBar:Hide() 
            independentResourceBar = nil
        end
        return
    end

    local settings = profile.independentResourceBar

    -- Create main resource bar if it doesn't exist
    if not independentResourceBar then
        local bar = CooldownManager.CreateStandardBar("CooldownManagerIndependentResourceBar", "resource", settings)
        bar:SetStatusBarColor(0, 0.6, 1, 1)
        bar.Ticks = {}
        AddPixelBorder(bar)
        independentResourceBar = bar
    end

    local bar = independentResourceBar
    
    -- Calculate width - try to match viewer width if available
    local attachToViewer = settings.attachToViewer or "EssentialCooldownViewer"
    local viewer = _G[attachToViewer]
    local width
    
    if viewer and viewer:IsShown() and CooldownManager.CalculateBarWidth then
        -- Use viewer-based width calculation if viewer is available
        width = CooldownManager.CalculateBarWidth(settings, viewer)
    else
        -- Fall back to manual width setting
        width = settings.width or CooldownManager.CONSTANTS.SIZES.DEFAULT_BAR_WIDTH
    end
    
    -- Safety check to ensure width is never nil
    if not width or width <= 0 then
        width = CooldownManager.CONSTANTS.SIZES.DEFAULT_BAR_WIDTH or 300
    end
    
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

    -- Position relative to viewer if available, otherwise independently
    bar:ClearAllPoints()
    local offsetX = settings.offsetX or 0
    local offsetY = settings.offsetY or 20
    
    if viewer and viewer:IsShown() then
        -- Position relative to viewer
        bar:SetPoint("TOP", viewer, "TOP", PixelPerfect(offsetX), PixelPerfect(offsetY))
    else
        -- Fall back to independent positioning
        offsetY = settings.offsetY or -100  -- Different default for independent mode
        bar:SetPoint("CENTER", UIParent, "CENTER", PixelPerfect(offsetX), PixelPerfect(offsetY))
    end

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
            -- Hide text if value is 0, or if showing Soul Fragments for non-Demon Hunter
            local shouldHideText = (current == 0) or 
                                  (powerType == 203981 and class ~= "DEMONHUNTER") -- Soul Fragments for non-DH
            
            if shouldHideText then
                bar.Text:SetText("")
            elseif powerType == Enum.PowerType.Mana then
                bar.Text:SetText(math.floor((current / max) * 100) .. "%")
            else
                bar.Text:SetText(math.floor(current))
            end
        end
    end

    -- Make this bar accessible globally for config.lua
    CooldownManagerResourceBars["Independent"] = bar
end

-- Main update function for all resource bars
function CooldownManager.ResourceBars.UpdateAllResourceBars()
    -- Throttle resource bar updates to prevent excessive calls
    if CooldownManager.ThrottleEvent("resourceBarUpdate", 0.008) then -- ~120 FPS max
        return
    end
    
    UpdateEssenceTracking()

    -- Update independent resource bars
    CooldownManager.ResourceBars.UpdateIndependentResourceBar()
    CooldownManager.ResourceBars.UpdateIndependentSecondaryResourceBar()
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

        -- Update independent resource bar for essence changes (viewer bars removed)
        if independentResourceBar and independentResourceBar:IsShown() then
            local powerType = GetRelevantPowerType()
            if powerType == Enum.PowerType.Essence then
                local value = essenceData.current + (essenceData.partial or 0)
                independentResourceBar:SetValue(value)
                if independentResourceBar.Text then
                    -- Hide text if value is 0 or if showing Soul Fragments for non-Demon Hunter
                    local _, class = UnitClass("player")
                    local shouldHideText = (value == 0) or 
                                          (powerType == 203981 and class ~= "DEMONHUNTER") -- Soul Fragments for non-DH
                    
                    if shouldHideText then
                        independentResourceBar.Text:SetText("")
                    else
                        independentResourceBar.Text:SetText(math.floor(value))
                    end
                end
            end
        end
    end)
end

-- Expose essential functions and data globally for other modules
CooldownManager.ResourceBars.essenceData = essenceData
CooldownManager.ResourceBars.GetRelevantPowerType = GetRelevantPowerType
CooldownManager.ResourceBars.UpdateEssenceTracking = UpdateEssenceTracking
CooldownManager.ResourceBars.GetEssenceRechargeTime = GetEssenceRechargeTime

-- Global function exposures for backward compatibility
UpdateAllResourceBars = CooldownManager.ResourceBars.UpdateAllResourceBars
GetRelevantPowerType = GetRelevantPowerType
UpdateEssenceTracking = UpdateEssenceTracking
GetEssenceRechargeTime = GetEssenceRechargeTime
GetAuraDataBySpellID = GetAuraDataBySpellID

-- Expose essenceData globally for main.lua access during transition
_G.essenceData = essenceData
