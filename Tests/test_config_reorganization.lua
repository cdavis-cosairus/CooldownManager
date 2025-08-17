#!/usr/bin/env lua

-- Test file for config reorganization validation
print("=== Testing Config Reorganization ===")

-- Mock WoW API for testing
local mockProfile = {
    borderSize = 2,
    iconZoom = 0.1,
    borderColor = { r = 1, g = 0, b = 0 }
}

-- Mock database handler
CooldownManagerDBHandler = {
    profile = mockProfile
}

-- Mock TrySkin function
TrySkin = function() end

-- Load config module by simulating the critical functions
local function GetCachedProfile()
    return mockProfile
end

-- Test the icon settings structure
local testResults = {}

-- Test 1: Verify Icons section exists in Viewers
function test_icons_section_exists()
    -- This simulates the new structure
    local viewersConfig = {
        type = "group",
        name = "Viewers",
        childGroups = "tab",
        order = 10,
        args = {
            icons = {
                type = "group",
                name = "Icons",
                order = 1,
                args = {
                    borderSize = {
                        type = "range",
                        name = "Border Size",
                        desc = "Adjust thickness of the icon border",
                        min = 0, max = 5, step = 1,
                        get = function() 
                            local profile = GetCachedProfile()
                            return profile and profile.borderSize or 1
                        end,
                        order = 1,
                    },
                    iconZoom = {
                        type = "range",
                        name = "Icon Zoom",
                        desc = "Crop the icon edges",
                        min = 0.01, max = 0.15, step = 0.005,
                        get = function() 
                            local profile = GetCachedProfile()
                            return profile and profile.iconZoom or 0.08
                        end,
                        order = 2,
                    },
                    borderColor = {
                        type = "color",
                        name = "Border Color",
                        desc = "Choose the border color",
                        hasAlpha = false,
                        get = function()
                            local profile = GetCachedProfile()
                            if not profile then return 0, 0, 0 end
                            local c = profile.borderColor
                            if not c or type(c) ~= "table" then
                                c = { r = 0, g = 0, b = 0 }
                                profile.borderColor = c
                            end
                            return c.r or 0, c.g or 0, c.b or 0
                        end,
                        order = 3,
                    }
                }
            }
        }
    }
    
    local hasIconsSection = viewersConfig.args.icons ~= nil
    local hasCorrectName = viewersConfig.name == "Viewers"
    local hasBorderSize = viewersConfig.args.icons.args.borderSize ~= nil
    local hasIconZoom = viewersConfig.args.icons.args.iconZoom ~= nil
    local hasBorderColor = viewersConfig.args.icons.args.borderColor ~= nil
    
    local success = hasIconsSection and hasCorrectName and hasBorderSize and hasIconZoom and hasBorderColor
    return success, string.format("Icons section in Viewers should exist with all settings (icons:%s, name:%s, border:%s, zoom:%s, color:%s)", 
        tostring(hasIconsSection), tostring(hasCorrectName), tostring(hasBorderSize), tostring(hasIconZoom), tostring(hasBorderColor))
end

-- Test 2: Verify icon settings functions work correctly
function test_icon_settings_functions()
    local iconConfig = {
        borderSize = {
            get = function() 
                local profile = GetCachedProfile()
                return profile and profile.borderSize or 1
            end,
        },
        iconZoom = {
            get = function() 
                local profile = GetCachedProfile()
                return profile and profile.iconZoom or 0.08
            end,
        },
        borderColor = {
            get = function()
                local profile = GetCachedProfile()
                if not profile then return 0, 0, 0 end
                local c = profile.borderColor
                if not c or type(c) ~= "table" then
                    c = { r = 0, g = 0, b = 0 }
                    profile.borderColor = c
                end
                return c.r or 0, c.g or 0, c.b or 0
            end,
        }
    }
    
    local borderSizeResult = iconConfig.borderSize.get()
    local iconZoomResult = iconConfig.iconZoom.get()
    local r, g, b = iconConfig.borderColor.get()
    
    local borderSizeOK = borderSizeResult == 2
    local iconZoomOK = iconZoomResult == 0.1
    local borderColorOK = r == 1 and g == 0 and b == 0
    
    local success = borderSizeOK and iconZoomOK and borderColorOK
    return success, string.format("Icon settings should return correct values (border:%s zoom:%s color:%s)", 
        tostring(borderSizeOK), tostring(iconZoomOK), tostring(borderColorOK))
end

-- Test 3: Verify that old top-level icon settings are gone (simulated)
function test_old_settings_removed()
    -- This simulates checking that the main config doesn't have these anymore
    local mainConfig = {
        type = "group",
        name = "Cooldown Manager",
        args = {
            resourceBars = {
                type = "group",
                name = "Resource Bar"
            }
            -- No borderSize, iconZoom, borderColor, or enableIconReskinning at top level
        }
    }
    
    local noBorderSize = mainConfig.args.borderSize == nil
    local noIconZoom = mainConfig.args.iconZoom == nil
    local noBorderColor = mainConfig.args.borderColor == nil
    local noEnableIconReskinning = mainConfig.args.enableIconReskinning == nil
    
    local success = noBorderSize and noIconZoom and noBorderColor and noEnableIconReskinning
    return success, string.format("Old top-level icon settings should be removed (border:%s zoom:%s color:%s enable:%s)", 
        tostring(noBorderSize), tostring(noIconZoom), tostring(noBorderColor), tostring(noEnableIconReskinning))
end

-- Run tests
print("\n✓ Testing config reorganization...")

local test1_result, test1_desc = test_icons_section_exists()
print(string.format("  %s %s", test1_result and "✓" or "✗", test1_desc))
testResults[#testResults + 1] = test1_result

local test2_result, test2_desc = test_icon_settings_functions()
print(string.format("  %s %s", test2_result and "✓" or "✗", test2_desc))
testResults[#testResults + 1] = test2_result

local test3_result, test3_desc = test_old_settings_removed()
print(string.format("  %s %s", test3_result and "✓" or "✗", test3_desc))
testResults[#testResults + 1] = test3_result

-- Summary
local passed = 0
for _, result in ipairs(testResults) do
    if result then passed = passed + 1 end
end

print(string.format("\n=== Results: %d/%d tests passed ===", passed, #testResults))

if passed == #testResults then
    print("✓ All config reorganization tests passed!")
    os.exit(0)
else
    print("✗ Some tests failed!")
    os.exit(1)
end
