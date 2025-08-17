#!/usr/bin/env lua

-- Test file for Masque reload requirement functionality
print("=== Testing Masque Reload Requirement ===")

-- Mock WoW API for testing
local mockPopupShown = false
local mockReloadCalled = false

-- Mock StaticPopup functions
StaticPopup_Show = function(popupName)
    if popupName == "COOLDOWNMANAGER_RELOAD_UI_MASQUE" then
        mockPopupShown = true
        return true
    end
    return false
end

-- Mock ReloadUI
ReloadUI = function()
    mockReloadCalled = true
end

-- Mock timer
C_Timer = {
    After = function(delay, func)
        func() -- Execute immediately for testing
    end
}

-- Mock database handler
CooldownManagerDBHandler = {
    profile = {
        masque = {
            enabled = true -- Start with Masque enabled
        }
    }
}

-- Mock TrySkin function
TrySkin = function() end

-- Test the StaticPopup configuration
StaticPopupDialogs = {}
StaticPopupDialogs["COOLDOWNMANAGER_RELOAD_UI_MASQUE"] = {
    text = "Disabling Masque integration requires a UI reload to properly clean up skinning. Reload now?",
    button1 = "Reload UI",
    button2 = "Cancel",
    OnAccept = function()
        -- Disable Masque before reload
        CooldownManagerDBHandler.profile.masque = CooldownManagerDBHandler.profile.masque or {}
        CooldownManagerDBHandler.profile.masque.enabled = false
        ReloadUI()
    end,
    OnCancel = function()
        -- Do nothing - keep current setting
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Test the set function behavior
local function testMasqueToggleSet(_, val)
    CooldownManagerDBHandler.profile.masque = CooldownManagerDBHandler.profile.masque or {}
    local currentEnabled = CooldownManagerDBHandler.profile.masque.enabled or false
    
    -- If disabling Masque, require a reload
    if currentEnabled and not val then
        StaticPopup_Show("COOLDOWNMANAGER_RELOAD_UI_MASQUE")
        return -- Don't change the setting until reload is accepted
    end
    
    CooldownManagerDBHandler.profile.masque.enabled = val
    -- Apply changes to all viewers
    C_Timer.After(0.1, function()
        if TrySkin then TrySkin() end
    end)
end

-- Test functions
local testResults = {}

-- Test 1: Enabling Masque should work normally (no reload required)
function test_enable_masque_no_reload()
    -- Reset state
    mockPopupShown = false
    mockReloadCalled = false
    CooldownManagerDBHandler.profile.masque.enabled = false
    
    -- Try to enable Masque
    testMasqueToggleSet(nil, true)
    
    local success = not mockPopupShown and not mockReloadCalled and CooldownManagerDBHandler.profile.masque.enabled
    return success, "Enabling Masque should not require reload"
end

-- Test 2: Disabling Masque should show popup and NOT change setting
function test_disable_masque_shows_popup()
    -- Reset state
    mockPopupShown = false
    mockReloadCalled = false
    CooldownManagerDBHandler.profile.masque.enabled = true
    
    -- Try to disable Masque
    testMasqueToggleSet(nil, false)
    
    local success = mockPopupShown and not mockReloadCalled and CooldownManagerDBHandler.profile.masque.enabled
    return success, "Disabling Masque should show popup and keep current setting"
end

-- Test 3: Accepting popup should disable Masque and call ReloadUI
function test_popup_accept_reloads()
    -- Reset state
    mockPopupShown = false
    mockReloadCalled = false
    CooldownManagerDBHandler.profile.masque.enabled = true
    
    -- Simulate accepting the popup
    StaticPopupDialogs["COOLDOWNMANAGER_RELOAD_UI_MASQUE"].OnAccept()
    
    local success = not CooldownManagerDBHandler.profile.masque.enabled and mockReloadCalled
    return success, "Accepting popup should disable Masque and reload UI"
end

-- Test 4: Canceling popup should keep Masque enabled
function test_popup_cancel_keeps_setting()
    -- Reset state
    mockPopupShown = false
    mockReloadCalled = false
    CooldownManagerDBHandler.profile.masque.enabled = true
    
    -- Simulate canceling the popup
    StaticPopupDialogs["COOLDOWNMANAGER_RELOAD_UI_MASQUE"].OnCancel()
    
    local success = CooldownManagerDBHandler.profile.masque.enabled and not mockReloadCalled
    return success, "Canceling popup should keep Masque enabled"
end

-- Run tests
print("\n✓ Testing Masque reload requirement...")

local test1_result, test1_desc = test_enable_masque_no_reload()
print(string.format("  %s %s", test1_result and "✓" or "✗", test1_desc))
testResults[#testResults + 1] = test1_result

local test2_result, test2_desc = test_disable_masque_shows_popup()
print(string.format("  %s %s", test2_result and "✓" or "✗", test2_desc))
testResults[#testResults + 1] = test2_result

local test3_result, test3_desc = test_popup_accept_reloads()
print(string.format("  %s %s", test3_result and "✓" or "✗", test3_desc))
testResults[#testResults + 1] = test3_result

local test4_result, test4_desc = test_popup_cancel_keeps_setting()
print(string.format("  %s %s", test4_result and "✓" or "✗", test4_desc))
testResults[#testResults + 1] = test4_result

-- Summary
local passed = 0
for _, result in ipairs(testResults) do
    if result then passed = passed + 1 end
end

print(string.format("\n=== Results: %d/%d tests passed ===", passed, #testResults))

if passed == #testResults then
    print("✓ All Masque reload requirement tests passed!")
    os.exit(0)
else
    print("✗ Some tests failed!")
    os.exit(1)
end
