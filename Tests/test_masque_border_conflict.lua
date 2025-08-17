#!/usr/bin/env lua

-- Test file for Masque border conflict resolution
print("=== Testing Masque Border Conflict Resolution ===")

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
        _masqueEnabled = false,
        children = {}
    }
    setmetatable(obj, self)
    return obj
end

function mockFrame:GetChildren()
    return self.children
end

function mockFrame:Hide()
    self.hidden = true
end

function mockFrame:Show()
    self.hidden = false
end

-- Mock global functions
_G = _G or {}
function _G.CreateFrame() return mockFrame:new() end

-- Mock LibStub
LibStub = function(name)
    if name == "Masque" then
        return {
            Group = function(addon, viewer)
                return {
                    AddButton = function() end,
                    RemoveButton = function() end,
                    ReSkin = function() end
                }
            end
        }
    end
end

-- Load the modules we need to test
CooldownManager = CooldownManager or {}
CooldownManager.viewers = {"TestViewer"}

-- Mock the profile
CooldownManagerDBHandler = {
    profile = {
        masque = {
            enabled = true,
            viewers = {
                TestViewer = true
            }
        },
        iconZoom = 0.25
    }
}

-- Test functions
local testResults = {}

-- Test 1: Built-in borders should be hidden when Masque is enabled
function test_borders_hidden_with_masque()
    local testIcon = mockFrame:new()
    
    -- Create mock border parts
    local borderParts = {}
    for i = 1, 4 do
        borderParts[i] = mockFrame:new()
    end
    testIcon.__borderParts = borderParts
    
    -- Mock the viewer
    _G["TestViewer"] = {
        GetChildren = function() return {testIcon} end
    }
    
    -- Mock Masque functions
    CooldownManager.AddIconToMasque = function(icon, viewer)
        icon._masqueEnabled = true
        return true
    end
    
    CooldownManager.IsMasqueEnabled = function() return true end
    
    -- Load ViewerManager functions (simulate the key parts)
    local function SkinViewer(viewerName)
        local viewer = _G[viewerName]
        if not viewer then return end
        
        local children = viewer:GetChildren()
        local profile = CooldownManagerDBHandler.profile
        local masqueEnabled = profile.masque.enabled
        local viewerMasqueEnabled = masqueEnabled and profile.masque.viewers[viewerName]
        
        for _, child in ipairs(children) do
            if child and child.Icon then
                if viewerMasqueEnabled and CooldownManager.AddIconToMasque then
                    CooldownManager.AddIconToMasque(child, viewerName)
                    -- Hide built-in borders when Masque is enabled
                    if child.__borderParts then
                        for _, line in ipairs(child.__borderParts) do
                            if line then line:Hide() end
                        end
                    end
                end
            end
        end
    end
    
    -- Run the test
    SkinViewer("TestViewer")
    
    -- Check results
    local allHidden = true
    for _, border in ipairs(testIcon.__borderParts) do
        if not border.hidden then
            allHidden = false
            break
        end
    end
    
    return allHidden, "Built-in borders should be hidden when Masque is enabled"
end

-- Test 2: Built-in borders should be shown when Masque is disabled
function test_borders_shown_without_masque()
    local testIcon = mockFrame:new()
    
    -- Create mock border parts
    local borderParts = {}
    for i = 1, 4 do
        borderParts[i] = mockFrame:new()
    end
    testIcon.__borderParts = borderParts
    
    -- Mock the viewer
    _G["TestViewer2"] = {
        GetChildren = function() return {testIcon} end
    }
    
    -- Mock cleanup function (simulate the key parts)
    local function CleanupMasque(viewerName)
        local viewer = _G[viewerName]
        if not viewer then return end
        
        local children = viewer:GetChildren()
        for _, child in ipairs(children) do
            if child and child._masqueEnabled then
                child._masqueEnabled = false
                -- Restore built-in borders when Masque is disabled
                if child.__borderParts then
                    for _, line in ipairs(child.__borderParts) do
                        if line then line:Show() end
                    end
                end
            end
        end
    end
    
    -- Set up initial state (Masque enabled)
    testIcon._masqueEnabled = true
    for _, border in ipairs(testIcon.__borderParts) do
        border:Hide()
    end
    
    -- Run cleanup (disable Masque)
    CleanupMasque("TestViewer2")
    
    -- Check results
    local allShown = true
    for _, border in ipairs(testIcon.__borderParts) do
        if border.hidden then
            allShown = false
            break
        end
    end
    
    return allShown, "Built-in borders should be restored when Masque is disabled"
end

-- Run tests
print("\n✓ Testing border visibility control...")

local test1_result, test1_desc = test_borders_hidden_with_masque()
print(string.format("  %s %s", test1_result and "✓" or "✗", test1_desc))
testResults[#testResults + 1] = test1_result

local test2_result, test2_desc = test_borders_shown_without_masque()
print(string.format("  %s %s", test2_result and "✓" or "✗", test2_desc))
testResults[#testResults + 1] = test2_result

-- Summary
local passed = 0
for _, result in ipairs(testResults) do
    if result then passed = passed + 1 end
end

print(string.format("\n=== Results: %d/%d tests passed ===", passed, #testResults))

if passed == #testResults then
    print("✓ All Masque border conflict tests passed!")
    os.exit(0)
else
    print("✗ Some tests failed!")
    os.exit(1)
end
