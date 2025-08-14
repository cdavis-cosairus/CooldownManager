-- Buff viewer specific functionality for CooldownManager
local AceDB = LibStub("AceDB-3.0")

-- Ensure CooldownManager namespace exists
CooldownManager = CooldownManager or {}
CooldownManager.BuffViewer = {}

-- Hook buff viewer layout updates
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

-- Update buff icon visibility
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

-- Initialize buff viewer hooks
function CooldownManager.BuffViewer.Initialize()
    HookBuffViewerLayout()
end

-- Update buff viewer visibility
function CooldownManager.BuffViewer.UpdateVisibility()
    UpdateBuffIconVisibility()
end

-- Expose functions for global access
CooldownManager.BuffViewer.UpdateBuffIconVisibility = UpdateBuffIconVisibility
CooldownManager.BuffViewer.HookBuffViewerLayout = HookBuffViewerLayout
