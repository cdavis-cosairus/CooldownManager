-- Independent Cast Bar management for CooldownManager
local AceDB = LibStub("AceDB-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- Ensure CooldownManager namespace exists
CooldownManager = CooldownManager or {}
CooldownManager.CastBars = {}

-- Ensure global table exists for backward compatibility
CooldownManagerCastBars = CooldownManagerCastBars or {}

-- Independent cast bar instance
local independentCastBar = nil
local independentCastBarEventFrame = nil

-- Update independent cast bar
function CooldownManager.CastBars.UpdateIndependentCastBar()
    -- Initialize events if not already done
    CooldownManager.CastBars.InitializeEvents()
    
    -- Safety check
    local profile = GetCachedProfile and GetCachedProfile() or (CooldownManagerDBHandler and CooldownManagerDBHandler.profile)
    if not profile or not profile.independentCastBar or not profile.independentCastBar.enabled then
        if independentCastBar then 
            independentCastBar:Hide() 
            independentCastBar = nil
        end
        return
    end

    local settings = profile.independentCastBar
    local attachToViewer = settings.attachToViewer or "EssentialCooldownViewer"
    local viewer = _G[attachToViewer]
    
    if not viewer then return end

    -- Create cast bar if it doesn't exist
    if not independentCastBar then
        local bar = CreateFrame("StatusBar", "CooldownManagerIndependentCastBar", UIParent)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        -- Set initial texture (will be updated below)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:SetHeight(PixelPerfect(settings.height or 22))

        bar.Background = bar:CreateTexture(nil, "BACKGROUND")
        bar.Background:SetAllPoints()
        bar.Background:SetColorTexture(0.1, 0.1, 0.1, 1)

        bar.IconFrame = CreateFrame("Frame", nil, bar)
        bar.Icon = bar.IconFrame:CreateTexture(nil, "ARTWORK")
        bar.Icon:SetAllPoints()
        bar.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        bar.TextFrame = CreateFrame("Frame", nil, bar)
        bar.TextFrame:SetFrameLevel(bar:GetFrameLevel() + 10)

        bar.SpellName = bar.TextFrame:CreateFontString(nil, "OVERLAY")
        bar.SpellName:SetJustifyH("LEFT")
        bar.SpellName:SetJustifyV("MIDDLE")
        bar.SpellName:SetWordWrap(false)

        bar.CastTime = bar.TextFrame:CreateFontString(nil, "OVERLAY")
        bar.CastTime:SetJustifyH("RIGHT")
        bar.CastTime:SetJustifyV("MIDDLE")

        -- Create tick indicators for empowered spells
        bar.TickContainer = CreateFrame("Frame", nil, bar)
        bar.TickContainer:SetAllPoints(bar)
        bar.TickContainer:SetFrameLevel(bar:GetFrameLevel() + 5)
        bar.Ticks = {}

        -- Note: Border will be handled by UpdateCastBarBorder function
        -- This ensures our new border system works properly

        independentCastBar = bar
    end

    local bar = independentCastBar
    if not bar then return end
    
    -- Update bar properties
    local width
    if settings.autoWidth then
        -- Calculate width based on the attached viewer (same logic as resource bars)
        if viewer.Selection then
            width = viewer.Selection:GetWidth()
            if width == 0 or not width then
                local viewerSettings = CooldownManagerDBHandler.profile.viewers[attachToViewer] or {}
                local size = viewerSettings.iconSize or 58
                local spacing = (viewerSettings.iconSpacing or -4) - 3
                local columns = viewerSettings.iconColumns or 14
                width = (size + spacing) * columns - spacing
            else
                local padding = 6
                width = width - (padding * 3)
            end
        else
            -- Fallback calculation if no Selection frame
            local viewerSettings = CooldownManagerDBHandler.profile.viewers[attachToViewer] or {}
            local size = viewerSettings.iconSize or 58
            local spacing = (viewerSettings.iconSpacing or -4) - 3
            local columns = viewerSettings.iconColumns or 14
            width = (size + spacing) * columns - spacing
        end
        width = math.max(width or 300, 50) -- Ensure minimum width
    else
        width = settings.width or 300
    end
    
    width = PixelPerfect(width)
    local height = PixelPerfect(settings.height or 22)
    bar:SetSize(width, height)
    
    -- Update texture - use LSM if available, otherwise default
    local texture = "Interface\\TargetingFrame\\UI-StatusBar" -- Default texture
    if settings.textureName and LSM then
        texture = LSM:Fetch("statusbar", settings.textureName) or texture
    elseif settings.texture then
        texture = settings.texture
    end
    bar:SetStatusBarTexture(texture)

    -- Position relative to viewer
    bar:ClearAllPoints()
    local offsetX = settings.offsetX or 0
    local offsetY = settings.offsetY or 17
    local attachPosition = settings.attachPosition or "top"
    
    if attachPosition == "bottom" then
        bar:SetPoint("TOP", viewer, "BOTTOM", PixelPerfect(offsetX), PixelPerfect(-offsetY))
    else -- top (default)
        bar:SetPoint("BOTTOM", viewer, "TOP", PixelPerfect(offsetX), PixelPerfect(offsetY))
    end

    -- Bar color
    if settings.classColor then
        local classColor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
        if classColor then
            bar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, 1)
        end
    else
        local c = settings.customColor or { r = 1, g = 0.7, b = 0 }
        bar:SetStatusBarColor(c.r, c.g, c.b, 1)
    end

    -- Font setup
    local fontSize = settings.fontSize or 16
    local fontPath = settings.fontPath or "Interface\\AddOns\\CooldownManager\\Fonts\\FRIZQT__.TTF"
    local fontOutline = settings.fontOutline or "OUTLINE"
    
    -- Use LSM if font name is specified
    if settings.fontName and LSM then
        fontPath = LSM:Fetch("font", settings.fontName) or fontPath
    end
    
    if bar.SpellName then
        bar.SpellName:SetFont(fontPath, fontSize, fontOutline)
    end
    if bar.CastTime then
        bar.CastTime:SetFont(fontPath, fontSize, fontOutline)
    end

    -- Icon sizing and visibility based on settings
    local barHeight = bar:GetHeight() or height
    local showIcon = settings.showIcon ~= false -- default to true
    
    if bar.IconFrame then
        if showIcon then
            bar.IconFrame:Show()
            bar.IconFrame:SetPoint("LEFT", bar, "LEFT", PixelPerfect(0), 0)
            bar.IconFrame:SetSize(barHeight, barHeight)
        else
            bar.IconFrame:Hide()
        end
    end

    -- Text frame positioning based on icon visibility
    bar.TextFrame:ClearAllPoints()
    if showIcon and bar.IconFrame then
        bar.TextFrame:SetPoint("TOPLEFT", bar.IconFrame, "TOPRIGHT", PixelPerfect(4), 0)
    else
        bar.TextFrame:SetPoint("TOPLEFT", bar, "TOPLEFT", PixelPerfect(4), 0)
    end
    bar.TextFrame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", PixelPerfect(-4), 0)

    -- Clear existing points
    bar.SpellName:ClearAllPoints()
    bar.CastTime:ClearAllPoints()

    -- Get text positioning setting
    local textPosition = settings.textPosition or "center"
    
    if textPosition == "left" then
        -- Both texts on the left side
        bar.SpellName:SetPoint("LEFT", bar.TextFrame, "LEFT", 0, 0)
        bar.SpellName:SetPoint("RIGHT", bar.TextFrame, "CENTER", -2, 0)
        bar.CastTime:SetPoint("LEFT", bar.TextFrame, "CENTER", 2, 0)
        bar.CastTime:SetPoint("RIGHT", bar.TextFrame, "RIGHT", 0, 0)
        bar.SpellName:SetJustifyH("LEFT")
        bar.CastTime:SetJustifyH("LEFT")
    elseif textPosition == "right" then
        -- Both texts on the right side
        bar.SpellName:SetPoint("LEFT", bar.TextFrame, "LEFT", 0, 0)
        bar.SpellName:SetPoint("RIGHT", bar.TextFrame, "CENTER", -2, 0)
        bar.CastTime:SetPoint("LEFT", bar.TextFrame, "CENTER", 2, 0)
        bar.CastTime:SetPoint("RIGHT", bar.TextFrame, "RIGHT", 0, 0)
        bar.SpellName:SetJustifyH("RIGHT")
        bar.CastTime:SetJustifyH("RIGHT")
    else -- center (default)
        -- Spell name on left, cast time on right (centered layout)
        bar.SpellName:SetPoint("LEFT", bar.TextFrame, "LEFT", 0, 0)
        bar.SpellName:SetPoint("RIGHT", bar.TextFrame, "CENTER", -2, 0)
        bar.CastTime:SetPoint("LEFT", bar.TextFrame, "CENTER", 2, 0)
        bar.CastTime:SetPoint("RIGHT", bar.TextFrame, "RIGHT", 0, 0)
        bar.SpellName:SetJustifyH("LEFT")
        bar.CastTime:SetJustifyH("RIGHT")
    end

    -- Update border appearance
    CooldownManager.CastBars.UpdateCastBarBorder(bar, settings)

    -- Make sure the frame is properly positioned and visible for configuration
    -- Check if user wants to preview the cast bar when not casting
    local showPreview = settings.showPreview or false
    
    -- Initial show/hide based on current cast state
    local spellName = UnitCastingInfo("player") or UnitChannelInfo("player")
    if spellName then
        -- Currently casting - show the bar
        if not bar:IsShown() then
            bar:Show()
        end
    else
        -- Not casting - show only if preview is enabled
        if showPreview then
            if not bar:IsShown() then
                bar:Show()
                -- Show a preview state
                bar:SetValue(0.5) -- 50% for preview
                if bar.SpellName then
                    bar.SpellName:SetText("Cast Bar Preview")
                end
                if bar.CastTime then
                    bar.CastTime:SetText("0.0s")
                end
            end
        else
            -- Hide when not casting and preview is disabled
            if bar:IsShown() then
                bar:Hide()
            end
        end
    end

    -- Make this bar accessible globally for config.lua and cast system
    CooldownManagerCastBars = CooldownManagerCastBars or {}
    CooldownManagerCastBars["Independent"] = bar
end

-- Function to update cast bar border appearance
function CooldownManager.CastBars.UpdateCastBarBorder(bar, settings)
    if not bar then return end
    
    -- Clean up existing border and background frames
    if bar.__borderFrame then
        bar.__borderFrame:Hide()
        bar.__borderFrame = nil
    end
    if bar.__backgroundFrame then
        bar.__backgroundFrame:Hide()
        bar.__backgroundFrame = nil
    end
    
    -- Clean up old AddPixelBorder remnants if they exist
    if bar.__borderParts then
        for _, part in ipairs(bar.__borderParts) do
            if part then
                part:Hide()
                part = nil
            end
        end
        bar.__borderParts = nil
    end
    
    -- Get border and background settings
    local borderTexture = settings.borderTexture
    local borderTextureName = settings.borderTextureName or "Blizzard Tooltip"
    local borderSize = settings.borderSize or 8
    local borderColor = settings.borderColor or { r = 1, g = 1, b = 1, a = 1 }
    local showBackground = settings.showBackground or false
    local backgroundColor = settings.backgroundColor or { r = 0, g = 0, b = 0, a = 0.8 }
    local backgroundClassColor = settings.backgroundClassColor or false
    local backgroundTexture = settings.backgroundTexture
    local backgroundTextureName = settings.backgroundTextureName or "Blizzard"
    
    -- Use LSM to get textures if available
    if borderTextureName and LSM then
        borderTexture = LSM:Fetch("border", borderTextureName) or borderTexture
    end
    if backgroundTextureName and LSM then
        backgroundTexture = LSM:Fetch("statusbar", backgroundTextureName) or backgroundTexture
    end
    
    -- Get class color for background if enabled
    if backgroundClassColor then
        local _, class = UnitClass("player")
        if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
            local classColor = RAID_CLASS_COLORS[class]
            backgroundColor = { 
                r = classColor.r, 
                g = classColor.g, 
                b = classColor.b, 
                a = backgroundColor.a -- Keep the original alpha
            }
        end
    end
    
    -- Hide the old background texture that was causing issues
    if bar.Background then
        bar.Background:Hide()
    end
    
    -- Create background frame if background is enabled
    if showBackground then
        local backgroundFrame = CreateFrame("Frame", nil, bar)
        backgroundFrame:SetAllPoints(bar)
        backgroundFrame:SetFrameLevel(bar:GetFrameLevel() - 1) -- Behind the status bar
        
        -- Create background texture
        local bgTexture = backgroundFrame:CreateTexture(nil, "BACKGROUND")
        bgTexture:SetAllPoints(backgroundFrame)
        
        -- Apply texture or color
        if backgroundTexture then
            -- Use the selected statusbar texture
            bgTexture:SetTexture(backgroundTexture)
            -- Apply color tint to the texture
            bgTexture:SetVertexColor(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundColor.a)
        else
            -- Fallback to solid color if no texture
            bgTexture:SetColorTexture(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundColor.a)
        end
        
        -- Store reference for cleanup
        bar.__backgroundFrame = backgroundFrame
    end
    
    -- Create border frame - always create this for the border
    local borderFrame = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    borderFrame:SetPoint("TOPLEFT", bar, "TOPLEFT", -borderSize, borderSize)
    borderFrame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", borderSize, -borderSize)
    borderFrame:SetFrameLevel(bar:GetFrameLevel() + 1) -- In front of the status bar
    
    -- Set up backdrop with ONLY border, no background
    borderFrame:SetBackdrop({
        edgeFile = borderTexture or "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = borderSize,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    
    -- Set border color only - no background color
    borderFrame:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
    
    -- Make sure the border frame is visible
    borderFrame:Show()
    
    -- Store reference for cleanup
    bar.__borderFrame = borderFrame
end

-- Function to create and update tick indicators for empowered spells
function CooldownManager.CastBars.UpdateEmpowermentTicks(bar, numStages, currentStage)
    if not bar or not bar.TickContainer or not bar.Ticks then 
        return 
    end
    
    -- Get settings
    local profile = CooldownManagerDBHandler and CooldownManagerDBHandler.profile
    local settings = profile and profile.independentCastBar or {}
    local enableTicks = settings.enableTicks ~= false -- Default: enabled
    
    -- Hide all existing ticks first
    for i = 1, #bar.Ticks do
        if bar.Ticks[i] then
            bar.Ticks[i]:Hide()
        end
    end
    
    -- Don't show ticks if disabled or no stages or only 1 stage
    if not enableTicks or not numStages or numStages <= 1 then
        return
    end
    
    local barWidth = bar:GetWidth()
    if not barWidth or barWidth <= 0 then
        return
    end
    
    -- Account for icon space if icon is shown
    local showIcon = settings.showIcon ~= false
    local iconWidth = showIcon and bar:GetHeight() or 0
    local usableWidth = barWidth - iconWidth
    
    -- Get tick appearance settings
    local tickWidth = settings.tickWidth or 3
    local tickHeight = (settings.tickHeight or 0.8) * bar:GetHeight()
    local activeColor = settings.tickActiveColor or { r = 1, g = 0.8, b = 0, a = 1.0 }  -- Orange/gold for active
    local inactiveColor = settings.tickInactiveColor or { r = 0.3, g = 0.3, b = 0.3, a = 0.8 }  -- Dark gray for inactive
    
    -- Create segment-style indicators for each empowerment stage
    for i = 1, numStages do
        -- Create tick if it doesn't exist
        if not bar.Ticks[i] then
            local tick = bar.TickContainer:CreateTexture(nil, "OVERLAY")
            -- Use a solid texture for segment-style appearance
            tick:SetTexture("Interface\\Buttons\\WHITE8X8")
            tick:SetBlendMode("BLEND")
            bar.Ticks[i] = tick
        end
        
        local tick = bar.Ticks[i]
        
        -- Calculate segment dimensions
        local segmentWidth = usableWidth / numStages
        local segmentHeight = tickHeight
        
        -- Make segments slightly smaller than full width to create gaps
        local actualSegmentWidth = segmentWidth - 2
        
        -- Update tick size for segment appearance
        tick:SetWidth(actualSegmentWidth)
        tick:SetHeight(segmentHeight)
        
        -- Position the segment
        local segmentStart = iconWidth + ((i - 1) * segmentWidth)
        local segmentCenter = segmentStart + (segmentWidth / 2)
        
        tick:ClearAllPoints()
        tick:SetPoint("CENTER", bar, "LEFT", segmentCenter, 0)
        
        -- Color the segment based on whether this stage has been reached
        if currentStage and i <= currentStage then
            -- Reached stage - use active color
            tick:SetVertexColor(activeColor.r, activeColor.g, activeColor.b, activeColor.a)
        else
            -- Unreached stage - use inactive color
            tick:SetVertexColor(inactiveColor.r, inactiveColor.g, inactiveColor.b, inactiveColor.a)
        end
        
        tick:Show()
    end
end

-- Function to update cast bar with casting information (called by events and OnUpdate)
local function UpdateIndependentCastBarInfo()
    if not independentCastBar then
        return
    end
    
    local bar = independentCastBar
    local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellId
    local isChanneling = false
    local isEmpowered = false
    local numEmpowerStages = 0
    
    -- Check for casting first
    name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellId = UnitCastingInfo("player")
    
    -- If not casting, check for channeling (including empowered spells)
    if not name then
        name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellId, isEmpowered, numEmpowerStages = UnitChannelInfo("player")
        isChanneling = true
    end
    
    if name and startTime and endTime then
        -- Show the bar if hidden
        if not bar:IsShown() then
            bar:Show()
            -- Start OnUpdate script for smooth progress
            bar:SetScript("OnUpdate", UpdateIndependentCastBarInfo)
        end
        
        -- Set spell icon (only if enabled)
        local profile = CooldownManagerDBHandler and CooldownManagerDBHandler.profile
        local settings = profile and profile.independentCastBar or {}
        local showIcon = settings.showIcon ~= false -- default to true
        
        if bar.Icon and texture and showIcon then
            bar.Icon:SetTexture(texture)
        end
        
        -- Set spell name
        if bar.SpellName then
            bar.SpellName:SetText(name or "")
        end
        
        -- Calculate progress and remaining time
        local currentTime = GetTime() * 1000 -- Convert to milliseconds
        local duration = endTime - startTime
        local elapsed = currentTime - startTime
        local remaining = (endTime - currentTime) / 1000 -- Convert back to seconds
        
        -- Set progress bar
        if duration > 0 then
            local progress = elapsed / duration
            -- Special handling for empowered spells - treat them like normal casts
            if isChanneling and not isEmpowered then
                -- For normal channeling, progress goes from 1 to 0
                progress = 1 - progress
            end
            -- For empowered spells or normal casts, progress goes from 0 to 1
            bar:SetValue(math.max(0, math.min(1, progress)))
        end
        
        -- Set cast time text
        if bar.CastTime then
            if remaining > 0 then
                bar.CastTime:SetText(string.format("%.1f", remaining))
            else
                bar.CastTime:SetText("")
            end
        end
        
        -- Handle empowered spell tick indicators
        if isEmpowered and numEmpowerStages and numEmpowerStages > 1 then
            -- For empowered spells, calculate progress like a normal cast (0 to 1)
            local currentStage = 0
            
            if duration > 0 then
                -- Calculate progress as 0 to 1 (like normal cast)
                local progress = elapsed / duration
                
                -- Calculate empowerment stage based on progress
                if progress < 0.2 then
                    currentStage = 0  -- Very early in cast
                elseif progress < 0.4 then
                    currentStage = 1  -- First empowerment stage
                elseif progress < 0.6 then
                    currentStage = 2  -- Second empowerment stage
                elseif progress < 0.8 then
                    currentStage = 3  -- Third empowerment stage (if available)
                else
                    currentStage = math.min(numEmpowerStages, 4)  -- Max empowerment
                end
                
                -- Don't exceed available stages
                currentStage = math.min(currentStage, numEmpowerStages)
            end
            
            -- Update tick indicators
            CooldownManager.CastBars.UpdateEmpowermentTicks(bar, numEmpowerStages, currentStage)
        else
            -- Hide tick indicators for non-empowered spells
            CooldownManager.CastBars.UpdateEmpowermentTicks(bar, 0, 0)
        end
    else
        -- Hide the bar if no casting/channeling
        if bar:IsShown() then
            bar:Hide()
            bar:SetScript("OnUpdate", nil)
            -- Clear tick indicators when hiding
            CooldownManager.CastBars.UpdateEmpowermentTicks(bar, 0, 0)
        end
    end
end

-- Initialize independent cast bar events
function CooldownManager.CastBars.InitializeEvents()
    if independentCastBarEventFrame then
        return -- Already initialized
    end
    
    independentCastBarEventFrame = CreateFrame("Frame")
    independentCastBarEventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    independentCastBarEventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    independentCastBarEventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    independentCastBarEventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    independentCastBarEventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    independentCastBarEventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    independentCastBarEventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    independentCastBarEventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    independentCastBarEventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
    independentCastBarEventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
    independentCastBarEventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")

    independentCastBarEventFrame:SetScript("OnEvent", function(self, event, unit)
        if unit == "player" then
            -- Call the info update function directly
            UpdateIndependentCastBarInfo()
        end
    end)
end

-- Expose functions for global access
UpdateIndependentCastBar = CooldownManager.CastBars.UpdateIndependentCastBar
CooldownManager.CastBars.UpdateIndependentCastBarInfo = UpdateIndependentCastBarInfo
