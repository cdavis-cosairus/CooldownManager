#!/usr/bin/env lua

-- Test file for resource bar auto width functionality
print("=== Testing Resource Bar Auto Width ===")

-- Mock WoW API for testing
local mockViewer = {}
mockViewer.__index = mockViewer

function mockViewer:new(width)
    local obj = {
        width = width or 500,
        shown = true,
        Selection = {
            GetWidth = function() return width or 500 end
        }
    }
    setmetatable(obj, self)
    return obj
end

function mockViewer:IsShown()
    return self.shown
end

function mockViewer:GetWidth()
    return self.width
end

function mockViewer:GetName()
    return "TestViewer"
end

-- Mock PixelPerfect function
function PixelPerfect(v)
    return math.floor(v + 0.5)
end

-- Mock CooldownManager namespace
CooldownManager = CooldownManager or {}
CooldownManager.CONSTANTS = {
    SIZES = {
        DEFAULT_BAR_WIDTH = 300,
        DEFAULT_RESOURCE_HEIGHT = 16
    }
}

-- Mock profile data
CooldownManager.GetCachedProfile = function()
    return {
        viewers = {
            TestViewer = {
                iconSize = 58,
                iconSpacing = -4,
                iconColumns = 14
            }
        }
    }
end

-- Mock the CalculateBarWidth function from Utils.lua
CooldownManager.CalculateBarWidth = function(settings, viewer)
    if not settings.autoWidth then
        return settings.width or 300
    end
    
    local width
    if viewer.Selection then
        width = viewer.Selection:GetWidth()
        if width == 0 or not width then
            -- Fallback calculation
            local viewerSettings = CooldownManager.GetCachedProfile().viewers[viewer:GetName()] or {}
            local size = viewerSettings.iconSize or 58
            local spacing = (viewerSettings.iconSpacing or -4) - 2
            local columns = viewerSettings.iconColumns or 14
            width = (size + spacing) * columns - spacing
        else
            local padding = 6
            width = width - (padding * 3)
        end
    else
        -- Fallback calculation if no Selection frame
        local viewerSettings = CooldownManager.GetCachedProfile().viewers[viewer:GetName()] or {}
        local size = viewerSettings.iconSize or 58
        local spacing = (viewerSettings.iconSpacing or -4) - 2
        local columns = viewerSettings.iconColumns or 14
        width = (size + spacing) * columns - spacing
    end
    
    return math.max(width or 300, 50)
end

-- Test the resource bar width calculation logic
local function testResourceBarWidthCalculation(settings, viewer)
    local width
    
    if viewer and viewer:IsShown() and CooldownManager.CalculateBarWidth and settings.autoWidth then
        -- Use viewer-based width calculation if viewer is available and auto width is enabled
        width = CooldownManager.CalculateBarWidth(settings, viewer)
    else
        -- Fall back to manual width setting
        width = settings.width or CooldownManager.CONSTANTS.SIZES.DEFAULT_BAR_WIDTH
    end
    
    -- Safety check to ensure width is never nil
    if not width or width <= 0 then
        width = CooldownManager.CONSTANTS.SIZES.DEFAULT_BAR_WIDTH or 300
    end
    
    return PixelPerfect(width)
end

-- Test functions
local testResults = {}

-- Test 1: Auto width enabled with visible viewer should use calculated width
function test_auto_width_with_viewer()
    local viewer = mockViewer:new(500)
    local settings = {
        autoWidth = true,
        width = 200 -- Manual setting should be ignored
    }
    
    local result = testResourceBarWidthCalculation(settings, viewer)
    local expected = CooldownManager.CalculateBarWidth(settings, viewer)
    
    local success = result == PixelPerfect(expected)
    return success, string.format("Auto width with viewer should calculate width (got %d, expected %d)", result, PixelPerfect(expected))
end

-- Test 2: Auto width disabled should use manual width
function test_manual_width()
    local viewer = mockViewer:new(500)
    local settings = {
        autoWidth = false,
        width = 400
    }
    
    local result = testResourceBarWidthCalculation(settings, viewer)
    local expected = 400
    
    local success = result == expected
    return success, string.format("Manual width should be used when auto width disabled (got %d, expected %d)", result, expected)
end

-- Test 3: Auto width enabled but no viewer should use manual width
function test_auto_width_no_viewer()
    local settings = {
        autoWidth = true,
        width = 350
    }
    
    local result = testResourceBarWidthCalculation(settings, nil)
    local expected = 350
    
    local success = result == expected
    return success, string.format("Auto width with no viewer should use manual width (got %d, expected %d)", result, expected)
end

-- Test 4: No settings should use default width
function test_default_width()
    local settings = {}
    
    local result = testResourceBarWidthCalculation(settings, nil)
    local expected = CooldownManager.CONSTANTS.SIZES.DEFAULT_BAR_WIDTH
    
    local success = result == expected
    return success, string.format("No settings should use default width (got %d, expected %d)", result, expected)
end

-- Test 5: Auto width with hidden viewer should use manual width
function test_auto_width_hidden_viewer()
    local viewer = mockViewer:new(500)
    viewer.shown = false
    local settings = {
        autoWidth = true,
        width = 250
    }
    
    local result = testResourceBarWidthCalculation(settings, viewer)
    local expected = 250
    
    local success = result == expected
    return success, string.format("Auto width with hidden viewer should use manual width (got %d, expected %d)", result, expected)
end

-- Run tests
print("\n✓ Testing resource bar width calculation...")

local test1_result, test1_desc = test_auto_width_with_viewer()
print(string.format("  %s %s", test1_result and "✓" or "✗", test1_desc))
testResults[#testResults + 1] = test1_result

local test2_result, test2_desc = test_manual_width()
print(string.format("  %s %s", test2_result and "✓" or "✗", test2_desc))
testResults[#testResults + 1] = test2_result

local test3_result, test3_desc = test_auto_width_no_viewer()
print(string.format("  %s %s", test3_result and "✓" or "✗", test3_desc))
testResults[#testResults + 1] = test3_result

local test4_result, test4_desc = test_default_width()
print(string.format("  %s %s", test4_result and "✓" or "✗", test4_desc))
testResults[#testResults + 1] = test4_result

local test5_result, test5_desc = test_auto_width_hidden_viewer()
print(string.format("  %s %s", test5_result and "✓" or "✗", test5_desc))
testResults[#testResults + 1] = test5_result

-- Summary
local passed = 0
for _, result in ipairs(testResults) do
    if result then passed = passed + 1 end
end

print(string.format("\n=== Results: %d/%d tests passed ===", passed, #testResults))

if passed == #testResults then
    print("✓ All resource bar auto width tests passed!")
    os.exit(0)
else
    print("✗ Some tests failed!")
    os.exit(1)
end
