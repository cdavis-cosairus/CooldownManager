-- Performance Optimization Module for CooldownManager
-- Caches frequently accessed values to reduce API calls

local CooldownManager = CooldownManager or {}
CooldownManager.PerformanceCache = {}

-- Cache variables
local powerCache = {}
local childrenCache = {}
local classSpecCache = {}
local colorCache = {}
local lastCacheUpdate = 0
local CACHE_DURATION = 0.1 -- Cache for 100ms

-- Player info cache
local playerClass, playerClassFile = UnitClass("player")
local lastSpecialization = GetSpecialization()

-- Clear caches when needed
local function ClearPerformanceCache()
    wipe(powerCache)
    wipe(childrenCache)
    wipe(classSpecCache)
    wipe(colorCache)
    lastCacheUpdate = 0
end

-- Cached power values
function CooldownManager.PerformanceCache.GetCachedPower(unit, powerType)
    local now = GetTime()
    if now - lastCacheUpdate > CACHE_DURATION then
        wipe(powerCache)
        lastCacheUpdate = now
    end
    
    local key = (unit or "player") .. "_" .. (powerType or "primary")
    if not powerCache[key] then
        if powerType then
            powerCache[key] = {
                current = UnitPower(unit, powerType),
                max = UnitPowerMax(unit, powerType)
            }
        else
            powerCache[key] = {
                current = UnitPower(unit),
                max = UnitPowerMax(unit),
                type = UnitPowerType(unit)
            }
        end
    end
    return powerCache[key]
end

-- Cached children list
function CooldownManager.PerformanceCache.GetCachedChildren(frame)
    if not frame then return {} end
    
    local frameId = tostring(frame)
    local now = GetTime()
    
    if not childrenCache[frameId] or (now - (childrenCache[frameId].lastUpdate or 0)) > CACHE_DURATION then
        childrenCache[frameId] = {
            children = { frame:GetChildren() },
            lastUpdate = now
        }
    end
    
    return childrenCache[frameId].children
end

-- Cached class and specialization
function CooldownManager.PerformanceCache.GetCachedClassSpec()
    local now = GetTime()
    if not classSpecCache.lastUpdate or (now - classSpecCache.lastUpdate) > 1.0 then -- Cache for 1 second
        classSpecCache = {
            class = playerClass,
            classFile = playerClassFile,
            spec = GetSpecialization(),
            lastUpdate = now
        }
    end
    return classSpecCache.class, classSpecCache.classFile, classSpecCache.spec
end

-- Cached color palette
function CooldownManager.PerformanceCache.GetCachedColors()
    if not colorCache.colors then
        colorCache.colors = {
            combo_points = CooldownManager.CONSTANTS.COLORS.COMBO_POINTS,
            chi = CooldownManager.CONSTANTS.COLORS.CHI,
            inactive = {0.3, 0.3, 0.3},
            chi_inactive = {0.2, 0.4, 0.2}
        }
    end
    return colorCache.colors
end

-- Events to clear cache
local cacheFrame = CreateFrame("Frame")
cacheFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
cacheFrame:RegisterEvent("PLAYER_LOGIN")
cacheFrame:RegisterEvent("UNIT_POWER_UPDATE")
cacheFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LOGIN" then
        ClearPerformanceCache()
        playerClass, playerClassFile = UnitClass("player")
        lastSpecialization = GetSpecialization()
    elseif event == "UNIT_POWER_UPDATE" then
        -- Only clear power cache, keep others
        wipe(powerCache)
    end
end)

-- Export functions
CooldownManager.PerformanceCache.ClearCache = ClearPerformanceCache

return CooldownManager.PerformanceCache
