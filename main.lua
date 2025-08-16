local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDB = LibStub("AceDB-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- Performance Cache (moved to Utils.lua - access via CooldownManager.GetCachedProfile())
local playerClass, playerClassFile = UnitClass("player")

-- Viewer logic
local viewers = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
}

LayoutCooldownIcons = LayoutCooldownIcons or function() end

local protectedViewers = {}

-- Make these global so config.lua can access them
CooldownManagerResourceBars = {}
local resourceBars = CooldownManagerResourceBars

-- Single independent resource bar instead of per-viewer bars
local independentResourceBar = nil
local independentSecondaryResourceBar = nil

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

local function UpdateAllResourceBars()
    -- Delegate to modular ResourceBars system
    if CooldownManager and CooldownManager.ResourceBars and CooldownManager.ResourceBars.UpdateAllResourceBars then
        CooldownManager.ResourceBars.UpdateAllResourceBars()
    end
    
    -- Update independent cast bar
    if CooldownManager and CooldownManager.CastBars and CooldownManager.CastBars.UpdateIndependentCastBar then
        CooldownManager.CastBars.UpdateIndependentCastBar()
    end
    
    -- Update combat visibility for all bars after they're created/updated
    if UpdateCombatVisibility then
        UpdateCombatVisibility()
    end
end

-- Compatibility functions for legacy calls
local function ThrottleEvent(eventName, delay)
    if CooldownManager and CooldownManager.ThrottleEvent then
        return CooldownManager.ThrottleEvent(eventName, delay)
    end
    return false
end

local TRINKET_SLOTS = {13, 14}

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
        
        -- Viewer resource bars removed - use independent resource bar instead
        -- if settings.showResourceBar and not CooldownManagerResourceBars[viewerName] then
        --     UpdateResourceBar(viewer)
        -- end
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
        UpdateAllResourceBars() -- Initialize resource bars on login
        -- Also initialize with a short delay to ensure all player data is available
        C_Timer.After(0.5, UpdateAllResourceBars)
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
