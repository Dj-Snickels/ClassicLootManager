local  _, CLM = ...

local LOG = CLM.LOG

local MODULES =  CLM.MODULES
local CONSTANTS = CLM.CONSTANTS
local UTILS = CLM.UTILS
local MODELS =  CLM.MODELS
local ACL_LEVEL = CONSTANTS.ACL.LEVEL

local LedgerManager = MODULES.LedgerManager
local RosterManager = MODULES.RosterManager
local ProfileManager = MODULES.ProfileManager

local LEDGER_LOOT = MODELS.LEDGER.LOOT
local Profile = MODELS.Profile
local Roster = MODELS.Roster
local Loot = MODELS.Loot

local typeof = UTILS.typeof
local getGuidFromInteger = UTILS.getGuidFromInteger

local LootManager = {}
function LootManager:Initialize()
    LOG:Trace("LootManager:Initialize()")
    LedgerManager:RegisterEntryType(
        LEDGER_LOOT.Award,
        (function(entry)
            LOG:TraceAndCount("mutator(LOOTAward)")
            local roster = RosterManager:GetRosterByUid(entry:rosterUid())
            if roster == nil then
                LOG:Warning("PointManager mutator(): Unknown roster uid %s", entry:rosterUid())
                return
            end
            local GUID = getGuidFromInteger(entry:profile())
            if roster:IsProfileInRoster(GUID) then
                local profile = ProfileManager:GetProfileByGUID(GUID)
                if profile == nil then
                    LOG:Warning("PointManager mutator(): Profile with guid [%s] does not exist", GUID)
                    return
                end
                RosterManager:AddLootToRoster(roster, Loot:New(entry), profile)
            else
                -- TODO: Add  Profile to roster? Store in anonymous profile?
                LOG:Warning("PointManager mutator(): Unknown profile guid [%s] in roster [%s]", GUID, entry:rosterUid())
                return
            end
        end),
        ACL_LEVEL.MANAGER)

        MODULES.ConfigManager:RegisterUniversalExecutor("lm", "LootManager", self)
end

function LootManager:AwardItem(roster, profile, itemId, value, forceInstant)
    LOG:Trace("LootManager:AwardItem()")
    if not typeof(roster, Roster) then
        LOG:Error("LootManager:AwardItem(): Missing valid roster")
        return
    end
    if not typeof(profile, Profile) then
        LOG:Error("LootManager:AwardItem(): Missing valid profile")
        return
    end
    if type(itemId) ~= "number" then
        LOG:Error("LootManager:AwardItem(): Invalid ItemId")
        return
    end
    if type(value) ~= "number" then
        LOG:Error("LootManager:AwardItem(): Invalid Value")
        return
    end
    if roster:IsProfileInRoster(profile:GUID()) then
        LedgerManager:Submit(LEDGER_LOOT.Award:new(roster:UID(), profile, itemId, value), forceInstant)
    else
        LOG:Warning("LootManager:AwardItem(): Unknown profile guid [%s] in roster [%s]", profile:GUID(), roster:UID())
    end
end

function LootManager:RevokeItem(loot, forceInstant)
    LOG:Trace("LootManager:RevokeItem()")
    if not typeof(loot, Loot) then
        LOG:Error("LootManager:RevokeItem(): Missing valid loot")
        return
    end
    -- TODO: Add entry to track who removed?
    LedgerManager:Remove(loot:Entry(), forceInstant)
end

function LootManager:TransferItem(roster, profile, loot, forceInstant)
    LOG:Trace("LootManager:TransferItem()")
    if not typeof(roster, Roster) then
        LOG:Error("LootManager:TransferItem(): Missing valid roster")
        return
    end
    if not typeof(profile, Profile) then
        LOG:Error("LootManager:TransferItem(): Missing valid target profile")
        return
    end
    if not typeof(loot, Loot) then
        LOG:Error("LootManager:TransferItem(): Missing valid loot")
        return
    end
    if roster:IsProfileInRoster(profile:GUID()) then
        LedgerManager:Submit(LEDGER_LOOT.Award:new(roster:UID(), profile, loot:Id(), loot:Value()), forceInstant)
        LedgerManager:Remove(loot:Entry(), forceInstant)
    else
        LOG:Warning("LootManager:TransferItem(): Unknown profile guid [%s] in roster [%s]", profile:GUID(), roster:UID())
    end
end

function LootManager:Debug(N)
    N = N or 10
    local rosters = RosterManager:GetRosters()
    local numRosters = 0
    local rosterLookup = {}
    local numProfiles = {}
    local profileLookup = {}
    for name, roster in pairs(rosters) do
        print(tostring(name))
        local standings = roster:Standings()
        numProfiles[name] = 0
        profileLookup[name] = {}
        for GUID,_ in pairs(standings) do
            numProfiles[name] = numProfiles[name] + 1
            table.insert(profileLookup[name], GUID)
        end
        if numProfiles[name] > 0 then
            numRosters = numRosters + 1
            table.insert(rosterLookup, name)
        end
    end

    print("Detected " .. tonumber(numRosters) .. " rosters with profiles")
    for name, value in pairs(numProfiles) do
        print("  " .. name .. ": " .. tostring(value) .. " profiles")
    end

    if numRosters == 0 then
        return
    end

    print("Generating total of  " .. N .. " entries")

    for iteration=1,N do
        local selectedRoster = rosterLookup[math.random(1, numRosters)]
        local roster = rosters[selectedRoster]
        if roster == nil then
            print("=== Wrong roster selection ===")
        else
            local profile = ProfileManager:GetProfileByGUID(profileLookup[selectedRoster][math.random(1, numProfiles[selectedRoster])])
            if profile == nil then
                print("=== Wrong profile selection ===")
            else
                local profileLoot = roster:GetProfileLootByGUID(profile:GUID())
                local numLoot = #profileLoot
                local entryType
                if numLoot > 0 then
                    entryType = math.random(0, 2)
                else
                    entryType = 0 -- Award only
                end
                local itemId = math.random(1100, 23328)
                local value = math.random() * 1000
                -- while GetItemInfoInstant(itemId) == nil do
                    -- value = math.random(1100, 23328)
                -- end
                print(
                    "Generated entry: " .. tostring(iteration) ..
                    " of type " .. tostring(entryType) ..
                    " in roster " .. selectedRoster .. " " ..
                    " with id " .. tostring(itemId) .. " "..
                    " and value " .. tostring(value)
                )
                if entryType == 0 then -- Award
                    self:AwardItem(roster, profile, itemId, value, true)
                elseif entryType == 1 then -- Revoke
                    self:RevokeItem(profileLoot[math.random(1, numLoot)], true)
                elseif entryType == 2 then -- Transfer
                    local targetProfile = ProfileManager:GetProfileByGUID(profileLookup[selectedRoster][math.random(1, numProfiles[selectedRoster])])
                    while targetProfile == nil or (targetProfile:GUID() == profile:GUID()) do
                        targetProfile = ProfileManager:GetProfileByGUID(profileLookup[selectedRoster][math.random(1, numProfiles[selectedRoster])])
                    end
                    self:TransferItem(roster, targetProfile, profileLoot[math.random(1, numLoot)], true)
                end
            end
        end
    end
end

MODULES.LootManager = LootManager