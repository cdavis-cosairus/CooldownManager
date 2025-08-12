local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local LSM = LibStub("LibSharedMedia-3.0")


local viewerNames = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
}

local needsReload = false


SetupOptions = nil
viewerTabs = nil




local function GetViewerSetting(viewer, key, default)
    CooldownManagerDBHandler.profile.viewers = CooldownManagerDBHandler.profile.viewers or {}
    CooldownManagerDBHandler.profile.viewers[viewer] = CooldownManagerDBHandler.profile.viewers[viewer] or {}
    local value = CooldownManagerDBHandler.profile.viewers[viewer][key]
    if value == nil then
        return default
    else
        return value
    end
end

function SetViewerSetting(viewer, key, value)
    CooldownManagerDBHandler.profile.viewers = CooldownManagerDBHandler.profile.viewers or {}
    CooldownManagerDBHandler.profile.viewers[viewer] = CooldownManagerDBHandler.profile.viewers[viewer] or {}
    CooldownManagerDBHandler.profile.viewers[viewer][key] = value
    TrySkin()
end

local generateHiddenSpellArgs
local viewerTabs

local function generateHiddenSpellArgs(viewerName)
    local args = {}
    local db = CooldownManagerDBHandler.profile.viewers[viewerName]
    if not db or not db.hiddenCooldowns or not db.hiddenCooldowns[viewerName] then return args end

    for spellID, hidden in pairs(db.hiddenCooldowns[viewerName]) do
        if hidden then
            local spellInfo = C_Spell.GetSpellInfo(spellID)
            local name = spellInfo and spellInfo.name or "Unknown"
            local icon = spellInfo and spellInfo.iconID or 134400
            local displayName = string.format("|T%d:16|t %s (ID: %d)", icon, name, spellID)

            args["hidden_" .. spellID] = {
                type = "execute",
                name = displayName,
                desc = "Click to unhide this spell from " .. viewerName,
                func = function()
                    if db.hiddenCooldowns and db.hiddenCooldowns[viewerName] then
                        db.hiddenCooldowns[viewerName][spellID] = nil
                    end
                
                    needsReload = true
                
                    C_Timer.After(0.05, function()
                        viewerTabs.args.hideSpells.args[viewerName].args.hiddenList.args = generateHiddenSpellArgs(viewerName)
                        viewerTabs.args.hideSpells.args.reloadUI = {
                            type = "execute",
                            name = "|cff00ffffReload UI|r",
                            desc = "Click to reload and apply unhidden spells",
                            confirm = true,
                            func = function()
                                ReloadUI()
                            end,
                            order = 9999,
                        }
                
                        AceConfigRegistry:NotifyChange("CooldownManager")
                    end)
                end,
                
                
                
                width = "full",
                order = spellID,
            }
        end
    end

    return args
end

local function generateCustomSpellArgs(viewerName)
    local args = {}
    local db = CooldownManagerDBHandler.profile.viewers[viewerName]
    if not db or not db.customSpells then return args end

    local viewer = _G[viewerName]

    local spellList
    local specID = GetSpecializationInfo(GetSpecialization())
    spellList = (db.customSpells and db.customSpells[specID]) or {}
    

    for spellID, enabled in pairs(spellList) do
        spellID = tonumber(spellID)

        local shouldShow = false
        if viewerName == "BuffIconCooldownViewer" then
            shouldShow = true
        else
            shouldShow = IsPlayerSpell(spellID)
        end

        if enabled and shouldShow then
            foundInViewer = true


            if foundInViewer then
                local spellInfo = C_Spell.GetSpellInfo(spellID)
                local name = spellInfo and spellInfo.name or "Unknown"
                local icon = spellInfo and spellInfo.iconID or 134400
                local displayName = string.format("|T%d:16|t %s (ID: %d)", icon, name, spellID)

                args["custom_" .. spellID] = {
                    type = "execute",
                    name = displayName,
                    desc = "Click to remove this spell from " .. viewerName,
                    func = function()
                        local specID = GetSpecializationInfo(GetSpecialization())
                        if db.customSpells and db.customSpells[specID] then
                            db.customSpells[specID][spellID] = nil
                        end

                        db.spellPriority = db.spellPriority or {}
                        local index = tIndexOf(db.spellPriority, spellID)
                        if index then
                            table.remove(db.spellPriority, index)
                        end

                        if viewer then
                            for _, icon in ipairs({ viewer:GetChildren() }) do
                                if icon._spellID == spellID then
                                    icon:Hide()
                                    icon:SetParent(nil)
                                    icon._spellID = nil
                                end
                            end
                        end

                        C_Timer.After(0.05, TrySkin)
                        viewerTabs.args.customSpells.args[viewerName].args.spellList.args = generateCustomSpellArgs(viewerName)

                        AceConfigRegistry:NotifyChange("CooldownManager")
                    end,
                    width = "full",
                    order = spellID,
                }
            end
        end
    end

    return args
end




function tIndexOf(tbl, val)
    for i, v in ipairs(tbl) do
        if v == val then return i end
    end
    return nil
end

--Main GUI
function SetupOptions()
    viewerTabs = {
        type = "group",
        name = "Cooldown Manager",
        args = {
            borderSize = {
                type = "range",
                name = "Border Size",
                desc = "Adjust thickness of the icon border",
                min = 0, max = 5, step = 1,
                get = function() return CooldownManagerDBHandler.profile.borderSize end,
                set = function(_, val)
                    CooldownManagerDBHandler.profile.borderSize = val
                    TrySkin()
                end,
                order = 1,
            },
            iconZoom = {
                type = "range",
                name = "Icon Zoom",
                desc = "Crop the icon edges",
                min = 0.01, max = 0.15, step = 0.005,
                get = function() return CooldownManagerDBHandler.profile.iconZoom end,
                set = function(_, val)
                    CooldownManagerDBHandler.profile.iconZoom = val
                    TrySkin()
                end,
                order = 2,
            },
            borderColor = {
                type = "color",
                name = "Border Color",
                desc = "Choose the border color",
                hasAlpha = false,
                get = function()
                    local c = CooldownManagerDBHandler.profile.borderColor
                    if not c then
                        c = { r = 0, g = 0, b = 0 } -- fallback default if missing
                        CooldownManagerDBHandler.profile.borderColor = c -- fix it in DB too immediately
                    end
                    return c.r, c.g, c.b
                end,
                
                set = function(_, r, g, b)
                    CooldownManagerDBHandler.profile.borderColor = { r = r, g = g, b = b }
                    TrySkin()
                end,
                order = 3,
            },
            useAuraForCooldown = {
                type = "toggle",
                name = "Show Buff Duration Swipe",
                desc = "Toggle whether Blizzard icons use buff durations",
                get = function() return CooldownManagerDBHandler.profile.useAuraForCooldown ~= false end,
                set = function(_, val)
                    CooldownManagerDBHandler.profile.useAuraForCooldown = val
                    TrySkin()
                end,
                order = 4,
            },
            enableIconReskinning = {
                type = "toggle",
                name = "Enable Icon Reskinning",
                desc = "Toggle whether to apply custom styling (borders, zoom, colors) to cooldown icons",
                get = function() return CooldownManagerDBHandler.profile.enableIconReskinning ~= false end,
                set = function(_, val)
                    CooldownManagerDBHandler.profile.enableIconReskinning = val
                    TrySkin()
                end,
                order = 5,
            },
            
            
            resourceBars = {
                type = "group",
                name = "Resource Bars",
                order = 30,
                childGroups = "tab",
                args = {},
            },
            castBars = {
                type = "group",
                name = "Cast Bars",
                order = 31,
                childGroups = "tab",
                args = {},
            },
            
            layout = {
                type = "group",
                name = "Viewer Layouts",
                childGroups = "tab",
                order = 10,
                args = {},
            },        
            hideSpells = {
                type = "group",
                name = "Hide Spells",
                order = 25,
                childGroups = "tab",
                args = {}
            },
            
            customSpells = {
                type = "group",
                name = "Add Spells",
                order = 26,
                childGroups = "tab",
                args = {}
            },
            sortSpells = {
                type = "group",
                name = "Sort Spells",
                order = 27,
                childGroups = "tab",
                args = {},
            },
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(CooldownManagerDBHandler)

        }
    }

    viewerTabs.args.profiles.order = 100

    local orderedViewers = {
        { name = "EssentialCooldownViewer", order = 1 },
        { name = "UtilityCooldownViewer", order = 2 },
        { name = "BuffIconCooldownViewer", order = 3 },
    }

-- Resource Bar
    for _, entry in ipairs(orderedViewers) do
        local viewerName = entry.name
        viewerTabs.args.resourceBars.args[viewerName] = {
            type = "group",
            name = viewerName,
            order = entry.order,
            args = {
                showResourceBar = {
                    type = "toggle",
                    name = "Show Resource Bar",
                    desc = "Toggle showing a resource bar under " .. viewerName,
                    get = function() return GetViewerSetting(viewerName, "showResourceBar", false) end,
                    set = function(_, val) SetViewerSetting(viewerName, "showResourceBar", val) end,
                    width = "full",
                    order = 1,
                },
                resourceBarHeight = {
                    type = "range",
                    name = "Resource Bar Height",
                    desc = "Adjust the height of the resource bar",
                    min = 4, max = 30, step = 1,
                    get = function() return GetViewerSetting(viewerName, "resourceBarHeight", 8) end,
                    set = function(_, val) SetViewerSetting(viewerName, "resourceBarHeight", val) end,
                    order = 2,
                },
                resourceBarTexture = {
                    type = "select",
                    dialogControl = 'LSM30_Statusbar', -- 🔥 this tells AceGUI to use LSM media picker
                    name = "Resource Bar Texture",
                    desc = "Choose the texture for the resource bar",
                    values = LSM:HashTable("statusbar"), -- get all registered statusbar textures
                    get = function()
                        return GetViewerSetting(viewerName, "resourceBarTextureName", "Blizzard")
                    end,
                    set = function(_, key)
                        SetViewerSetting(viewerName, "resourceBarTextureName", key)
                        local path = LSM:Fetch("statusbar", key)
                        SetViewerSetting(viewerName, "resourceBarTexture", path)
                    end,
                    order = 3,
                },
                
                resourceBarFontSize = {
                    type = "range",
                    name = "Resource Number Font Size",
                    desc = "Adjust the font size of the resource number",
                    min = 6, max = 24, step = 1,
                    get = function() return GetViewerSetting(viewerName, "resourceBarFontSize", 10) end,
                    set = function(_, val) SetViewerSetting(viewerName, "resourceBarFontSize", val) end,
                    order = 4,
                },
                resourceBarOffsetY = {
                    type = "range",
                    name = "Resource Bar Y Offset",
                    desc = "Vertical offset of the resource bar relative to the cooldown viewer",
                    min = -100, max = 100, step = 1,
                    get = function() return GetViewerSetting(viewerName, "resourceBarOffsetY", 10) end,
                    set = function(_, val) SetViewerSetting(viewerName, "resourceBarOffsetY", val) end,
                    order = 5,
                },
                resourceBarClassColor = {
                    type = "toggle",
                    name = "Use Class Color",
                    desc = "Color the resource bar by your class color",
                    get = function() return GetViewerSetting(viewerName, "resourceBarClassColor", false) end,
                    set = function(_, val) SetViewerSetting(viewerName, "resourceBarClassColor", val) end,
                    order = 6,
                },
                resourceBarPowerColor = {
                    type = "toggle",
                    name = "Use Class Power Color",
                    desc = "Color the resource bar by your class power color",
                    get = function() return GetViewerSetting(viewerName, "resourceBarPowerColor", false) end,
                    set = function(_, val) SetViewerSetting(viewerName, "resourceBarPowerColor", val) end,
                    order = 7,
                },
                resourceBarCustomColor = {
                    type = "color",
                    name = "Custom Bar Color",
                    desc = "Pick a custom color if not using class color",
                    hasAlpha = false,
                    get = function()
                        local c = GetViewerSetting(viewerName, "resourceBarCustomColor", { r = 0, g = 0.6, b = 1 }) -- default blue
                        return c.r, c.g, c.b
                    end,
                    set = function(_, r, g, b)
                        SetViewerSetting(viewerName, "resourceBarCustomColor", { r = r, g = g, b = b })
                    end,
                    order = 8,
                },                
            }
        }
    end
    
-- Cast Bar
    for _, entry in ipairs(orderedViewers) do
        local viewerName = entry.name
        viewerTabs.args.castBars.args[viewerName] = {
        type = "group",
        name = viewerName,
        order = entry.order,
        args = {
            showCastBar = {
                type = "toggle",
                name = "Show Cast Bar",
                desc = "Toggle showing a cast bar for " .. viewerName,
                get = function() return GetViewerSetting(viewerName, "showCastBar", false) end,
                set = function(_, val) SetViewerSetting(viewerName, "showCastBar", val) end,
                width = "full",
                order = 1,
            },
            castBarHeight = {
                type = "range",
                name = "Cast Bar Height",
                desc = "Height of the cast bar",
                min = 4, max = 30, step = 1,
                get = function() return GetViewerSetting(viewerName, "castBarHeight", 10) end,
                set = function(_, val) SetViewerSetting(viewerName, "castBarHeight", val) end,
                order = 2,
            },
            castBarOffsetY = {
                type = "range",
                name = "Cast Bar Offset Y",
                desc = "Vertical offset for the cast bar",
                min = -200, max = 200, step = 1,
                get = function() return GetViewerSetting(viewerName, "castBarOffsetY", 5) end,
                set = function(_, val) SetViewerSetting(viewerName, "castBarOffsetY", val) end,
                order = 3,
            },
            castBarClassColor = {
                type = "toggle",
                name = "Use Class Color",
                desc = "Color cast bar based on class color",
                get = function() return GetViewerSetting(viewerName, "castBarClassColor", false) end,
                set = function(_, val) SetViewerSetting(viewerName, "castBarClassColor", val) end,
                order = 4,
            },
            castBarCustomColor = {
                type = "color",
                name = "Custom Cast Bar Color",
                desc = "Pick a custom cast bar color",
                hasAlpha = false,
                get = function()
                    local c = GetViewerSetting(viewerName, "castBarCustomColor", { r = 1, g = 0.7, b = 0 })
                    return c.r, c.g, c.b
                end,
                set = function(_, r, g, b)
                    SetViewerSetting(viewerName, "castBarCustomColor", { r = r, g = g, b = b })
                end,
                order = 5,
            },
            castBarFontSize = {
                type = "range",
                name = "Cast Bar Font Size",
                desc = "Font size for text inside the cast bar",
                min = 8, max = 24, step = 1,
                get = function() return GetViewerSetting(viewerName, "castBarFontSize", 12) end,
                set = function(_, val) SetViewerSetting(viewerName, "castBarFontSize", val) end,
                order = 6,
            },
            castBarTexture = {
                type = "select",
                dialogControl = 'LSM30_Statusbar',
                name = "Cast Bar Texture",
                desc = "Choose the texture for the cast bar",
                values = LSM:HashTable("statusbar"),
                get = function()
                    return GetViewerSetting(viewerName, "castBarTextureName", "Blizzard")
                end,
                set = function(_, key)
                    SetViewerSetting(viewerName, "castBarTextureName", key)
                    local path = LSM:Fetch("statusbar", key)
                    SetViewerSetting(viewerName, "castBarTexture", path)
                end,
                order = 7,
            },
            hideOutOfCombat = {
                type = "toggle",
                name = "Hide Out of Combat",
                desc = "Hide this viewer when not in combat",
                get = function() return GetViewerSetting(viewerName, "hideOutOfCombat", false) end,
                set = function(_, val) 
                    SetViewerSetting(viewerName, "hideOutOfCombat", val)
                    UpdateCombatVisibility()
                end,
                order = 8,
            },
            
        }
    }
end

-- Hide Spells
for _, entry in ipairs(orderedViewers) do
    local viewerName = entry.name
    viewerTabs.args.hideSpells.args[viewerName] = {
        type = "group",
        name = viewerName,
        order = entry.order,
        args = {
            spellIDInput = {
                type = "input",
                name = "Hide Spell ID",
                desc = "Enter a SpellID to hide it from " .. viewerName,
                get = function() return "" end,
                set = function(_, val)
                    local id = tonumber(val)
                    if id then
                        CooldownManagerDBHandler.profile.viewers[viewerName] = CooldownManagerDBHandler.profile.viewers[viewerName] or {}
                        local db = CooldownManagerDBHandler.profile.viewers[viewerName]
                        db.hiddenCooldowns = db.hiddenCooldowns or {}
                        db.hiddenCooldowns[viewerName] = db.hiddenCooldowns[viewerName] or {}
                        db.hiddenCooldowns[viewerName][id] = true
                
                        db.spellPriority = db.spellPriority or {}
                        local i = tIndexOf(db.spellPriority, id)
                        if i then table.remove(db.spellPriority, i) end

                
                        C_Timer.After(0.05, function()
                            TrySkin()
                            SetupOptions()
                            AceConfig:RegisterOptionsTable("CooldownManager", viewerTabs)
                            AceConfigRegistry:NotifyChange("CooldownManager")
                            viewerTabs.args.hideSpells.args[viewerName].args.hiddenList.args = generateHiddenSpellArgs(viewerName)
                
                            AceConfigDialog:Open("CooldownManager")
                        end)
                    end
                end,
                
                
                width = "full",
                order = 1,
            },
            hiddenList = {
                type = "group",
                name = "Currently Hidden",
                inline = true,
                order = 2,
                args = generateHiddenSpellArgs(viewerName),
            }
        }
        
    }
end


--Custom Spells
    for _, entry in ipairs(orderedViewers) do
        local viewerName = entry.name
        viewerTabs.args.customSpells.args[viewerName] = {
            type = "group",
            name = viewerName,
            order = entry.order,
            args = {
                spellIDInput = {
                    type = "input",
                    name = "Add Spell ID",
                    desc = "Enter a SpellID to spawn it in " .. viewerName,
                    get = function() return "" end,
                    set = function(_, val)
                        local id = tonumber(val)
                        if id then
                            CooldownManagerDBHandler.profile.viewers[viewerName] = CooldownManagerDBHandler.profile.viewers[viewerName] or {}
                            local db = CooldownManagerDBHandler.profile.viewers[viewerName]
                    
                            local specID = GetSpecializationInfo(GetSpecialization())
                            db.customSpells = db.customSpells or {}
                            db.customSpells[specID] = db.customSpells[specID] or {}
                            db.customSpells[specID][id] = true
                            
                    
                            db.spellPriority = db.spellPriority or {}
                            if not tIndexOf(db.spellPriority, id) then
                                table.insert(db.spellPriority, id)
                            end
                    
                            local viewer = _G[viewerName]
                            if viewer and CreateCustomIcon then
                                local icon = CreateCustomIcon(viewer, id)
                                icon:SetParent(viewer)
                                icon:Show()
                            end

                            viewerTabs.args.customSpells.args[viewerName].args.spellList.args = generateCustomSpellArgs(viewerName)
                    
                            C_Timer.After(0.05, function()
                                TrySkin()
                                SetupOptions()
                                AceConfig:RegisterOptionsTable("CooldownManager", viewerTabs)
                                AceConfigRegistry:NotifyChange("CooldownManager")

                    
                                AceConfigDialog:Open("CooldownManager")
                            end)
                        end
                    end,
                    
                                 
                    
                    width = "full",
                    order = 1,
                },
                spellList = {
                    type = "group",
                    name = "Currently Added Spells",
                    inline = true,
                    order = 2,
                    args = generateCustomSpellArgs(viewerName),
                }
            }
        }
    end

-- Zoom and Border
    for _, entry in ipairs(orderedViewers) do
        local viewer = entry.name
        local v = viewer
        viewerTabs.args.layout.args[v] = {
            type = "group",
            name = v,
            order = entry.order,
            args = {
                iconSize = {
                    type = "range",
                    name = "Icon Size",
                    desc = "Adjust size of cooldown icons for " .. v,
                    min = 16, max = 64, step = 2,
                    get = function() return GetViewerSetting(v, "iconSize", 58) end,
                    set = function(_, val) SetViewerSetting(v, "iconSize", val) end,
                    order = 1,
                },
                iconSpacing = {
                    type = "range",
                    name = "Icon Spacing",
                    desc = "Spacing between icons for " .. v,
                    min = -20, max = 20, step = 2,
                    get = function() return GetViewerSetting(v, "iconSpacing", -4) end,
                    set = function(_, val) SetViewerSetting(v, "iconSpacing", val) end,
                    order = 2,
                },
                iconColumns = {
                    type = "range",
                    name = "Icons Per Row",
                    desc = "How many icons per row for " .. v,
                    min = 1, max = 14, step = 1,
                    get = function() return GetViewerSetting(v, "iconColumns", 14) end,
                    set = function(_, val) SetViewerSetting(v, "iconColumns", val) end,
                    order = 3,
                },
                cooldownFontSize = {
                    type = "range",
                    name = "Cooldown Font Size",
                    desc = "Font size of the cooldown number",
                    min = 6, max = 24, step = 1,
                    get = function() return GetViewerSetting(v, "cooldownFontSize", 18) end,
                    set = function(_, val) SetViewerSetting(v, "cooldownFontSize", val) end,
                    order = 6,
                },                
                chargeFontSize = {
                    type = "range",
                    name = "Charge Font Size",
                    desc = "Font size of the custom charge number",
                    min = 6, max = 24, step = 1,
                    get = function() return GetViewerSetting(v, "chargeFontSize", 18) end,
                    set = function(_, val) SetViewerSetting(v, "chargeFontSize", val) end,
                    order = 5,
                },
                chargeTextOffsetX = {
                    type = "range",
                    name = "Charge X Offset",
                    desc = "Horizontal offset of charge text",
                    min = -60, max = 60, step = 1,
                    get = function() return GetViewerSetting(v, "chargeTextOffsetX", -4) end,
                    set = function(_, val) SetViewerSetting(v, "chargeTextOffsetX", val) end,
                    order = 6,
                },
                chargeTextOffsetY = {
                    type = "range",
                    name = "Charge Y Offset",
                    desc = "Vertical offset of charge text",
                    min = -60, max = 60, step = 1,
                    get = function() return GetViewerSetting(v, "chargeTextOffsetY", 4) end,
                    set = function(_, val) SetViewerSetting(v, "chargeTextOffsetY", val) end,
                    order = 7,
                },
                showTrinkets = {
                    type = "toggle",
                    name = "Show Trinkets",
                    desc = "Enable or disable tracking trinket cooldowns (slots 13 and 14)",
                    order = 8,
                    get = function() return GetViewerSetting(v, "showTrinkets", false) end,
                    set = function(_, val)
                        SetViewerSetting(v, "showTrinkets", val)
                        LayoutCooldownIcons(_G[v])
                        TrySkin()
                    end,
                },
                
            },
        }
    end

--Sort Spells
-- Sort Spells by specID per viewer
for _, entry in ipairs(orderedViewers) do
    local viewerName = entry.name
    local db = CooldownManagerDBHandler.profile.viewers[viewerName] or {}
    local viewer = _G[viewerName]
    local sortArgs = {}

    -- Get current specID
    local specID = GetSpecializationInfo(GetSpecialization())
    db.spellPriorityBySpec = db.spellPriorityBySpec or {}
    db.spellPriorityBySpec[specID] = db.spellPriorityBySpec[specID] or {}
    local priorityList = db.spellPriorityBySpec[specID]

    -- Scan all icons in the viewer (both Blizzard + custom) and collect unique spellIDs
    if viewer then
        for _, icon in ipairs({ viewer:GetChildren() }) do
            local sid = icon._spellID
            if not sid and icon.GetCooldownID then
                local cooldownID = icon:GetCooldownID()
                if cooldownID then
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
                    sid = info and info.spellID
                    if sid then icon._spellID = sid end
                end
            end
            if sid and not tIndexOf(priorityList, sid) then
                table.insert(priorityList, sid)
            end
        end
        if viewer._customIcons then
            for sid in pairs(viewer._customIcons) do
                if not tIndexOf(priorityList, sid) then
                    table.insert(priorityList, sid)
                end
            end
        end
    end

    -- Save updated list
    db.spellPriorityBySpec[specID] = priorityList
    SetViewerSetting(viewerName, "spellPriorityBySpec", db.spellPriorityBySpec)

    for prioIndex, spellID in ipairs(priorityList) do
        spellID = tonumber(spellID)
        if spellID then
            local foundInViewer = false
            if viewer then
                for _, icon in ipairs({ viewer:GetChildren() }) do
                    if icon._spellID == spellID then
                        foundInViewer = true
                        break
                    end
                end
                if not foundInViewer and viewer._customIcons and viewer._customIcons[spellID] then
                    foundInViewer = true
                end
            end

            local isHidden = db.hiddenCooldowns and db.hiddenCooldowns[viewerName] and db.hiddenCooldowns[viewerName][spellID]
            if foundInViewer and not isHidden then
                local info = C_Spell.GetSpellInfo(spellID)
                if info then
                    local name = info.name or "Unknown"
                    local icon = info.iconID or 134400

                    sortArgs["prio_" .. spellID] = {
                        type = "group",
                        name = "",
                        inline = true,
                        order = prioIndex,
                        args = {
                            up = {
                                type = "execute",
                                name = "",
                                image = "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up",
                                imageWidth = 32,
                                imageHeight = 32,
                                func = function()
                                    local i = tIndexOf(priorityList, spellID)
                                    if i and i > 1 then
                                        priorityList[i], priorityList[i - 1] = priorityList[i - 1], priorityList[i]
                                        SetViewerSetting(viewerName, "spellPriorityBySpec", db.spellPriorityBySpec)
                                        C_Timer.After(0.05, function()
                                            TrySkin()
                                            SetupOptions()
                                            AceConfig:RegisterOptionsTable("CooldownManager", viewerTabs)
                                            AceConfigRegistry:NotifyChange("CooldownManager")
                                            AceConfigDialog:Open("CooldownManager")
                                        end)
                                    end
                                end,
                                width = 0.1,
                                order = 1,
                            },
                            down = {
                                type = "execute",
                                name = "",
                                image = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up",
                                imageWidth = 32,
                                imageHeight = 32,
                                func = function()
                                    local i = tIndexOf(priorityList, spellID)
                                    if i and i < #priorityList then
                                        priorityList[i], priorityList[i + 1] = priorityList[i + 1], priorityList[i]
                                        SetViewerSetting(viewerName, "spellPriorityBySpec", db.spellPriorityBySpec)
                                        C_Timer.After(0.05, function()
                                            TrySkin()
                                            SetupOptions()
                                            AceConfig:RegisterOptionsTable("CooldownManager", viewerTabs)
                                            AceConfigRegistry:NotifyChange("CooldownManager")
                                            AceConfigDialog:Open("CooldownManager")
                                        end)
                                    end
                                end,
                                width = 0.1,
                                order = 2,
                            },
                            label = {
                                type = "description",
                                name = string.format("    |T%d:32:32:0:0:64:64:5:59:5:59|t  %s (ID: %d)", icon, name, spellID),
                                fontSize = "medium",
                                width = 1.4,
                                order = 3,
                            },
                        },
                    }
                end
            end
        end
    end

    viewerTabs.args.sortSpells.args[viewerName] = {
        type = "group",
        name = viewerName,
        order = entry.order,
        args = sortArgs,
    }
end


end

local specWatcher = CreateFrame("Frame")
specWatcher:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
specWatcher:SetScript("OnEvent", function()
    SetupOptions()
    AceConfig:RegisterOptionsTable("CooldownManager", viewerTabs)
end)


local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    SetupOptions()
    AceConfig:RegisterOptionsTable("CooldownManager", viewerTabs)
    AceConfigRegistry:NotifyChange("CooldownManager")
    AceConfigDialog:AddToBlizOptions("CooldownManager", "Cooldown Manager")
end)



-- Combat visibility management
function UpdateCombatVisibility()
    local inCombat = InCombatLockdown()
    
    for _, viewerName in ipairs(viewerNames) do
        local viewer = _G[viewerName]
        if viewer then
            local hideOutOfCombat = GetViewerSetting(viewerName, "hideOutOfCombat", false)
            
            if hideOutOfCombat then
                if inCombat then
                    viewer:Show()
                else
                    viewer:Hide()
                end
            else
                viewer:Show() -- Always show if setting is disabled
            end
        end
    end
end

-- Combat event watcher
local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entering combat
combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Leaving combat
combatWatcher:RegisterEvent("PLAYER_LOGIN")          -- Initial state on login
combatWatcher:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Small delay to ensure viewers are created
        C_Timer.After(0.5, UpdateCombatVisibility)
    else
        UpdateCombatVisibility()
    end
end)

SLASH_COOLDOWNMANAGER1 = "/cdm"
SlashCmdList["COOLDOWNMANAGER"] = function()
    SetupOptions()
    AceConfig:RegisterOptionsTable("CooldownManager", viewerTabs)
    AceConfigRegistry:NotifyChange("CooldownManager")
    AceConfigDialog:Open("CooldownManager")
end
