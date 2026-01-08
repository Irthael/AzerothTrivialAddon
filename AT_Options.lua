local addonName, AT = ...
local _G = _G
local CreateFrame, UIDropDownMenu_Initialize, UIDropDownMenu_AddButton = _G.CreateFrame, _G.UIDropDownMenu_Initialize, _G.UIDropDownMenu_AddButton
local UIDropDownMenu_SetSelectedValue, UIDropDownMenu_SetText, UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_SetSelectedValue, _G.UIDropDownMenu_SetText, _G.UIDropDownMenu_CreateInfo
local UIParent, Settings, PlaySound, UIErrorsFrame = _G.UIParent, _G.Settings, _G.PlaySound, _G.UIErrorsFrame
local math, pairs, ipairs, tostring = _G.math, _G.pairs, _G.ipairs, _G.tostring
local optionsPanel = CreateFrame("Frame", "ATOptionsPanel", UIParent)
optionsPanel.name = "Azeroth Trivia"
local title = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(AT.L["Azeroth Trivia Settings"])

local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
Settings.RegisterAddOnCategory(category)

function AT:OpenSettings()
    Settings.OpenToCategory(category:GetID())
end

local function CreateSlider(name, label, minVal, maxVal, step, dbKey)
    local slider = CreateFrame("Slider", name, optionsPanel, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(200)
    
    _G[slider:GetName() .. 'Low']:SetText(tostring(minVal))
    _G[slider:GetName() .. 'High']:SetText(tostring(maxVal))
    
    slider:SetScript("OnShow", function(self)
        if AT.db then
            local val = AT.db[dbKey] or (dbKey == "answerTime" and 30 or 10)
            self:SetValue(val)
            _G[self:GetName() .. 'Text']:SetText(label .. ": " .. val .. "s")
        end
    end)
    
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        if AT.db then
            AT.db[dbKey] = value
        end
        _G[self:GetName() .. 'Text']:SetText(label .. ": " .. value .. "s")
    end)
    
    return slider
end

local answerTimeSlider = CreateSlider("ATAnswerTimeSlider", AT.L["Answer Time"], 10, 60, 1, "answerTime")
answerTimeSlider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -40)

local intermissionTimeSlider = CreateSlider("ATIntermissionTimeSlider", AT.L["Intermission Time"], 5, 30, 1, "intermissionTime")
intermissionTimeSlider:SetPoint("TOPLEFT", answerTimeSlider, "BOTTOMLEFT", 0, -40)

local escapeCheck = CreateFrame("CheckButton", "ATEscapeCheck", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
escapeCheck:SetPoint("TOPLEFT", intermissionTimeSlider, "BOTTOMLEFT", 0, -40)
_G[escapeCheck:GetName() .. "Text"]:SetText(AT.L["Close Main Menu with Escape"])

escapeCheck:SetScript("OnShow", function(self)
    if AT.db then
        self:SetChecked(AT.db.closeWithEscape)
    end
end)

escapeCheck:SetScript("OnClick", function(self)
    if AT.db then
        AT.db.closeWithEscape = self:GetChecked()
        AT:UpdateEscapeConfig(AT.db.closeWithEscape)
    end
end)

local blockInvitesCheck = CreateFrame("CheckButton", "ATBlockInvitesCheck", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
blockInvitesCheck:SetPoint("TOPLEFT", escapeCheck, "BOTTOMLEFT", 0, -20)
_G[blockInvitesCheck:GetName() .. "Text"]:SetText(AT.L["Block Multiplayer Invites"])

blockInvitesCheck:SetScript("OnShow", function(self)
    if AT.db then
        self:SetChecked(AT.db.blockInvites)
    end
end)

blockInvitesCheck:SetScript("OnClick", function(self)
    if AT.db then
        AT.db.blockInvites = self:GetChecked()
    end
end)

local qTypeLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
qTypeLabel:SetPoint("TOPLEFT", blockInvitesCheck, "BOTTOMLEFT", 0, -20)
qTypeLabel:SetText(AT.L["Question Type"] .. ":")

local function CreateQuestionTypeCheck(name, label, key, anchor)
    local check = CreateFrame("CheckButton", name, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -5)
    _G[check:GetName() .. "Text"]:SetText(label)
    
    check:SetScript("OnShow", function(self)
        if AT.db and AT.db.allowedTypes then
            self:SetChecked(AT.db.allowedTypes[key])
        end
    end)
    
    check:SetScript("OnClick", function(self)
        if AT.db and AT.db.allowedTypes then
            local count = 0
            for _, active in pairs(AT.db.allowedTypes) do
                if active then count = count + 1 end
            end
            
            if not self:GetChecked() and count <= 1 then
                
                self:SetChecked(true)
                UIErrorsFrame:AddMessage(AT.L["You must have at least one question type selected!"], 1.0, 0.1, 0.1, 1.0)
                PlaySound(847, "Master")
            else
                AT.db.allowedTypes[key] = self:GetChecked()
            end
        end
    end)
    
    return check
end

local textCheck = CreateQuestionTypeCheck("ATTextCheck", AT.L["Text"], "text", qTypeLabel)
local voicesCheck = CreateQuestionTypeCheck("ATVoicesCheck", AT.L["Voices"], "voice", textCheck)
local musicCheck = CreateQuestionTypeCheck("ATMusicCheck", AT.L["Music"], "music", voicesCheck)

local mpNumLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
mpNumLabel:SetPoint("TOPLEFT", musicCheck, "BOTTOMLEFT", 0, -20)
mpNumLabel:SetText(AT.L["Amount of questions in multiplayer:"])

local mpNumDropDown = CreateFrame("Frame", "ATMPNumDropDown", optionsPanel, "UIDropDownMenuTemplate")
mpNumDropDown:SetPoint("TOPLEFT", mpNumLabel, "BOTTOMLEFT", -15, -5)

local function OnNumClick(self)
    UIDropDownMenu_SetSelectedValue(mpNumDropDown, self.value)
    if AT.db then
        AT.db.numMultiplayerQuestions = self.value
    end
end

local function InitializeNum(self, level)
    local info = UIDropDownMenu_CreateInfo()
    local currentVal = (AT.db and AT.db.numMultiplayerQuestions) or 10
    info.func = OnNumClick
    
    local options = {5, 10, 15, 20, 0}
    for _, val in ipairs(options) do
        info.text = (val == 0) and AT.L["All"] or (val .. " " .. AT.L["Questions"])
        info.value = val
        info.checked = (currentVal == val)
        UIDropDownMenu_AddButton(info, level)
    end
end

mpNumDropDown:SetScript("OnShow", function(self)
    UIDropDownMenu_Initialize(self, InitializeNum)
    local val = (AT.db and AT.db.numMultiplayerQuestions) or 10
    UIDropDownMenu_SetSelectedValue(self, val)
    local text = (val == 0) and AT.L["All"] or (val .. " " .. AT.L["Questions"])
    UIDropDownMenu_SetText(self, text)
end)

local minimapCheck = CreateFrame("CheckButton", "ATMinimapCheck", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
minimapCheck:SetPoint("TOPLEFT", mpNumDropDown, "BOTTOMLEFT", 15, -20)
_G[minimapCheck:GetName() .. "Text"]:SetText(AT.L["Show Minimap Icon"])

minimapCheck:SetScript("OnShow", function(self)
    self:SetChecked(not AT.db.minimap.hide)
end)

minimapCheck:SetScript("OnClick", function(self)
    AT.db.minimap.hide = not self:GetChecked()
    AT:UpdateMinimapIconVisibility()
end)

local authorText = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
authorText:SetPoint("BOTTOMLEFT", 16, 16)
authorText:SetText("Addon created by Irthael- DunModr - |cff00ff00v" .. (AT.Version or "1.0.2") .. "|r")
