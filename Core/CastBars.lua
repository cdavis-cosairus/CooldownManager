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

        -- Apply border safely
        if AddPixelBorder then
            local oldIcon = bar.Icon
            bar.Icon = nil
            AddPixelBorder(bar)
            bar.Icon = oldIcon
        end

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
    bar:SetPoint("BOTTOM", viewer, "TOP", PixelPerfect(offsetX), PixelPerfect(offsetY))

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
    local fontPath = "Interface\\AddOns\\CooldownManager\\Fonts\\FRIZQT__.TTF"
    
    if bar.SpellName then
        bar.SpellName:SetFont(fontPath, fontSize, "OUTLINE")
    end
    if bar.CastTime then
        bar.CastTime:SetFont(fontPath, fontSize, "OUTLINE")
    end

    -- Icon sizing based on bar height
    local barHeight = bar:GetHeight() or height
    if bar.IconFrame then
        bar.IconFrame:SetPoint("LEFT", bar, "LEFT", PixelPerfect(0), 0)
        bar.IconFrame:SetSize(barHeight, barHeight)
    end

    -- Text frame and positioning based on text position setting
    local textPosition = settings.textPosition or "center"
    bar.TextFrame:ClearAllPoints()
    bar.TextFrame:SetPoint("TOPLEFT", bar.IconFrame, "TOPRIGHT", PixelPerfect(4), 0)
    bar.TextFrame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", PixelPerfect(-4), 0)

    -- Clear existing points
    bar.SpellName:ClearAllPoints()
    bar.CastTime:ClearAllPoints()

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

    -- Initial show/hide based on current cast state, but don't set up OnUpdate here
    -- OnUpdate will be managed by events
    local spellName = UnitCastingInfo("player") or UnitChannelInfo("player")
    if spellName then
        if not bar:IsShown() then
            bar:Show()
        end
    else
        if bar:IsShown() then
            bar:Hide()
        end
    end

    -- Make this bar accessible globally for config.lua and cast system
    CooldownManagerCastBars = CooldownManagerCastBars or {}
    CooldownManagerCastBars["Independent"] = bar
end

-- Function to update cast bar with casting information (called by events and OnUpdate)
local function UpdateIndependentCastBarInfo()
    if not independentCastBar then
        return
    end
    
    local bar = independentCastBar
    local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellId
    local isChanneling = false
    
    -- Check for casting first
    name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellId = UnitCastingInfo("player")
    
    -- If not casting, check for channeling
    if not name then
        name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellId = UnitChannelInfo("player")
        isChanneling = true
    end
    
    if name and startTime and endTime then
        -- Show the bar if hidden
        if not bar:IsShown() then
            bar:Show()
            -- Start OnUpdate script for smooth progress
            bar:SetScript("OnUpdate", UpdateIndependentCastBarInfo)
        end
        
        -- Set spell icon
        if bar.Icon and texture then
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
            if isChanneling then
                -- For channeling, progress goes from 1 to 0
                progress = 1 - progress
            end
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
    else
        -- Hide the bar if no casting/channeling
        if bar:IsShown() then
            bar:Hide()
            bar:SetScript("OnUpdate", nil)
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
