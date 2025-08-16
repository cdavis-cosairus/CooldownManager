-- Event handling for CooldownManager
local AceDB = LibStub("AceDB-3.0")

-- Ensure CooldownManager namespace exists
CooldownManager = CooldownManager or {}
CooldownManager.EventHandler = {}

-- Spell ID tooltip integration
local function AddSpellIDToTooltip(tooltip, data)
    local spellName, spellID = tooltip:GetSpell()
    if spellID then
        tooltip:AddLine(" ")
        tooltip:AddLine("Spell ID: " .. tostring(spellID), 1, 1, 1)
    end
end

-- Initialize tooltip integration
function CooldownManager.EventHandler.InitializeTooltips()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, AddSpellIDToTooltip)
end

-- Handle main events
function CooldownManager.EventHandler.HandleEvent(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        CooldownManager.BuffViewer.UpdateVisibility()
        CooldownManager.IconManager.UpdateAllCustomIcons()
        C_Timer.After(1.5, CooldownManager.ViewerManager.TrySkin)
        return
    end

    -- Buff/aura related events
    if event == "UNIT_AURA" and (unit == "player" or unit == "target")
    or event == "PLAYER_ENTERING_WORLD"
    or event == "PLAYER_TALENT_UPDATE"
    or event == "PLAYER_SPECIALIZATION_CHANGED"
    or event == "PLAYER_REGEN_ENABLED"
    or event == "PLAYER_REGEN_DISABLED"
    or (event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player") then
        CooldownManager.BuffViewer.UpdateVisibility()
        CooldownManager.IconManager.UpdateAllCustomIcons()
    end

    -- Cooldown and charge events
    if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES"
        or event == "SPELL_ACTIVATION_OVERLAY_SHOW"
        or event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
        CooldownManager.IconManager.UpdateAllCustomIcons()
        C_Timer.After(0, CooldownManager.IconManager.UpdateAllCustomIcons)
        return
    end

    -- Rune events
    if event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE" then
        CooldownManager.ResourceBars.UpdateAllResourceBars()
        return
    end

    -- Cast bar and resource bar events
    if unit == "player" then
        -- Handle cast bar events
        CooldownManager.CastBars.HandleCastEvents(event, unit)
        
        -- Update resource bars
        CooldownManager.ResourceBars.UpdateAllResourceBars()
        CooldownManager.IconManager.UpdateAllCustomIcons()
    end
end

-- Register all necessary events
function CooldownManager.EventHandler.RegisterEvents()
    local eventFrame = CreateFrame("Frame")
    
    local events = {
        "UNIT_AURA", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE",
        "PLAYER_ENTERING_WORLD", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
        "RUNE_POWER_UPDATE", "RUNE_TYPE_UPDATE",
        "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_SPELLCAST_SUCCEEDED"
    }
    
    for _, ev in pairs(events) do
        eventFrame:RegisterEvent(ev)
    end

    eventFrame:SetScript("OnEvent", CooldownManager.EventHandler.HandleEvent)
    
    return eventFrame
end

-- Update secondary bars on a timer
function CooldownManager.EventHandler.StartSecondaryBarUpdater()
    local secondaryThrottle = 0
    local watcher = CreateFrame("Frame")
    watcher:SetScript("OnUpdate", function(self, delta)
        secondaryThrottle = secondaryThrottle + delta
        if secondaryThrottle >= 0.1 then
            secondaryThrottle = 0
            for _, viewerName in ipairs(CooldownManager.viewers) do
                local viewer = _G[viewerName]
                if viewer and CooldownManager.ResourceBars.secondaryResourceBars[viewerName] then
                    -- Update secondary resource bars (handled in ResourceBars module)
                end
            end
        end
    end)
end

-- Handle login events
function CooldownManager.EventHandler.HandleLogin()
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

            CooldownManager.BuffViewer.Initialize()

            -- Hook profile changes
            local function RefreshConfig()
                CooldownManager.ViewerManager.TrySkin()
                SetupOptions()
                LibStub("AceConfigRegistry-3.0"):NotifyChange("CooldownBorders")
            end
            CooldownManagerDBHandler:RegisterCallback("OnProfileChanged", RefreshConfig)
            CooldownManagerDBHandler:RegisterCallback("OnProfileCopied", RefreshConfig)
            CooldownManagerDBHandler:RegisterCallback("OnProfileReset", RefreshConfig)

            -- GUI setup + hooks
            C_Timer.After(0, function()
                SetupOptions()
                CooldownManager.ViewerManager.HookEditModeUpdates()
                -- Initialize resource bars after everything is loaded
                CooldownManager.ResourceBars.UpdateAllResourceBars()
            end)

        elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
            C_Timer.After(0, CooldownManager.ViewerManager.TrySkin)

        elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" then
            CooldownManager.ResourceBars.UpdateAllResourceBars()
            CooldownManager.IconManager.UpdateAllCustomIcons()
            CooldownManager.ViewerManager.TrySkin()
        end
    end)
end

-- Initialize all event handlers
function CooldownManager.EventHandler.Initialize()
    -- Initialize tooltips
    CooldownManager.EventHandler.InitializeTooltips()
    
    -- Register main events
    CooldownManager.EventHandler.RegisterEvents()
    
    -- Start secondary bar updater
    CooldownManager.EventHandler.StartSecondaryBarUpdater()
    
    -- Handle login
    CooldownManager.EventHandler.HandleLogin()
    
    -- Initialize cast bar events
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == "CooldownManager" then
            C_Timer.After(1, CooldownManager.CastBars.InitializeEvents)
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
    
    -- Initialize essence tracking
    CooldownManager.ResourceBars.InitializeEssenceTracking()
end
