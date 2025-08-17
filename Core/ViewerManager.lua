-- Viewer protection and skinning for CooldownManager
local AceDB = LibStub("AceDB-3.0")

-- Ensure CooldownManager namespace exists
CooldownManager = CooldownManager or {}
CooldownManager.ViewerManager = {}

-- Protected viewers tracking
local protectedViewers = {}

-- Protect viewer from unwanted resizing
function CooldownManager.ViewerManager.ProtectViewer(viewer)
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

-- Skin a specific viewer
function CooldownManager.ViewerManager.SkinViewer(viewerName)
    local viewer = _G[viewerName]
    if not viewer then return end

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
    CooldownManager.ViewerManager.ProtectViewer(viewer)
    LayoutCooldownIcons(viewer)
    CooldownManager.IconManager.AdjustIconVisualPadding(viewer)

    -- Skin each icon
    local children = { viewer:GetChildren() }
    local profile = CooldownManagerDBHandler and CooldownManagerDBHandler.profile
    local masqueEnabled = profile and profile.masque and profile.masque.enabled
    local viewerMasqueEnabled = masqueEnabled and profile.masque.viewers and profile.masque.viewers[viewerName] ~= false
    local disableBuiltinSkinning = masqueEnabled and profile.masque.disableBuiltinSkinning
    
    for _, child in ipairs(children) do
        if child and child.Icon then
            -- Apply Masque skinning if enabled
            if viewerMasqueEnabled and CooldownManager.AddIconToMasque then
                CooldownManager.AddIconToMasque(child, viewerName)
                -- Hide built-in borders when Masque is enabled
                if child.__borderParts then
                    for _, line in ipairs(child.__borderParts) do
                        if line then line:Hide() end
                    end
                end
            end
            
            -- Apply built-in styling only if Masque is not enabled for this viewer
            if not viewerMasqueEnabled then
                local z = CooldownManagerDBHandler.profile.iconZoom or 0.25
                child.Icon:SetTexCoord(z, 1 - z, z, 1 - z)
                AddPixelBorder(child)
            end
        end
    end
    
    -- Update Masque group if enabled
    if viewerMasqueEnabled and CooldownManager.UpdateMasqueIcons then
        CooldownManager.UpdateMasqueIcons(viewerName)
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

-- Try to skin all viewers
function CooldownManager.ViewerManager.TrySkin()
    -- Check if icon reskinning is enabled
    if not CooldownManagerDBHandler or not CooldownManagerDBHandler.profile then
        return
    end
    
    for _, name in ipairs(CooldownManager.viewers) do
        CooldownManager.ViewerManager.SkinViewer(name)
    end
    
    -- Also refresh Masque skinning if enabled
    if CooldownManager.IsMasqueEnabled and CooldownManager.IsMasqueEnabled() then
        local profile = CooldownManagerDBHandler and CooldownManagerDBHandler.profile
        if profile and profile.masque and profile.masque.enabled then
            for _, viewerName in ipairs(CooldownManager.viewers) do
                if CooldownManager.UpdateMasqueIcons then
                    CooldownManager.UpdateMasqueIcons(viewerName)
                end
            end
        end
    end
end

-- Initialize viewer manager
function CooldownManager.ViewerManager.Initialize()
    local wasVisible = true
    local watcher = CreateFrame("Frame")
    watcher:SetScript("OnUpdate", function()
        local nowVisible = UIParent:IsVisible()
        if nowVisible and not wasVisible then
            C_Timer.After(0.1, CooldownManager.ViewerManager.TrySkin)
        end
        wasVisible = nowVisible
    end)
    
    -- Initialize edit mode hooks
    CooldownManager.ViewerManager.HookEditModeUpdates()
end

-- Hook edit mode updates
function CooldownManager.ViewerManager.HookEditModeUpdates()
    if EditModeManagerFrame then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() C_Timer.After(0.1, CooldownManager.ViewerManager.TrySkin) end)
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            C_Timer.After(0.1, function()
                CooldownManager.ViewerManager.TrySkin()
                CooldownManager.ResourceBars.UpdateAllResourceBars()
                CooldownManager.IconManager.UpdateAllCustomIcons()
            end)
        end)
    end
end

-- Handle trinket equipment changes
function CooldownManager.ViewerManager.HandleTrinketChange(slot)
    if slot == 13 or slot == 14 then
        C_Timer.After(1, CooldownManager.ViewerManager.TrySkin) -- slight delay ensures texture updates
    end
end

-- Initialize trinket watching
function CooldownManager.ViewerManager.InitializeTrinketWatcher()
    local trinketWatchFrame = CreateFrame("Frame")
    trinketWatchFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    trinketWatchFrame:SetScript("OnEvent", function(_, _, slotID)
        CooldownManager.ViewerManager.HandleTrinketChange(slotID)
    end)
end

-- Clean up Masque skinning for a viewer
function CooldownManager.ViewerManager.CleanupMasque(viewerName)
    if not CooldownManager.IsMasqueEnabled or not CooldownManager.IsMasqueEnabled() then return end
    
    local viewer = _G[viewerName]
    if not viewer then return end
    
    local children = { viewer:GetChildren() }
    for _, child in ipairs(children) do
        if child and child._masqueEnabled and CooldownManager.RemoveIconFromMasque then
            CooldownManager.RemoveIconFromMasque(child, viewerName)
            
            -- Restore built-in borders when Masque is disabled
            if child.__borderParts then
                for _, line in ipairs(child.__borderParts) do
                    if line then line:Show() end
                end
            end
        end
    end
end

-- Re-apply skinning to all viewers (used when settings change)
function CooldownManager.ViewerManager.RefreshAllViewers()
    for _, viewerName in ipairs(CooldownManager.viewers) do
        -- Clean up first if needed
        CooldownManager.ViewerManager.CleanupMasque(viewerName)
        -- Re-apply skinning
        CooldownManager.ViewerManager.SkinViewer(viewerName)
    end
end

-- Expose functions globally
TrySkin = CooldownManager.ViewerManager.TrySkin -- Keep global for compatibility
ProtectViewer = CooldownManager.ViewerManager.ProtectViewer -- Keep global for compatibility
SkinViewer = CooldownManager.ViewerManager.SkinViewer -- Keep global for compatibility
HookEditModeUpdates = CooldownManager.ViewerManager.HookEditModeUpdates -- Keep global for compatibility
