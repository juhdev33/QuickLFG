--[[
PlayerInfo struct
{
    areaName?: string,
    assignedRole: string,
    classFilename: string, -- non localized class name?
    className: string, -- localized class name?
    isleader: boolean,
    isLeaver?: boolean,
    level?: number,
    lfgRoles: LFGRoles,
    name?: string,
    specName?: string
}
]]

FilterExpansion = {}

FilterExpansion.expansions = {
    ["warrior"] = {
        ["Class"] = "Warrior"
    },
    ["paladin"] = {
        ["Class"] = "Paladin"
    },
    ["hunter"] = {
        ["Class"] = "Hunter"
    },
    ["rogue"] = {
        ["Class"] = "Rogue"
    },
    ["priest"] = {
        ["Class"] = "Priest"
    },
    ["shaman"] = {
        ["Class"] = "Shaman"
    },
    ["mage"] = {
        ["Class"] = "Mage"
    },
    ["warlock"] = {
        ["Class"] = "Warlock"
    },
    ["druid"] = {
        ["Class"] = "Druid"
    },

    ["tanker"] = {
        ["Class"] = {"Warrior", "Paladin", "Druid"},
        ["Role"] = "tank"
    },
    ["healer"] = {
        ["Class"] = {"Priest", "Shaman", "Druid", "Paladin"},
        ["Role"] = "healer"
    },
    ["dps"] = {
        ["Role"] = "dps"
    },
    ["damager"] = {
        ["Role"] = "dps"
    },

    ["spriest"] = {
        ["Class"] = "Priest",
        ["Role"] = "dps"
    },
    ["shadow"] = {
        ["Class"] = "Priest",
        ["Role"] = "dps"
    },    
    ["hpriest"] = {
        ["Class"] = "Priest",
        ["Role"] = "healer"
    },
    ["rshaman"] = {
        ["Class"] = "Shaman",
        ["Role"] = "healer"
    },
    ["elemental"] = {
        ["Class"] = "Shaman",
        ["Role"] = "dps"
    },
    ["enhancement"] = {
        ["Class"] = "Shaman",
        ["Role"] = "dps"
    },
    ["restoration"] = {
        ["Class"] = {"Shaman", "Druid"},
        ["Role"] = "healer"
    },
    ["feral"] = {
        ["Class"] = "Druid",
        ["Role"] = {"dps", "tank"}
    },
    ["balance"] = {
        ["Class"] = "Druid",
        ["Role"] = "dps"
    },
    ["holy"] = {
        ["Class"] = {"Paladin", "Priest"},
        ["Role"] = "healer"
    },
    ["protection"] = {
        ["Class"] = {"Paladin", "Warrior"},
        ["Role"] = "tank"
    },
    ["retribution"] = {
        ["Class"] = "Paladin",
        ["Role"] = "dps"
    },

    ["lock"] = {
        ["Class"] = "Warlock"
    },
}

local terms = {}

local function ToLowerList(value)
    if not value then
        return nil
    end
    if type(value) ~= "table" then
        return { strlower(value) }
    end
    local list = {}
    for i = 1, #value do
        list[i] = strlower(value[i])
    end
    return list
end

for key, expansion in pairs(FilterExpansion.expansions) do
    local classList = ToLowerList(expansion.Class)
    local roleList = ToLowerList(expansion.Role)
    terms[#terms + 1] = {
        key = strlower(key),
        minLength = (classList and not roleList) and 1 or 2,
        Class = classList,
        Role = roleList,
    }
end

local function MatchesClass(term, playerInfo)
    if not term.Class then
        return true
    end

    local className = playerInfo.classFilename and strlower(playerInfo.classFilename)
    if not className then
        return false
    end

    for i = 1, #term.Class do
        if className == term.Class[i] then
            return true
        end
    end
    return false
end

local function MatchesRole(term, playerInfo)
    if not term.Role then
        return true
    end

    local roles = playerInfo.lfgRoles
    if not roles then
        return false
    end

    for i = 1, #term.Role do
        if roles[term.Role[i]] then
            return true
        end
    end
    return false
end

-- token is each separated user input. ex: hpriest
-- terms is a built list of all possible expansions text keys. match if the key starts with the token (+rules)
function FilterExpansion:Filter(token, playerInfo)
    if not token or token == "" or not playerInfo then
        return false
    end

    local tokenLen = #token
    for i = 1, #terms do
        local term = terms[i]
        if tokenLen >= term.minLength and strsub(term.key, 1, tokenLen) == token then
            if MatchesClass(term, playerInfo) and MatchesRole(term, playerInfo) then
                return true
            end
        end
    end
    return false
end
