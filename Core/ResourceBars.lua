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

-- Helper function to add borders to resource bars
local function AddResourceBarBorder(bar, settings)
    if not bar or not settings then return end
    
    local borderSize = settings.borderSize or 0
    local borderColor = settings.borderColor or { r = 1, g = 1, b = 1, a = 1 }
    local borderTexture = settings.borderTexture
    
    -- Remove existing border frame if it exists
    if bar._borderFrame then
        bar._borderFrame:Hide()
        bar._borderFrame = nil
    end
    
    -- Remove old AddPixelBorder style borders if they exist
    if bar.__borderParts then
        for _, line in ipairs(bar.__borderParts) do
            if line then
                line:Hide()
                line:SetParent(nil)
            end
        end
        bar.__borderParts = nil
    end
    
    -- Only create border if size > 0
    if borderSize > 0 then
        -- Create border frame
        bar._borderFrame = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        bar._borderFrame:SetAllPoints(bar)
        bar._borderFrame:SetFrameLevel(bar:GetFrameLevel() + 1)
        
        -- Create border texture
        if borderTexture and LSM then
            -- Use LSM border texture with modern backdrop system
            local texture = LSM:Fetch("border", settings.borderTextureName or "Blizzard Tooltip")
            if texture then
                bar._borderFrame:SetBackdrop({
                    edgeFile = texture,
                    edgeSize = borderSize,
                })
                bar._borderFrame:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
            else
                -- Fallback if texture not found
                bar._borderFrame = nil
                borderSize = 0
            end
        end
        
        -- Fallback to simple pixel border if no texture or texture failed
        if not bar._borderFrame or borderSize == 0 then
            -- Remove failed border frame
            if bar._borderFrame then
                bar._borderFrame:Hide()
                bar._borderFrame = nil
            end
            
            -- Create simple pixel border using textures
            bar._borderFrame = CreateFrame("Frame", nil, bar)
            bar._borderFrame:SetAllPoints(bar)
            bar._borderFrame:SetFrameLevel(bar:GetFrameLevel() + 1)
            
            local function CreateBorderLine()
                local line = bar._borderFrame:CreateTexture(nil, "OVERLAY")
                line:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
                return line
            end
            
            -- Create four border lines
            local top = CreateBorderLine()
            top:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            top:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
            top:SetHeight(borderSize)
            
            local bottom = CreateBorderLine()
            bottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
            bottom:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
            bottom:SetHeight(borderSize)
            
            local left = CreateBorderLine()
            left:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            left:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
            left:SetWidth(borderSize)
            
            local right = CreateBorderLine()
            right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
            right:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
            right:SetWidth(borderSize)
            
            bar._borderFrame._lines = {top, bottom, left, right}
        end
        
        if bar._borderFrame then
            bar._borderFrame:Show()
        end
    end
end

-- Helper function for updating Brewmaster Monk stagger bar
local function UpdateBrewmasterStagger(sbar, texture)
    -- Get stagger info
    local staggerAuraInfo = GetAuraDataBySpellID("player", 124275) -- Heavy Stagger
    if not staggerAuraInfo then
        staggerAuraInfo = GetAuraDataBySpellID("player", 124274) -- Moderate Stagger  
    end
    if not staggerAuraInfo then
        staggerAuraInfo = GetAuraDataBySpellID("player", 124273) -- Light Stagger
    end
    
    local staggerAmount = 0
    local maxHealth = UnitHealthMax("player")
    local staggerPercentage = 0
    local staggerTickDamage = 0
    
    if staggerAuraInfo and staggerAuraInfo.points and staggerAuraInfo.points[1] then
        staggerAmount = staggerAuraInfo.points[1]
        staggerPercentage = (staggerAmount / maxHealth) * 100
        -- Calculate tick damage (stagger ticks every 0.5 seconds, total duration varies)
        staggerTickDamage = math.floor(staggerAmount * 0.02) -- Approximate 2% per tick
    end
    
    -- Create or update the stagger bar
    if not sbar.StaggerBar then
        sbar.StaggerBar = CooldownManager.CreateSecondaryResourceComponent(sbar, texture, sbar:GetWidth(), sbar:GetHeight())
        sbar.StaggerBar:SetPoint("LEFT", sbar, "LEFT", 0, 0)
        
        -- Create text overlays for tick and percentage
        sbar.StaggerBar.TickText = sbar.StaggerBar:CreateFontString(nil, "OVERLAY")
        sbar.StaggerBar.TickText:SetFont(CooldownManager.CONSTANTS.FONTS.DEFAULT, 12, "OUTLINE")
        sbar.StaggerBar.TickText:SetPoint("LEFT", sbar.StaggerBar, "LEFT", 4, 0)
        sbar.StaggerBar.TickText:SetTextColor(1, 1, 1, 1)
        
        sbar.StaggerBar.PercentText = sbar.StaggerBar:CreateFontString(nil, "OVERLAY")
        sbar.StaggerBar.PercentText:SetFont(CooldownManager.CONSTANTS.FONTS.DEFAULT, 12, "OUTLINE")
        sbar.StaggerBar.PercentText:SetPoint("RIGHT", sbar.StaggerBar, "RIGHT", -4, 0)
        sbar.StaggerBar.PercentText:SetTextColor(1, 1, 1, 1)
    end
    
    -- Update bar size to match parent
    sbar.StaggerBar:SetWidth(sbar:GetWidth())
    sbar.StaggerBar:SetHeight(sbar:GetHeight())
    
    -- Set bar fill based on stagger percentage (scale to reasonable max of 50% health)
    local maxDisplayPercentage = 50
    local fillValue = math.min(staggerPercentage / maxDisplayPercentage, 1.0)
    sbar.StaggerBar:SetMinMaxValues(0, 1)
    sbar.StaggerBar:SetValue(fillValue)
    
    -- Color coding based on stagger level
    local color
    if staggerPercentage >= 15 then
        -- Heavy stagger (red)
        color = CooldownManager.CONSTANTS.COLORS.STAGGER.HEAVY
    elseif staggerPercentage >= 6 then
        -- Moderate stagger (yellow/orange)
        color = CooldownManager.CONSTANTS.COLORS.STAGGER.MODERATE
    elseif staggerPercentage > 0 then
        -- Light stagger (green)
        color = CooldownManager.CONSTANTS.COLORS.STAGGER.LIGHT
    else
        -- No stagger (transparent)
        color = {0.3, 0.3, 0.3}
    end
    
    -- Apply brightness multiplier based on fill amount
    local brightness = CalculateBrightnessMultiplier(fillValue)
    sbar.StaggerBar:SetStatusBarColor(color[1] * brightness, color[2] * brightness, color[3] * brightness, 1)
    
    -- Update text displays
    if staggerAmount > 0 then
        sbar.StaggerBar.TickText:SetText(string.format("%d", staggerTickDamage))
        sbar.StaggerBar.PercentText:SetText(string.format("%.1f%%", staggerPercentage))
    else
        sbar.StaggerBar.TickText:SetText("")
        sbar.StaggerBar.PercentText:SetText("")
    end
    
    sbar.StaggerBar:Show()
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
                                (class == "MONK" and (GetSpecialization() == 1 or GetSpecialization() == 3)) or 
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
    local attachPosition = settings.attachPosition or "bottom"  -- Default to bottom for secondary resource bar
    
    if viewer and viewer:IsShown() and settings.attachToViewer ~= "Independent" then
        -- Position relative to viewer with attachment position
        if attachPosition == "bottom" then
            sbar:SetPoint("TOP", viewer, "BOTTOM", PixelPerfect(offsetX), PixelPerfect(-offsetY))
        else -- top
            sbar:SetPoint("BOTTOM", viewer, "TOP", PixelPerfect(offsetX), PixelPerfect(offsetY))
        end
    else
        -- Independent positioning
        offsetY = settings.offsetY or -130  -- Different default for independent mode
        sbar:SetPoint("CENTER", UIParent, "CENTER", PixelPerfect(offsetX), PixelPerfect(offsetY))
    end

    -- Add border if configured
    AddResourceBarBorder(sbar, settings)

    -- Throttled OnUpdate for secondary resource bar updates (60 FPS for performance)
    if not sbar._secondaryUpdateHooked then
        local updateInterval = 0.016  -- ~60 FPS instead of 120 FPS for performance
        local elapsed = 0
        local cachedWidth = nil
        local lastWidthCheck = 0
        
        sbar:SetScript("OnUpdate", function(self, delta)
            elapsed = elapsed + delta
            if elapsed < updateInterval then return end
            elapsed = 0
            
            -- Only update if the bar is actually visible to save performance
            if not self:IsShown() then return end
            
            -- Cache frame width to reduce GetWidth() calls
            local now = GetTime()
            if not cachedWidth or (now - lastWidthCheck) > 0.5 then
                cachedWidth = self:GetWidth() or 300
                if cachedWidth <= 0 then cachedWidth = 300 end
                lastWidthCheck = now
            end
            local frameWidth = cachedWidth
            
            if class == "DEATHKNIGHT" then
                local totalRunes = 6
                local runeWidth = PixelPerfect((frameWidth - (totalRunes - 1)) / totalRunes)
                UpdateDeathKnightRunes(self, totalRunes, runeWidth, texture)
            elseif class == "ROGUE" or (class == "DRUID" and GetSpecialization() == 2) then
                -- Cache power values to reduce API calls
                local powerData = CooldownManager.PerformanceCache and 
                    CooldownManager.PerformanceCache.GetCachedPower("player", Enum.PowerType.ComboPoints) or 
                    { current = UnitPower("player", Enum.PowerType.ComboPoints), max = UnitPowerMax("player", Enum.PowerType.ComboPoints) }
                local maxCP = powerData.max or 5
                local currentCP = powerData.current or 0
                local pointWidth = PixelPerfect((frameWidth - (maxCP - 1)) / maxCP)
                
                -- Use cached colors
                local colors = CooldownManager.PerformanceCache and CooldownManager.PerformanceCache.GetCachedColors() or {}
                local activeColor = colors.combo_points or CooldownManager.CONSTANTS.COLORS.COMBO_POINTS
                local inactiveColor = colors.inactive or {0.3, 0.3, 0.3}
                
                UpdateComboPointsOrChi(self, maxCP, currentCP, pointWidth, texture, activeColor, inactiveColor)
            elseif class == "MONK" and GetSpecialization() == 1 then
                -- Brewmaster Monk - Stagger Bar
                UpdateBrewmasterStagger(self, texture)
            elseif class == "MONK" and GetSpecialization() == 3 then
                -- Cache power values to reduce API calls
                local powerData = CooldownManager.PerformanceCache and 
                    CooldownManager.PerformanceCache.GetCachedPower("player", Enum.PowerType.Chi) or 
                    { current = UnitPower("player", Enum.PowerType.Chi), max = UnitPowerMax("player", Enum.PowerType.Chi) }
                local maxChi = powerData.max or 5
                local currentChi = powerData.current or 0
                local pointWidth = PixelPerfect((frameWidth - (maxChi - 1)) / maxChi)
                
                -- Use cached colors
                local colors = CooldownManager.PerformanceCache and CooldownManager.PerformanceCache.GetCachedColors() or {}
                local activeColor = colors.chi or CooldownManager.CONSTANTS.COLORS.CHI
                local inactiveColor = colors.chi_inactive or {0.2, 0.4, 0.2}
                
                UpdateComboPointsOrChi(self, maxChi, currentChi, pointWidth, texture, activeColor, inactiveColor)
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
    elseif class == "MONK" and GetSpecialization() == 1 then
        sbar:Show()
        UpdateBrewmasterStagger(sbar, texture)
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
        independentResourceBar = bar
    end

    local bar = independentResourceBar
    
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
    bar:SetSize(width, height)
    
    -- Update texture - use LSM if available, otherwise default
    local texture = settings.texture or CooldownManager.CONSTANTS.TEXTURES.DEFAULT_STATUSBAR
    if settings.textureName and LSM then
        texture = LSM:Fetch("statusbar", settings.textureName) or texture
    end
    bar:SetStatusBarTexture(texture)
    
    if bar.Text then
        local fontSize = settings.fontSize or CooldownManager.CONSTANTS.SIZES.DEFAULT_FONT_SIZE
        
        -- Apply custom font selection
        local fontPath = CooldownManager.CONSTANTS.FONTS.DEFAULT
        if settings.font and LSM then
            fontPath = LSM:Fetch("font", settings.font) or fontPath
        elseif settings.font then
            fontPath = settings.font
        end
        
        bar.Text:SetFont(fontPath, fontSize, "OUTLINE")
        
        -- Apply text alignment
        local textAlign = settings.textAlign or "CENTER"
        bar.Text:SetJustifyH(textAlign)
        
        -- Apply text positioning offsets
        local textOffsetX = settings.textOffsetX or 0
        local textOffsetY = settings.textOffsetY or 0
        
        -- Reposition the text with custom offsets
        bar.Text:ClearAllPoints()
        bar.Text:SetPoint("CENTER", bar.TextFrame, "CENTER", 
                         PixelPerfect(2 + textOffsetX), PixelPerfect(1 + textOffsetY))
    end

    -- Position relative to viewer if available, otherwise independently
    bar:ClearAllPoints()
    local offsetX = settings.offsetX or 0
    local offsetY = settings.offsetY or 20
    local attachPosition = settings.attachPosition or "top"  -- Default to top for main resource bar
    
    if viewer and viewer:IsShown() then
        -- Position relative to viewer with attachment position
        if attachPosition == "bottom" then
            bar:SetPoint("TOP", viewer, "BOTTOM", PixelPerfect(offsetX), PixelPerfect(-offsetY))
        else -- top
            bar:SetPoint("BOTTOM", viewer, "TOP", PixelPerfect(offsetX), PixelPerfect(offsetY))
        end
    else
        -- Fall back to independent positioning
        offsetY = settings.offsetY or -100  -- Different default for independent mode
        bar:SetPoint("CENTER", UIParent, "CENTER", PixelPerfect(offsetX), PixelPerfect(offsetY))
    end

    -- Add border if configured
    AddResourceBarBorder(bar, settings)

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

    -- Resource value calculation (optimized with caching)
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
        -- Use cached power values to reduce API calls
        local powerData = CooldownManager.PerformanceCache and 
            CooldownManager.PerformanceCache.GetCachedPower("player", powerType) or 
            { current = UnitPower("player", powerType), max = UnitPowerMax("player", powerType) }
        current = powerData.current
        max = powerData.max
    else
        current = 0
        max = 0
    end

    -- Bar fill
    if max > 0 then
        bar:SetMinMaxValues(0, max)
        bar:SetValue(current)
        if bar.Text then
            -- Only hide text for Soul Fragments when shown to non-Demon Hunter
            local shouldHideText = (powerType == 203981 and class ~= "DEMONHUNTER") -- Soul Fragments for non-DH
            
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

    -- Optimized Essence Recharge Partial Update (Throttled for Performance)
    local throttle = 0
    essenceFrame:SetScript("OnUpdate", function(self, elapsed)
        if not essenceData.active then return end

        throttle = throttle + elapsed
        -- Throttle to 60 FPS for performance during mythic content
        if throttle < 0.016 then return end -- ~60 FPS max
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
                    -- Only hide text for Soul Fragments when shown to non-Demon Hunter
                    local _, class = UnitClass("player")
                    local shouldHideText = (powerType == 203981 and class ~= "DEMONHUNTER") -- Soul Fragments for non-DH
                    
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
