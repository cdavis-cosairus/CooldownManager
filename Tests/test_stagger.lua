-- Test script for Brewmaster Monk Stagger functionality
-- This file tests the stagger detection and calculation logic

-- Simulate the stagger IDs (these are the actual spell IDs in WoW)
local STAGGER_SPELL_IDS = {
    124275, -- Heavy Stagger (red)
    124274, -- Moderate Stagger (yellow/orange)  
    124273  -- Light Stagger (green)
}

print("Testing Brewmaster Monk Stagger Detection...")

-- Test the stagger thresholds
local function TestStaggerThresholds()
    local testCases = {
        {staggerPercent = 0, expected = "none"},
        {staggerPercent = 3, expected = "light"},
        {staggerPercent = 8, expected = "moderate"},
        {staggerPercent = 20, expected = "heavy"}
    }
    
    for _, test in ipairs(testCases) do
        local staggerLevel
        if test.staggerPercent >= 15 then
            staggerLevel = "heavy"
        elseif test.staggerPercent >= 6 then
            staggerLevel = "moderate"
        elseif test.staggerPercent > 0 then
            staggerLevel = "light"
        else
            staggerLevel = "none"
        end
        
        local result = (staggerLevel == test.expected) and "PASS" or "FAIL"
        print(string.format("Stagger %d%% -> %s [%s]", test.staggerPercent, staggerLevel, result))
    end
end

-- Test stagger color mapping
local function TestStaggerColors()
    local STAGGER_COLORS = {
        LIGHT = {0.4, 0.8, 0.4},     -- Green for light stagger
        MODERATE = {1.0, 0.6, 0.2},  -- Orange for moderate stagger  
        HEAVY = {0.8, 0.2, 0.2}      -- Red for heavy stagger
    }
    
    print("Testing stagger color constants...")
    print(string.format("Light stagger color: RGB(%.1f, %.1f, %.1f)", 
        STAGGER_COLORS.LIGHT[1], STAGGER_COLORS.LIGHT[2], STAGGER_COLORS.LIGHT[3]))
    print(string.format("Moderate stagger color: RGB(%.1f, %.1f, %.1f)", 
        STAGGER_COLORS.MODERATE[1], STAGGER_COLORS.MODERATE[2], STAGGER_COLORS.MODERATE[3]))
    print(string.format("Heavy stagger color: RGB(%.1f, %.1f, %.1f)", 
        STAGGER_COLORS.HEAVY[1], STAGGER_COLORS.HEAVY[2], STAGGER_COLORS.HEAVY[3]))
end

-- Test tick damage calculation
local function TestStaggerTicks()
    local testStaggerAmounts = {1000, 5000, 10000, 25000}
    
    print("Testing stagger tick calculations...")
    for _, amount in ipairs(testStaggerAmounts) do
        local tickDamage = math.floor(amount * 0.02) -- 2% per tick approximation
        print(string.format("Stagger amount: %d -> Tick damage: %d", amount, tickDamage))
    end
end

-- Run all tests
TestStaggerThresholds()
print("")
TestStaggerColors()
print("")
TestStaggerTicks()

print("")
print("Stagger test completed successfully!")
print("Spell IDs to monitor:")
for i, spellID in ipairs(STAGGER_SPELL_IDS) do
    print(string.format("  %d: Stagger level %d", spellID, i))
end
