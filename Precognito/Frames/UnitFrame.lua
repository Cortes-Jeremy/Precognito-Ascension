---@class Precognito : AceAddon
---@field db AceDB-3.0
local Precognito = LibStub("AceAddon-3.0"):GetAddon("Precognito")
local UnitIsUnit, UnitGUID = UnitIsUnit, UnitGUID
local UnitHealth, UnitPower, UnitPowerType = UnitHealth, UnitPower, UnitPowerType
local min, max, pairs = math.min, math.max, pairs
local hooksecurefunc = hooksecurefunc
local GetSpellInfo = GetSpellInfo

------------------------------------------------------- Ascension

local function CastingInfo()
    -- name, rank, displayName, icon, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo("player")
    local name, _, _, _, startTime, endTime, _, _, _, spellID = UnitCastingInfo("player")
    if not name then
        -- name, rank, isChanneling, icon, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo("player")
        name, _, _, _, startTime, endTime, _, _, spellID = UnitChannelInfo("player")
    end
    if spellID == 0 then
        spellID = nil
    end
    return name, nil, nil, startTime, endTime, nil, nil, nil, spellID
end

local function GetSpellPowerCost(spellID)
    local costTable = {}
    local _, _, _, spellCost = GetSpellInfo(spellID)
    local powerType, powerToken = UnitPowerType("player")
    if spellCost and spellCost > 0 then
        local maxPower = UnitPowerMax("player", powerType)
        table.insert(costTable, {
            type = powerType,
            cost = spellCost,
            costPercent = maxPower > 0 and (spellCost / maxPower * 100) or 0
        })
    end

    return costTable
end

-------------------------------------------------------

local function UnitFrameUtil_UpdateFillBarBase_New(frame, realbar, previousTexture, bar, amount, barOffsetXPercent)
    if frame.unit ~= "player" then return previousTexture end

	if amount == 0 then
		bar:Hide()
		if bar.overlay then
			bar.overlay:Hide()
		end
		return previousTexture
	end

	local barOffsetX = 0
	if barOffsetXPercent then
		local realbarSizeX = realbar:GetWidth()
		barOffsetX = realbarSizeX * barOffsetXPercent
	end

	bar:SetPoint("TOPLEFT", previousTexture, "TOPRIGHT", barOffsetX, 0)
	bar:SetPoint("BOTTOMLEFT", previousTexture, "BOTTOMRIGHT", barOffsetX, 0)

	local totalWidth, totalHeight = realbar:GetSize()
	local _, totalMax = realbar:GetMinMaxValues()

	local barSize = (amount / totalMax) * totalWidth
	bar:SetWidth(barSize)
	bar:Show()
	if bar.overlay then
		bar.overlay:SetTexCoord(0, barSize / bar.overlay.tileSize, 0, totalHeight / bar.overlay.tileSize)
		bar.overlay:Show()
	end
	return bar
end

local function UnitFrameUtil_UpdateManaFillBar_New(frame, previousTexture, bar, amount, barOffsetXPercent)
	return UnitFrameUtil_UpdateFillBarBase_New(frame, frame.manabar, previousTexture, bar, amount, barOffsetXPercent)
end

-------------------------------------------------------

local function OnEnterCombat(self)
    if not self.manabar or not self.manabar.FullPowerFrame then return end

    local powerType = self.manabar.powerType
    local powerToken = self.manabar.powerToken or select(2, UnitPowerType("player"))
    local info = PowerBarColor[powerToken] or PowerBarColor[powerType]
    if not info then return end

    local curr = UnitPower("player", powerType)
    local max = UnitPowerMax("player", powerType)

    if curr == max then
        self.manabar.FullPowerFrame:StartAnimIfFull(curr)
    end
end

-------------------------------------------------------

local function UnitFrameManaBar_OnUpdate_New(self, unit)
	if not self.disconnected and not self.lockValues then

		local predictedCost = self:GetParent().predictedPowerCost
		local currValue = UnitPower(self.unit, self.powerType)

		if predictedCost then
			currValue = currValue - predictedCost
		end

		if currValue ~= self.currValue or self.forceUpdate then
			self.forceUpdate = nil
			if not self.ignoreNoUnit or UnitGUID(self.unit) then
				if self.FeedbackFrame and self.FeedbackFrame.maxValue then
					-- Only show anim if change is more than 10%
					local oldValue = self.currValue or 0
					if self.FeedbackFrame.maxValue ~= 0 and math.abs(currValue - oldValue) / self.FeedbackFrame.maxValue > 0.1 then
						self.FeedbackFrame:StartFeedbackAnim(oldValue, currValue)
					end
				end
				if self.FullPowerFrame and self.FullPowerFrame.active then
					self.FullPowerFrame:StartAnimIfFull(currValue)
				end
				self:SetValue(currValue)
				self.currValue = currValue
				TextStatusBar_UpdateTextString(self)
			end
		end
	end
end

local function UnitFrameManaBar_Update_New(statusbar, unit)
	if not statusbar or statusbar.lockValues then return end

	if unit == statusbar.unit then
		-- be sure to update the power type before grabbing the max power!
		UnitFrameManaBar_UpdateType_Hook(statusbar)

		local maxValue = UnitPowerMax(unit, statusbar.powerType)

        statusbar:SetMinMaxValues(0, maxValue)

        statusbar.disconnected = not UnitIsConnected(unit)
		if statusbar.disconnected then
			statusbar:SetValue(maxValue)
			statusbar.currValue = maxValue
			if not statusbar.lockColor then
				statusbar:SetStatusBarColor(0.5, 0.5, 0.5)
			end
		else
            local predictedCost = statusbar:GetParent().predictedPowerCost
            local currValue = UnitPower(unit, statusbar.powerType)
            if predictedCost then
                currValue = currValue - predictedCost
            end
            if statusbar.FullPowerFrame then
                statusbar.FullPowerFrame:SetMaxValue(maxValue)
            end

            -- statusbar:SetValue(currValue)
			-- statusbar.currValue = currValue
            statusbar.forceUpdate = true
        end
	end
    TextStatusBar_UpdateTextString(statusbar)
end

------------------------------------------------------- // Ascension

local function UnitFrameHealthBar_OnUpdate_New(self)
    if not self.disconnected and not self.lockValues then
        local currValue = UnitHealth(self.unit)
        local animatedLossBar = self.AnimatedLossBar

        if currValue ~= self.currValue then
            if not self.ignoreNoUnit or UnitGUID(self.unit) then

                if animatedLossBar then
                    animatedLossBar:UpdateHealth(currValue, self.currValue)
                end

                self:SetValue(currValue)
                self.currValue = currValue
                TextStatusBar_UpdateTextString(self)
                -- UnitFrameHealPredictionBars_Update(self.unitFrame)
            end
        end

        if animatedLossBar then
            animatedLossBar:UpdateLossAnimation(currValue)
        end
    end
end

function UnitFrameManaBar_UpdateType_Hook(manaBar)
    if not manaBar or manaBar.unit ~= "player" then return end

    local unitFrame = manaBar:GetParent()
    local powerType, powerToken = UnitPowerType(manaBar.unit)
    local info = PowerBarColor[powerToken]

    if info then
        if not manaBar.lockColor then
            if manaBar.FeedbackFrame then
				manaBar.FeedbackFrame:Initialize(info, manaBar.unit, powerType)
			end
            if manaBar.FullPowerFrame and Precognito.db.profile.FeedBack then
                manaBar.FullPowerFrame:Initialize(true)
            end
        end
    end

    if manaBar.powerType ~= powerType or manaBar.powerType ~= powerType then
        manaBar.powerType = powerType
        manaBar.powerToken = powerToken
        if manaBar.FullPowerFrame then
            manaBar.FullPowerFrame:RemoveAnims()
        end
        if manaBar.FeedbackFrame then
            manaBar.FeedbackFrame:StopFeedbackAnim()
        end
        manaBar.currValue = UnitPower("player", powerType)
        if unitFrame.myManaCostPredictionBars then
            unitFrame.myManaCostPredictionBars:Hide()
        end
        unitFrame.predictedPowerCost = 0
    end
end

function UnitFrameManaCostPredictionBars_Update(frame, isStarting, startTime, endTime, spellID)
    if not frame.manabar or not frame.myManaCostPredictionBars then return end

    local cost = 0

    if not isStarting or startTime == endTime then
        local currentSpellID = spellID -- select(9, CastingInfo())

        if currentSpellID and frame.predictedPowerCost then
            cost = frame.predictedPowerCost
        else
            frame.predictedPowerCost = nil
        end

    else
        local costTable = GetSpellPowerCost(spellID)
        for _, costInfo in pairs(costTable) do
            if costInfo.type == frame.manabar.powerType then
                cost = costInfo.cost
                break
            end
        end

        frame.predictedPowerCost = cost
    end

    local manaBarTexture = frame.manabar:GetStatusBarTexture()
    UnitFrameManaBar_Update_New(frame.manabar, frame.unit)
    UnitFrameUtil_UpdateManaFillBar_New(frame, manaBarTexture, frame.myManaCostPredictionBars, cost)
end

-------------------------------------------------------

local function UnitFrame_Initialize(self, myManaCostPredictionBars)

    self.myManaCostPredictionBars = myManaCostPredictionBars

    if Precognito.db.profile.animMana then
        self:RegisterEvent("UNIT_SPELLCAST_START")
        self:RegisterEvent("UNIT_SPELLCAST_STOP")
        self:RegisterEvent("UNIT_SPELLCAST_FAILED")
        self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self.myManaCostPredictionBars:ClearAllPoints()
    else
        self:UnregisterEvent("UNIT_SPELLCAST_START")
        self:UnregisterEvent("UNIT_SPELLCAST_STOP")
        self:UnregisterEvent("UNIT_SPELLCAST_FAILED")
        self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        self.myManaCostPredictionBars:Hide()
    end

    if Precognito.db.profile.animHealth then
        self.PlayerFrameHealthBarAnimatedHealth = Mixin(CreateFrame("StatusBar", nil, self), AnimatedHealthLossMixin)
        self.PlayerFrameHealthBarAnimatedHealth:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        self.PlayerFrameHealthBarAnimatedHealth:OnLoad()
        self.PlayerFrameHealthBarAnimatedHealth:SetUnitHealthBar("player", self.healthbar)
        self.PlayerFrameHealthBarAnimatedHealth:SetFrameLevel(self.healthbar:GetFrameLevel() - 1)
        self.PlayerFrameHealthBarAnimatedHealth:Hide()
        self.healthbar:SetScript("OnUpdate", UnitFrameHealthBar_OnUpdate_New)
    end

    if self.manabar then
        if Precognito.db.profile.animMana then
            self.manabar.FeedbackFrame = CreateFrame("Frame", nil, self.manabar, "BuilderSpenderFrame")
            self.manabar.FeedbackFrame:SetAllPoints()
            self.manabar.FeedbackFrame:SetFrameLevel(self:GetParent():GetFrameLevel() + 2)
            self.manabar:SetScript("OnUpdate", UnitFrameManaBar_OnUpdate_New)
        end

        if Precognito.db.profile.FeedBack then
            self.manabar.FullPowerFrame = CreateFrame("Frame", nil, self.manabar, "FullResourcePulseFrame")
            self.manabar.FullPowerFrame:SetPoint("TOPRIGHT", 0, 0)
            self.manabar.FullPowerFrame:SetSize(124, 10)
            self:RegisterEvent("PLAYER_REGEN_DISABLED")
        else
            self:UnregisterEvent("PLAYER_REGEN_DISABLED")
        end
    end

    PlayerFrame:HookScript("OnEvent", function(frame, event, ...)
        if frame.unit ~= "player" then return end

        local eventUnit = ...

        if event == "PLAYER_REGEN_DISABLED" then
            OnEnterCombat(self)

        elseif event == "UNIT_SPELLCAST_START" and eventUnit == "player" then
            local _, _, _, startTime, endTime, _, _, _, spellID = CastingInfo()
            UnitFrameManaCostPredictionBars_Update(frame, true, startTime, endTime, spellID)

        elseif (event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_SUCCEEDED") and eventUnit == "player" then
            UnitFrameManaCostPredictionBars_Update(frame, false, nil, nil, nil)
        end
    end)

    UnitFrame_Update(self)
end

-------------------------------------------------------

local function UF_Event_Hook(self, event, ...)
    if self.unit ~= "player" then return end

    if not self.manaCostPrediction then
        self.manaCostPrediction = CreateFrame("Frame", nil, self, "ManaCostPredictionTemplate")
        UnitFrame_Initialize(self, _G[self:GetName() .. "ManaCostPredictionBars"])
    end
end

local function UF_HealthBar_Update_Hook(statusbar, unit)
    if not statusbar  then return end
    if statusbar.unit ~= "player" then return end

    if (unit == statusbar.unit) then
        if statusbar.AnimatedLossBar then
            statusbar.AnimatedLossBar:UpdateHealthMinMax()
        end
    end
end

local function UF_Update_Hook(self)
    if self.unit ~= "player" then return end

    if Precognito.db.profile.animMana then
        UnitFrameManaCostPredictionBars_Update(self)
    end
end

function Precognito:UFInit()

    hooksecurefunc("UnitFrame_OnEvent", UF_Event_Hook)
    hooksecurefunc("UnitFrameHealthBar_Update", UF_HealthBar_Update_Hook)
    hooksecurefunc("UnitFrame_Update", UF_Update_Hook)

    if Precognito.db.profile.animMana or Precognito.db.profile.FeedBack then
        hooksecurefunc("UnitFrameManaBar_UpdateType", UnitFrameManaBar_UpdateType_Hook)
    end
end


-----------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("VARIABLES_LOADED")

    if Precognito.db.profile.animHealth or Precognito.db.profile.animMana or Precognito.db.profile.FeedBack then
        Precognito:UFInit()
    end
end)
