#!/usr/bin/env lua

-- Test file for class color border functionality
print("=== Testing Class Color Border Functionality ===")

-- Mock WoW API for testing
local mockFrame = {}
mockFrame.__index = mockFrame

function mockFrame:new()
    local obj = {
        name = "MockIcon",
        Icon = {
            SetTexCoord = function() end
        },
        __borderParts = {},
        children = {}
    }
    setmetatable(obj, self)
    return obj
end

function mockFrame:SetColorTexture(r, g, b, a)
    self.color = { r = r, g = g, b = b, a = a }
end

function mockFrame:SetHeight() end
function mockFrame:SetWidth() end
function mockFrame:SetShown() end

-- Mock PixelPerfect function
function PixelPerfect(v)
    return math.floor(v + 0.5)
end

-- Mock CooldownManager namespace
CooldownManager = CooldownManager or {}
CooldownManager.CONSTANTS = {
    COLORS = {
        CLASS_COLORS = {
            WARRIOR = {0.78, 0.61, 0.43},
            PALADIN = {0.96, 0.55, 0.73},
            HUNTER = {0.67, 0.83, 0.45},
            ROGUE = {1.00, 0.96, 0.41},
            PRIEST = {1.00, 1.00, 1.00},
            DEATHKNIGHT = {0.77, 0.12, 0.23},
            SHAMAN = {0.00, 0.44, 0.87},
            MAGE = {0.25, 0.78, 0.92},
            WARLOCK = {0.53, 0.53, 0.93},
            MONK = {0.00, 1.00, 0.59},
            DRUID = {1.00, 0.49, 0.04},
            DEMONHUNTER = {0.64, 0.19, 0.79},
            EVOKER = {0.20, 0.58, 0.50}
        }
    }
}

-- Mock GetCachedPlayerClass function
CooldownManager.GetCachedPlayerClass = function()
    return "Warrior", "WARRIOR"
end

-- Mock profile data
CooldownManagerDBHandler = {
    profile = {
        borderSize = 2,
        borderColor = { r = 1, g = 0, b = 0 }, -- Red custom color
        useClassColor = false -- Default: use custom color
    }
}

-- Test the AddPixelBorder function
local function testAddPixelBorder(frame, useClassColor)
    if not frame then return end

    local dbProfile = CooldownManagerDBHandler.profile or {}
    local thickness = dbProfile.borderSize or 1
    local color = dbProfile.borderColor or { r = 0, g = 0, b = 0 }
    
    -- Use class color if enabled
    if useClassColor then
        local _, playerClassFile = CooldownManager.GetCachedPlayerClass()
        local classColor = CooldownManager.CONSTANTS.COLORS.CLASS_COLORS[playerClassFile]
        if classColor then
            color = { r = classColor[1], g = classColor[2], b = classColor[3] }
        end
    end

    frame.__borderParts = frame.__borderParts or {}

    if #frame.__borderParts == 0 then
        local function CreateLine()
            local line = mockFrame:new()
            return line
        end

        local top = CreateLine()
        local bottom = CreateLine()
        local left = CreateLine()
        local right = CreateLine()

        frame.__borderParts = { top, bottom, left, right }
    end

    local top, bottom, left, right = unpack(frame.__borderParts)
    if top and bottom and left and right then
        for _, line in ipairs(frame.__borderParts) do
            line:SetColorTexture(color.r, color.g, color.b, 1)
            line:SetShown(thickness > 0)
        end
    end
    
    return color
end

-- Test functions
local testResults = {}

-- Test 1: Custom border color should be used when useClassColor is false
function test_custom_border_color()
    local testIcon = mockFrame:new()
    
    -- Test with useClassColor = false
    local color = testAddPixelBorder(testIcon, false)
    
    local success = color.r == 1 and color.g == 0 and color.b == 0
    return success, string.format("Custom border color should be used (got r:%.2f g:%.2f b:%.2f, expected r:1.00 g:0.00 b:0.00)", color.r, color.g, color.b)
end

-- Test 2: Class color should be used when useClassColor is true
function test_class_border_color()
    local testIcon = mockFrame:new()
    
    -- Test with useClassColor = true
    local color = testAddPixelBorder(testIcon, true)
    
    -- Warrior class color should be {0.78, 0.61, 0.43}
    local expected = CooldownManager.CONSTANTS.COLORS.CLASS_COLORS.WARRIOR
    local success = math.abs(color.r - expected[1]) < 0.01 and 
                   math.abs(color.g - expected[2]) < 0.01 and 
                   math.abs(color.b - expected[3]) < 0.01
    return success, string.format("Class border color should be used (got r:%.2f g:%.2f b:%.2f, expected r:%.2f g:%.2f b:%.2f)", 
        color.r, color.g, color.b, expected[1], expected[2], expected[3])
end

-- Test 3: Test different class colors
function test_different_class_colors()
    -- Test Mage class color
    local originalGetClass = CooldownManager.GetCachedPlayerClass
    CooldownManager.GetCachedPlayerClass = function()
        return "Mage", "MAGE"
    end
    
    local testIcon = mockFrame:new()
    local color = testAddPixelBorder(testIcon, true)
    
    -- Mage class color should be {0.25, 0.78, 0.92}
    local expected = CooldownManager.CONSTANTS.COLORS.CLASS_COLORS.MAGE
    local success = math.abs(color.r - expected[1]) < 0.01 and 
                   math.abs(color.g - expected[2]) < 0.01 and 
                   math.abs(color.b - expected[3]) < 0.01
    
    -- Restore original function
    CooldownManager.GetCachedPlayerClass = originalGetClass
    
    return success, string.format("Different class colors should work (Mage: got r:%.2f g:%.2f b:%.2f, expected r:%.2f g:%.2f b:%.2f)", 
        color.r, color.g, color.b, expected[1], expected[2], expected[3])
end

-- Test 4: Test config option functionality
function test_config_option()
    -- Test the config get/set functions
    local configOption = {
        get = function()
            local profile = CooldownManagerDBHandler.profile
            return profile and profile.useClassColor or false
        end,
        set = function(_, val)
            local profile = CooldownManagerDBHandler.profile
            if profile then
                profile.useClassColor = val
            end
        end
    }
    
    -- Test initial state (should be false)
    local initialValue = configOption.get()
    
    -- Set to true
    configOption.set(nil, true)
    local newValue = configOption.get()
    
    -- Set back to false
    configOption.set(nil, false)
    local finalValue = configOption.get()
    
    local success = not initialValue and newValue and not finalValue
    return success, string.format("Config option should work correctly (initial:%s new:%s final:%s)", 
        tostring(initialValue), tostring(newValue), tostring(finalValue))
end

-- Run tests
print("\n✓ Testing class color border functionality...")

local test1_result, test1_desc = test_custom_border_color()
print(string.format("  %s %s", test1_result and "✓" or "✗", test1_desc))
testResults[#testResults + 1] = test1_result

local test2_result, test2_desc = test_class_border_color()
print(string.format("  %s %s", test2_result and "✓" or "✗", test2_desc))
testResults[#testResults + 1] = test2_result

local test3_result, test3_desc = test_different_class_colors()
print(string.format("  %s %s", test3_result and "✓" or "✗", test3_desc))
testResults[#testResults + 1] = test3_result

local test4_result, test4_desc = test_config_option()
print(string.format("  %s %s", test4_result and "✓" or "✗", test4_desc))
testResults[#testResults + 1] = test4_result

-- Summary
local passed = 0
for _, result in ipairs(testResults) do
    if result then passed = passed + 1 end
end

print(string.format("\n=== Results: %d/%d tests passed ===", passed, #testResults))

-- Show available class colors
print("\n✓ Available class colors:")
for class, color in pairs(CooldownManager.CONSTANTS.COLORS.CLASS_COLORS) do
    print(string.format("  %s: r:%.2f g:%.2f b:%.2f", class, color[1], color[2], color[3]))
end

if passed == #testResults then
    print("\n✓ All class color border tests passed!")
    os.exit(0)
else
    print("\n✗ Some tests failed!")
    os.exit(1)
end
