Precognito = LibStub("AceAddon-3.0"):NewAddon("Precognito")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

local function getOption(info, value)
    if value then
        return Precognito.db.profile[info.arg][value]
    else
        return Precognito.db.profile[info.arg]
    end
end

local function setOption(info, value)
    Precognito.db.profile[info.arg] = value
end

Precognito.options = {
    type = "group",
    name = "Precognito",
    get = getOption,
    set = setOption,
    args = {
        version = {
            name = "|cff89CFF0Version:|r "..GetAddOnMetadata("Precognito", "Version").."\n",
            type = "description"
        },
        tab1 = {
            type = "group",
            name = "UnitFrame Settings",
            args = {
                animHealth = {
                    order = 1,
                    name = "Animate Health Loss",
                    desc = "Animates loss of health on the PlayerFrame",
                    type = "toggle",
                    arg = "animHealth",
                },
                animMana = {
                    order = 2,
                    name = "Animate Power cost",
                    desc = "Displays cost of spells when casting",
                    type = "toggle",
                    arg = "animMana",
                },
                Feedback = {
                    order = 3,
                    name = "Animate Full Power",
                    desc = "Animate the manaBar when you reach max power while in combat.",
                    type = "toggle",
                    arg = "FeedBack",
                },
            },
        },
    },
}

Precognito.defaults = {
    profile = {
        animHealth = true,
        animMana = true,
        FeedBack = true,
    },
}

function Precognito:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("PrecognitoDB", self.defaults, true)

    AceConfig:RegisterOptionsTable("Precognito", self.options)
    AceConfigDialog:AddToBlizOptions("Precognito", "Precognito")

    --[[ if self.db.profile.animHealth or self.db.profile.animMana or self.db.profile.FeedBack then
        self:UFInit()
    end ]]
end
