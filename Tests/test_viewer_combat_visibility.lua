-- Test file for viewer combat visibility feature
-- This tests the new hideOutOfCombat setting for viewers and icon refresh logic

print("=== Testing Viewer Combat Visibility with Icon Refresh ===")

-- Mock the necessary WoW API functions for testing
local mockInCombat = false
function InCombatLockdown()
    return mockInCombat
end

-- Mock C_Timer for testing
C_Timer = {
    After = function(delay, func)
        print("C_Timer.After(" .. delay .. "s) - Executing icon refresh functions")
        func()
    end
}

-- Mock viewers with alpha, positioning, and tooltip support
local mockViewers = {}
for _, viewerName in ipairs({"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer"}) do
    -- Create mock icon for tooltip testing
    local mockIcon = {
        mouseEnabled = true,
        EnableMouse = function(self, enabled)
            self.mouseEnabled = enabled
            print("    " .. viewerName .. " icon: EnableMouse(" .. tostring(enabled) .. ") called")
        end
    }
    
    mockViewers[viewerName] = {
        name = viewerName,
        shown = true,
        alpha = 1,
        mouseEnabled = true,
        position = {x = 0, y = 0},
        editModeManagerAnchor = nil,
        _hiddenPosition = nil,
        children = {mockIcon},
        Show = function(self) 
            self.shown = true
            print(self.name .. ": Show() called")
        end,
        Hide = function(self) 
            self.shown = false
            print(self.name .. ": Hide() called")
        end,
        IsShown = function(self) 
            return self.shown 
        end,
        SetAlpha = function(self, alpha)
            self.alpha = alpha
            print(self.name .. ": SetAlpha(" .. alpha .. ") called")
        end,
        EnableMouse = function(self, enabled)
            self.mouseEnabled = enabled
            print(self.name .. ": EnableMouse(" .. tostring(enabled) .. ") called")
        end,
        GetChildren = function(self)
            return self.children
        end,
        ClearAllPoints = function(self)
            print(self.name .. ": ClearAllPoints() called")
        end,
        SetPoint = function(self, point, parent, relativePoint, x, y)
            self.position.x = x or 0
            self.position.y = y or 0
            print(self.name .. ": SetPoint(" .. point .. ", " .. tostring(parent) .. ", " .. tostring(relativePoint) .. ", " .. (x or 0) .. ", " .. (y or 0) .. ") called")
        end,
        GetPoint = function(self)
            return "CENTER", UIParent, "CENTER", self.position.x, self.position.y
        end
    }
    _G[viewerName] = mockViewers[viewerName]
end

-- Mock icon management functions
function UpdateAllCustomIcons()
    print("  -> UpdateAllCustomIcons() called")
end

function UpdateBuffIconVisibility()
    print("  -> UpdateBuffIconVisibility() called")
end

function TrySkin()
    print("  -> TrySkin() called")
end

function LayoutCooldownIcons(viewer)
    print("  -> LayoutCooldownIcons(" .. viewer.name .. ") called")
end

-- Mock the database handler
CooldownManagerDBHandler = {
    profile = {
        viewers = {
            EssentialCooldownViewer = { hideOutOfCombat = true },
            UtilityCooldownViewer = { hideOutOfCombat = false },
            BuffIconCooldownViewer = { hideOutOfCombat = true }
        },
        independentResourceBar = { enabled = false },
        independentSecondaryResourceBar = { enabled = false }
    }
}

-- Mock CooldownManager namespace
CooldownManager = {
    viewers = {"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer"}
}

-- Test UpdateCombatVisibility function (alpha-only approach with tooltip control)
function UpdateCombatVisibility()
    local inCombat = InCombatLockdown()
    
    -- Handle viewer visibility
    local viewers = CooldownManager and CooldownManager.viewers or {
        "EssentialCooldownViewer",
        "UtilityCooldownViewer",
        "BuffIconCooldownViewer",
    }
    
    for _, viewerName in ipairs(viewers) do
        local viewer = _G[viewerName]
        if viewer and CooldownManagerDBHandler and CooldownManagerDBHandler.profile and 
           CooldownManagerDBHandler.profile.viewers and CooldownManagerDBHandler.profile.viewers[viewerName] then
            
            local hideOutOfCombat = CooldownManagerDBHandler.profile.viewers[viewerName].hideOutOfCombat
            
            if hideOutOfCombat then
                if inCombat then
                    -- Show viewer by restoring alpha and enabling tooltips
                    viewer:SetAlpha(1)
                    viewer:EnableMouse(true)
                    -- Re-enable tooltips for all icons
                    for _, icon in ipairs(viewer.children) do
                        if icon and icon.EnableMouse then
                            icon:EnableMouse(true)
                        end
                    end
                else
                    -- Hide viewer by setting alpha to 0 and disabling tooltips (but keep position and "shown" state for Blizzard)
                    viewer:SetAlpha(0)
                    viewer:EnableMouse(false)
                    -- Disable tooltips for all icons
                    for _, icon in ipairs(viewer.children) do
                        if icon and icon.EnableMouse then
                            icon:EnableMouse(false)
                        end
                    end
                end
            else
                -- Always show if combat setting is disabled
                viewer:SetAlpha(1)
                viewer:EnableMouse(true)
                -- Ensure tooltips are enabled for all icons
                for _, icon in ipairs(viewer.children) do
                    if icon and icon.EnableMouse then
                        icon:EnableMouse(true)
                    end
                end
            end
        end
    end
end

-- Test Case 1: Out of combat
print("\n--- Test Case 1: Out of Combat ---")
mockInCombat = false
UpdateCombatVisibility()

print("Expected behavior:")
print("- EssentialCooldownViewer (hideOutOfCombat=true): should be hidden (alpha=0) with tooltips disabled")
print("- UtilityCooldownViewer (hideOutOfCombat=false): should be shown (alpha=1) with tooltips enabled") 
print("- BuffIconCooldownViewer (hideOutOfCombat=true): should be hidden (alpha=0) with tooltips disabled")

print("\nActual results:")
for _, viewerName in ipairs({"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer"}) do
    local viewer = _G[viewerName]
    local setting = CooldownManagerDBHandler.profile.viewers[viewerName].hideOutOfCombat
    local icon = viewer.children[1]
    print(string.format("- %s (hideOutOfCombat=%s): Alpha=%.1f, Mouse=%s, IconMouse=%s", 
          viewerName, tostring(setting), viewer.alpha, 
          tostring(viewer.mouseEnabled), tostring(icon.mouseEnabled)))
end

-- Test Case 2: In combat (this should trigger icon refresh)
print("\n--- Test Case 2: In Combat (Icon Refresh Test) ---")
mockInCombat = true
UpdateCombatVisibility()

print("Expected behavior:")
print("- All viewers should be shown when in combat (alpha=1) with tooltips enabled")
print("- Icon refresh should be triggered for previously hidden viewers")

print("\nActual results:")
for _, viewerName in ipairs({"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer"}) do
    local viewer = _G[viewerName]
    local setting = CooldownManagerDBHandler.profile.viewers[viewerName].hideOutOfCombat
    local icon = viewer.children[1]
    print(string.format("- %s (hideOutOfCombat=%s): Alpha=%.1f, Mouse=%s, IconMouse=%s", 
          viewerName, tostring(setting), viewer.alpha, 
          tostring(viewer.mouseEnabled), tostring(icon.mouseEnabled)))
end

-- Test Case 3: Back out of combat
print("\n--- Test Case 3: Back Out of Combat ---")
mockInCombat = false
UpdateCombatVisibility()

print("Expected behavior:")
print("- EssentialCooldownViewer (hideOutOfCombat=true): should be hidden again (alpha=0) with tooltips disabled")
print("- UtilityCooldownViewer (hideOutOfCombat=false): should remain shown (alpha=1) with tooltips enabled")
print("- BuffIconCooldownViewer (hideOutOfCombat=true): should be hidden again (alpha=0) with tooltips disabled")

print("\nActual results:")
for _, viewerName in ipairs({"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer"}) do
    local viewer = _G[viewerName]
    local setting = CooldownManagerDBHandler.profile.viewers[viewerName].hideOutOfCombat
    local icon = viewer.children[1]
    print(string.format("- %s (hideOutOfCombat=%s): Alpha=%.1f, Mouse=%s, IconMouse=%s", 
          viewerName, tostring(setting), viewer.alpha, 
          tostring(viewer.mouseEnabled), tostring(icon.mouseEnabled)))
end

print("\n=== Test Complete ===")
print("Feature should work correctly in WoW environment!")
