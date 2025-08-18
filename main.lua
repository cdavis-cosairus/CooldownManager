local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDB = LibStub("AceDB-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

local playerClass, playerClassFile = UnitClass("player")

local viewers = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
}

LayoutCooldownIcons = LayoutCooldownIcons or function() end

local protectedViewers = {}
CooldownManagerResourceBars = {}
local resourceBars = CooldownManagerResourceBars
local independentResourceBar = nil
local independentSecondaryResourceBar = nil

-- Initialize core modules on addon load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "CooldownManager" then
        if CooldownManager and CooldownManager.CastBars and CooldownManager.CastBars.InitializeEvents then
            C_Timer.After(0.5, CooldownManager.CastBars.InitializeEvents)
        end
        if CooldownManager and CooldownManager.ViewerManager and CooldownManager.ViewerManager.Initialize then
            C_Timer.After(0.5, CooldownManager.ViewerManager.Initialize)
        end
        if CooldownManager and CooldownManager.ViewerManager and CooldownManager.ViewerManager.InitializeTrinketWatcher then
            C_Timer.After(0.5, CooldownManager.ViewerManager.InitializeTrinketWatcher)
        end
        if CooldownManager and CooldownManager.BuffViewer and CooldownManager.BuffViewer.Initialize then
            C_Timer.After(0.5, CooldownManager.BuffViewer.Initialize)
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

local function UpdateAllResourceBars()
    if CooldownManager and CooldownManager.ResourceBars and CooldownManager.ResourceBars.UpdateAllResourceBars then
        CooldownManager.ResourceBars.UpdateAllResourceBars()
    end
    if CooldownManager and CooldownManager.CastBars and CooldownManager.CastBars.UpdateIndependentCastBar then
        CooldownManager.CastBars.UpdateIndependentCastBar()
    end
    if UpdateCombatVisibility then
        UpdateCombatVisibility()
    end
end

-- Throttle frequent power updates to prevent performance issues during mythic content
local lastPowerUpdate = 0
local POWER_UPDATE_THROTTLE = 0.1 -- Limit to 10 updates per second max

local function ThrottledResourceBarUpdate()
    local now = GetTime()
    if now - lastPowerUpdate < POWER_UPDATE_THROTTLE then
        return
    end
    lastPowerUpdate = now
    UpdateAllResourceBars()
end

local TRINKET_SLOTS = {13, 14}
local trinketUsabilityCache = {}




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
        if UpdateBuffIconVisibility then
            UpdateBuffIconVisibility()
        end
        if UpdateAllCustomIcons then
            UpdateAllCustomIcons()
        end
        UpdateAllResourceBars()
        C_Timer.After(0.5, UpdateAllResourceBars)
        C_Timer.After(1.5, function()
            if TrySkin then
                TrySkin()
            end
        end)
        return
    end

    if event == "UNIT_AURA" and (unit == "player" or unit == "target")
    or event == "PLAYER_ENTERING_WORLD"
    or event == "PLAYER_TALENT_UPDATE"
    or event == "PLAYER_SPECIALIZATION_CHANGED"
    or event == "PLAYER_REGEN_ENABLED"
    or event == "PLAYER_REGEN_DISABLED" then
        if UpdateBuffIconVisibility then
            UpdateBuffIconVisibility()
        end
        if UpdateAllCustomIcons then
            UpdateAllCustomIcons()
        end
        -- Update combat visibility for viewers
        if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
            if UpdateCombatVisibility then
                UpdateCombatVisibility()
            end
        end
    end
    
    if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES"
        or event == "SPELL_ACTIVATION_OVERLAY_SHOW"
        or event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
        if UpdateAllCustomIcons then
            UpdateAllCustomIcons()
            -- Use slight delay for second update to catch any delayed spell changes
            C_Timer.After(0.01, UpdateAllCustomIcons)
        end
        return
    end

    if event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE" then
        UpdateAllResourceBars()
        return
    end

    if unit == "player" then
        -- Use throttled updates for frequent power events to prevent performance issues
        if event == "UNIT_POWER_FREQUENT" then
            ThrottledResourceBarUpdate()
        else
            UpdateAllResourceBars()
        end
        if UpdateAllCustomIcons then
            UpdateAllCustomIcons()
        end
    end
end)

-- Login & Profile Setup
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
                independentCastBar = {
                    enabled = true,
                    attachToViewer = "EssentialCooldownViewer",
                    attachPosition = "top",
                    width = 300,
                    autoWidth = true,
                    height = 24,
                    showIcon = true,
                    showPreview = true,
                },
            }
        }, true)

        if HookBuffViewerLayout then
            HookBuffViewerLayout()
        end
        
        local function RefreshConfig()
            if TrySkin then
                TrySkin()
            end
            if SetupOptions then
                SetupOptions()
            end
            AceConfigRegistry:NotifyChange("CooldownBorders")
        end
        CooldownManagerDBHandler:RegisterCallback("OnProfileChanged", RefreshConfig)
        CooldownManagerDBHandler:RegisterCallback("OnProfileCopied", RefreshConfig)
        CooldownManagerDBHandler:RegisterCallback("OnProfileReset", RefreshConfig)

        C_Timer.After(0.1, function()
            if SetupOptions then
                SetupOptions()
            end
            if HookEditModeUpdates then
                HookEditModeUpdates()
            end
        end)

    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
        C_Timer.After(0.1, function()
            if TrySkin then
                TrySkin()
            end
        end)

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
        UpdateAllResourceBars()
        if UpdateAllCustomIcons then
            UpdateAllCustomIcons()
        end
        if TrySkin then
            TrySkin()
        end
    end
end)


