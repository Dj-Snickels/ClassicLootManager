local _, CLM = ...
local LOG = CLM.LOG
CLM.UTILS = {}

local UTILS = CLM.UTILS
local CONSTANTS = CLM.CONSTANTS

local DumpTable = LibStub("EventSourcing/Util").DumpTable

local function capitalize(string)
    string = string or ""
    return string:sub(1,1):upper()..string:sub(2):lower()
end

local classOrdered = {
    "druid", "hunter", "mage", "priest", "rogue", "shaman", "paladin", "warlock", "warrior"
}

local classColors = {
    ["druid"]   = { r = 1,    g = 0.49, b = 0.04, hex = "FF7D0A" },
    ["hunter"]  = { r = 0.67, g = 0.83, b = 0.45, hex = "ABD473" },
    ["mage"]    = { r = 0.25, g = 0.78, b = 0.92, hex = "40C7EB" },
    ["priest"]  = { r = 1,    g = 1,    b = 1,    hex = "FFFFFF" },
    ["rogue"]   = { r = 1,    g = 0.96, b = 0.41, hex = "FFF569" },
    ["shaman"]  = { r = 0.01, g = 0.44, b = 0.87, hex = "0270DD" },
    ["paladin"] = { r = 0.96, g = 0.55, b = 0.73, hex = "F58CBA" },
    ["warlock"] = { r = 0.53, g = 0.53, b = 0.93, hex = "8787ED" },
    ["warrior"] = { r = 0.78, g = 0.61, b = 0.43, hex = "C79C6E" }
}

function UTILS.GetClassColor(className)
    local color = classColors[string.lower(className)]
    return (color or { r = 0.627, g = 0.627, b = 0.627, hex = "A0A0A0" })
end

function UTILS.ColorCodeText(text, color)
    return string.format("|cff%s%s|r", color, text);
end

function UTILS.ColorCodeClass(className)
    return UTILS.ColorCodeText(className, UTILS.GetClassColor(className).hex);
end

local colorCodedClassList = {}
do
    for _,class in pairs(classOrdered) do
        table.insert(colorCodedClassList, UTILS.ColorCodeClass(capitalize(class)))
    end
end
function UTILS.GetColorCodedClassDict()
    return colorCodedClassList
end

function UTILS.UniversalCliMethodExecutor(name, object, cli)
    local values = {strsplit(" ", cli)}
    local method, args, parameters = values[1], {}, ""
    for i=2,#values do
        args[i - 1] = values[i]
        parameters = parameters .. tostring(values[i]) ..  ", "
    end

    if type(object[method]) == "function" then
        LOG:Info("Execute [%s(%s(%s)]", name, method, parameters)
        object[method](object, unpack(args))
    else
        print("Available methods:")
        for methodName,ref in pairs(object) do
            if type(ref) == "function" then
                print(methodName)
            end
        end
    end
end

local StorageQualifiedObject = {}
function StorageQualifiedObject:New(storage)
    local o = {}

    setmetatable(o, self)
    self.__index = self

    -- Virtual profile that is not stored
    -- It's not a bug. It's a feature.
    if storage == nil then
        LOG:Warning("Virtual storage qualified object. Is this intended?")
        local s = {}
        o.persistent = s
    else
        o.persistent = storage
    end

    o.volatile = {}

    return o
end

function UTILS.NewStorageQualifiedObject(storage, o)
    local sqo = StorageQualifiedObject:New(storage)
    o = o or {}
    setmetatable(sqo, o)
    o.__index = o
    return sqo
end

function UTILS.GenerateItemLink(itemId)
    return string.format("item:%d:0:0:0:0:0:0:0:0:0:0:0:0", itemId)
end

function UTILS.Set(t)
    local s = {}
    for _,v in pairs(t) do s[v] = true end
    return s
end

-- http://lua-users.org/wiki/CopyTable
function UTILS.ShallowCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- http://lua-users.org/wiki/CopyTable
function UTILS.DeepCopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[UTILS.DeepCopy(orig_key, copies)] = UTILS.DeepCopy(orig_value, copies)
            end
            setmetatable(copy, UTILS.DeepCopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function UTILS.RemoveServer(name)
    name, _ = strsplit("-", name)
    return name
end

function UTILS.GetUnitName(unit)
    local name = GetUnitName(unit)
    return UTILS.RemoveServer(name)
end

function UTILS.typeof(object, objectType)
    if not object or not objectType then
        return false
    end
    if type(object) ~= "table" then
        return false
    end
    local mo = getmetatable(object)
    if not mo then
        return false
    end
    return (mo == objectType)
end
local typeof = UTILS.typeof

function UTILS.empty(object)
    if object == "" or object == nil then
        return true
    end
    return false
end

function UTILS.getIntegerGuid(GUID)
    return tonumber(string.sub(GUID, -8), 16)
end
local getIntegerGuid = UTILS.getIntegerGuid

local GUIDPrefix = string.sub(UnitGUID("player"), 1, -9)
function UTILS.getGuidFromInteger(int)
    return GUIDPrefix .. string.format("%08X", int)
end

function UTILS.DumpTable(t)
    return DumpTable(t)
end

local playerName = UTILS.GetUnitName("player")
function UTILS.WhoAmI()
    return playerName
end

function UTILS.GetGUIDFromEntry(e)
    if typeof(e, CLM.MODELS.Profile) then
        return getIntegerGuid(e:GUID())
    elseif type(e) == "number" then
        return e
    elseif type(e) == "string" then
        return getIntegerGuid(e)
    else
        return nil
    end
end
local GetGUIDFromEntry = UTILS.GetGUIDFromEntry

function UTILS.CreateGUIDList(playerList)
    local playerGUIDList = {}
    local GUID
    -- We expect list of either: GUID in string/integer form or profile
    -- List is expected always
    for _, p in ipairs(playerList) do
        GUID = GetGUIDFromEntry(p)
        if GUID ~= nil then
            table.insert(playerGUIDList, GUID)
        end
    end
    return playerGUIDList
end


function UTILS.inflate(object, data)
    for i, key in ipairs(object:fields(data.v)) do
        object[key] = data[i]
    end
end

function UTILS.deflate(object, version)
    local result = {}
    for _, key in ipairs(object:fields(version)) do
        table.insert(result, object[key])
    end
    result.v = version
    return result
end

function UTILS.keys(object)
    local keyList = {}
    local n = 0

    for k,_ in pairs(object) do
      n = n + 1
      keyList[n] = k
    end
    return keyList
end

function UTILS.method2function(handler, method)
    return (function(...) handler[method](handler, ...) end)
end

function UTILS.mergeLists(t1, t2, t)
    t = t or {}
    local n = 0
    for _,v in ipairs(t1) do n = n+1; t[n] = v end
    for _,v in ipairs(t2) do n = n+1; t[n] = v end
    return t
end

function UTILS.mergeDicts(t1, t2, t)
    t = t or {}
    for k,v in pairs(t1) do t[k] = v end
    for k,v in pairs(t2) do t[k] = v end
    return t
end

function UTILS.mergeDictsInline(t, s)
    for k,v in pairs(s) do t[k] = v end
end

local classToNumber = {
    ["WARRIOR"] = 1,
    ["PALADIN"] = 2,
    ["HUNTER"] = 3,
    ["ROGUE"] = 4,
    ["PRIEST"] = 5,
    ["DEATHKNIGHT"] = 6,
    ["SHAMAN"] = 7,
    ["MAGE"] = 8,
    ["WARLOCK"] = 9,
    ["MONK"] = 10,
    ["DRUID"] = 11,
    ["DEMONHUNTER"] = 12
}
function UTILS.ClassToNumber(class)
    return classToNumber[(class or ""):upper()] or 0
end

local numberToClass = {
    [1]  = "WARRIOR",
    [2]  = "PALADIN",
    [3]  = "HUNTER",
    [4]  = "ROGUE",
    [5]  = "PRIEST",
    -- [6]  = "DEATHKNIGHT",
    [7]  = "SHAMAN",
    [8]  = "MAGE",
    [9]  = "WARLOCK",
    -- [10] = "MONK",
    [11] = "DRUID",
    -- [12] = "DEMONHUNTER"
}
function UTILS.NumberToClass(number)
    return (numberToClass[number] or ""):upper()
end

function UTILS.capitalize(string)
    return capitalize(string)
end

function UTILS.stringifyList(list)
    if not list then return "" end
    local string = ""
    for _,v in ipairs(list) do
        string = string .. tostring(v) .. ", "
    end
    return string:sub(1, -3)
end

function UTILS.stringifyDict(dict)
    if not dict then return "" end
    local string = ""
    for k,v in pairs(dict) do
        string = string .. tostring(k) .. ": " .. tostring(v) .. ", "
    end
    return string:sub(1, -3)
end

function UTILS.MakeFrameCloseOnEsc(frame, name)
    _G[name] = frame
    tinsert(UISpecialFrames, name)
end

CONSTANTS.REGEXP_FLOAT = "^-?%d+.?%d*$"
CONSTANTS.REGEXP_FLOAT_POSITIVE = "^%d+.?%d*$"