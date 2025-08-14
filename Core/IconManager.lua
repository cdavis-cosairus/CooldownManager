-- Icon management and layout for CooldownManager
local AceDB = LibStub("AceDB-3.0")

-- Ensure CooldownManager namespace exists
CooldownManager = CooldownManager or {}
CooldownManager.IconManager = {}

-- Trinket slot constants
local TRINKET_SLOTS = {13, 14}

-- Trinket usability cache
local trinketUsabilityCache = {}

-- Custom update tracking
local lastCustomUpdate = 0
local UPDATE_INTERVAL = 0.1

-- Class spell cache for performance
local CLASS_SPELL_CACHE = {}

-- Check if spell is usable by player class
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

-- Create a trinket icon
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

-- Helper function to get viewer settings
local function GetViewerSetting(viewer, key, default)
    CooldownManagerDBHandler.profile.viewers = CooldownManagerDBHandler.profile.viewers or {}
    CooldownManagerDBHandler.profile.viewers[viewer] = CooldownManagerDBHandler.profile.viewers[viewer] or {}
    return CooldownManagerDBHandler.profile.viewers[viewer][key] or default
end

-- Create a custom icon for spells
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

-- Adjust icon visual padding
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

-- Main layout function for cooldown icons
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

    -- Clean up unused custom icons
    for spellID, frame in pairs(viewer._customIcons) do
        if frame and not customSpells[spellID] then
            frame:Hide()
            frame:SetParent(nil)
            viewer._customIcons[spellID] = nil
        end
    end

    -- Create custom spell icons
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

    -- Create trinket icons if enabled
    if db.showTrinkets then
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

    -- Sort icons by priority
    table.sort(icons, function(a, b)
        return (tIndexOf(spellPriority, a._spellID) or 9999) < (tIndexOf(spellPriority, b._spellID) or 9999)
    end)

    -- Calculate layout
    local total = #icons
    local rows = math.ceil(total / columns)
    local rowIcons = {}
    for i = 1, rows do rowIcons[i] = {} end
    for i, icon in ipairs(icons) do
        table.insert(rowIcons[math.floor((i - 1) / columns) + 1], icon)
    end

    -- Position icons
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
                    chargeText:SetShown(count > 1)
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
            CooldownManager.ResourceBars.UpdateResourceBar(viewer)
        end
        
        -- Create cast bar if enabled but doesn't exist  
        if settings.showCastBar and not CooldownManagerCastBars[viewerName] then
            CooldownManager.CastBars.UpdateCastBar(viewer)
        end
    end
end

-- Update all custom icons
function CooldownManager.IconManager.UpdateAllCustomIcons()
    local now = GetTime()
    if now - lastCustomUpdate < UPDATE_INTERVAL then return end
    lastCustomUpdate = now

    for _, viewerName in ipairs(CooldownManager.viewers) do
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

-- Expose key functions globally
CooldownManager.IconManager.CreateCustomIcon = CreateCustomIcon
CooldownManager.IconManager.CreateTrinketIcon = CreateTrinketIcon
CooldownManager.IconManager.AdjustIconVisualPadding = AdjustIconVisualPadding
CooldownManager.IconManager.LayoutCooldownIcons = LayoutCooldownIcons
CooldownManager.IconManager.UpdateAllCustomIcons = UpdateAllCustomIcons

-- Make functions available globally for backward compatibility
LayoutCooldownIcons = LayoutCooldownIcons
UpdateAllCustomIcons = UpdateAllCustomIcons
IsSpellUsableByPlayerClass = IsSpellUsableByPlayerClass
