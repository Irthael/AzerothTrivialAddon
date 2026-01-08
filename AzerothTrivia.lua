local addonName, AT = ...
local _G = _G
local pairs, ipairs, table, math, string = _G.pairs, _G.ipairs, _G.table, _G.math, _G.string
local GetTime, C_Timer, UnitName, IsInGroup, GetLocale = _G.GetTime, _G.C_Timer, _G.UnitName, _G.IsInGroup, _G.GetLocale
local CreateFrame, UIParent, PlaySound, PlaySoundFile, StopSound = _G.CreateFrame, _G.UIParent, _G.PlaySound, _G.PlaySoundFile, _G.StopSound
local UISpecialFrames, StaticPopupDialogs, SlashCmdList = _G.UISpecialFrames, _G.StaticPopupDialogs, _G.SlashCmdList
local tonumber, tostring, math_random = _G.tonumber, _G.tostring, _G.math.random
local UIErrorsFrame = _G.UIErrorsFrame
local questionDB = AT.QuestionDB

local currentRound = nil
local optionButtons = {}
local frame

local dbFrame = CreateFrame("Frame")
dbFrame:RegisterEvent("ADDON_LOADED")
dbFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName == addonName then
        -- Initialize empty DB
        if not AzerothTriviaDB then AzerothTriviaDB = {} end
        
        -- Default Values Migration/Initialization
        if AzerothTriviaDB.intermissionTime == nil then AzerothTriviaDB.intermissionTime = 10 end
        if AzerothTriviaDB.closeWithEscape == nil then AzerothTriviaDB.closeWithEscape = true end
        if AzerothTriviaDB.numMultiplayerQuestions == nil then AzerothTriviaDB.numMultiplayerQuestions = 10 end
        if AzerothTriviaDB.answerTime == nil then AzerothTriviaDB.answerTime = 30 end
        
        if not AzerothTriviaDB.allowedTypes then
            AzerothTriviaDB.allowedTypes = {
                text = true,
                voice = true,
                music = true,
            }
        else
            -- Ensure all subtypes exist
            if AzerothTriviaDB.allowedTypes.text == nil then AzerothTriviaDB.allowedTypes.text = true end
            if AzerothTriviaDB.allowedTypes.voice == nil then AzerothTriviaDB.allowedTypes.voice = true end
            if AzerothTriviaDB.allowedTypes.music == nil then AzerothTriviaDB.allowedTypes.music = true end
        end
        
        if not AzerothTriviaDB.minimap then
            AzerothTriviaDB.minimap = {
                hide = false,
                minimapPos = 45,
            }
        else
            if AzerothTriviaDB.minimap.hide == nil then AzerothTriviaDB.minimap.hide = false end
            if AzerothTriviaDB.minimap.minimapPos == nil then AzerothTriviaDB.minimap.minimapPos = 45 end
        end

        AT.db = AzerothTriviaDB
        
        -- Index questions for fast access
        AT.QuestionIndex = {}
        for _, q in ipairs(questionDB) do
            AT.QuestionIndex[q.uid] = q
        end

        AT:UpdateEscapeConfig(AT.db.closeWithEscape)
        
        if AT.InitializeMinimapIcon then
            AT:InitializeMinimapIcon()
        end
    end
end)

StaticPopupDialogs["AZEROTHTRIVIA_ABOUT"] = {
    text = AT.L["About Message"],
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

frame = CreateFrame("Frame", "AzerothTrivialFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(320, 315)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

frame.title = frame:CreateFontString(nil, "OVERLAY")
frame.title:SetFontObject("GameFontHighlight")
frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER", 0, 0)
frame.title:SetText("Azeroth Trivia")

local btnPlay = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
btnPlay:SetPoint("TOP", 0, -40)
btnPlay:SetSize(160, 40)
btnPlay:SetText(AT.L["Play Audio"])

local questionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
questionText:SetPoint("TOP", 0, -40)
questionText:SetSize(280, 60)
questionText:SetJustifyH("CENTER")
questionText:SetText("")


for i = 1, 4 do
    local btn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    btn:SetSize(200, 30)
    if i == 1 then
        btn:SetPoint("TOP", 0, -100)
    else
        btn:SetPoint("TOP", optionButtons[i-1], "BOTTOM", 0, -10)
    end
    btn:Disable()
    table.insert(optionButtons, btn)
end

local btnNext = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
btnNext:SetPoint("TOP", optionButtons[4], "BOTTOM", 0, -15)
btnNext:SetSize(140, 30)
btnNext:SetText(AT.L["New Question"])
btnNext:Hide()

local btnBack = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
btnBack:SetSize(80, 25)
btnBack:SetPoint("BOTTOMLEFT", 10, 10)
btnBack:SetText(AT.L["Back"])
btnBack:SetScript("OnClick", function()
    frame:Hide()
    AT.ModeFrame:Show()
end)

function AT:StopCurrentSound()
    if AT.CurrentSoundHandle then
        StopSound(AT.CurrentSoundHandle)
        AT.CurrentSoundHandle = nil
    end
end

local function ForcePlay(soundID, isFile)
    AT:StopCurrentSound()
    local success, handle
    if isFile then
        success, handle = PlaySoundFile(soundID, "Master")
    else
        success, handle = PlaySound(soundID, "Master", true)
    end
    if success then
        AT.CurrentSoundHandle = handle
    end
end

function AT:GetLocaleData(qData)
    local loc = GetLocale()
    if loc == "esMX" then loc = "esES" end
    if qData[loc] then
        return qData[loc]
    end
    -- Fallback to enUS if preferred locale is missing
    return qData["enUS"] or qData
end

function AT:ShuffleTable(t)
    if not t then return end
    for i = #t, 2, -1 do
        local j = math_random(i)
        t[i], t[j] = t[j], t[i]
    end
end

local function ResetButtons()
    for _, btn in ipairs(optionButtons) do
        btn:SetText("")
        btn:Disable()
        btn:GetFontString():SetTextColor(1, 0.82, 0) 
    end
    btnPlay:Enable()
    btnNext:Hide()
end

local function StartNewRound()
    AT:StopCurrentSound()
    local filteredDB = {}
    local allowed = (AT.db and AT.db.allowedTypes) or {text = true, voice = true, music = true}
    
    for _, q in ipairs(questionDB) do
        if allowed[q.type] then
            table.insert(filteredDB, q)
        end
    end
    
    if #filteredDB == 0 then
        filteredDB = questionDB
    end

    currentRound = filteredDB[math.random(#filteredDB)]
    local locData = AT:GetLocaleData(currentRound)
    ResetButtons()

    if currentRound.type == "voice" or currentRound.type == "music" then
        btnPlay:Show()
        questionText:Hide()
    else
        btnPlay:Hide()
        questionText:Show()
        questionText:SetText(locData.question)
        for _, btn in ipairs(optionButtons) do
            btn:Enable()
        end
    end

    local answers = {
        {text = locData.answer, isCorrect = true},
        {text = locData.false_1, isCorrect = false},
        {text = locData.false_2, isCorrect = false},
        {text = locData.false_3, isCorrect = false}
    }
    
    AT:ShuffleTable(answers)
    
    for i, btn in ipairs(optionButtons) do
        btn:SetText(answers[i].text)
        btn.isCorrect = answers[i].isCorrect
    end
end

local function OnAnswerSelected(clickedBtn)
    AT:StopCurrentSound()
    for _, btn in ipairs(optionButtons) do
        btn:Disable()
        
        if btn.isCorrect then
            btn:GetFontString():SetTextColor(0, 1, 0)
        elseif btn == clickedBtn then
             btn:GetFontString():SetTextColor(1, 0, 0)
        end
    end

    if clickedBtn.isCorrect then
        ForcePlay(888, false)
    else
        ForcePlay(896, false)
    end
    
    btnNext:Show()
end

btnPlay:SetScript("OnClick", function()
    if currentRound and (currentRound.type == "voice" or currentRound.type == "music") then
        ForcePlay(currentRound.id, true)
        
        if not btnNext:IsShown() then
            for _, btn in ipairs(optionButtons) do
                btn:Enable()
            end
        end
    end
end)

for _, btn in ipairs(optionButtons) do
    btn:SetScript("OnClick", function(self)
        OnAnswerSelected(self)
    end)
end

btnNext:SetScript("OnClick", function()
    StartNewRound()
end)

AT.ModeFrame = CreateFrame("Frame", "ATModeSelectFrame", UIParent, "BasicFrameTemplateWithInset")
local modeFrame = AT.ModeFrame
modeFrame:SetSize(250, 150)
modeFrame:SetPoint("CENTER")
modeFrame:SetMovable(true)
modeFrame:EnableMouse(true)
modeFrame:RegisterForDrag("LeftButton")
modeFrame:SetScript("OnDragStart", modeFrame.StartMoving)
modeFrame:SetScript("OnDragStop", modeFrame.StopMovingOrSizing)
modeFrame:Hide()

modeFrame.title = modeFrame:CreateFontString(nil, "OVERLAY")
modeFrame.title:SetFontObject("GameFontHighlight")
modeFrame.title:SetPoint("CENTER", modeFrame.TitleBg, "CENTER", 0, 0)
modeFrame.title:SetText(AT.L["Select Mode"])

local btnSolo = CreateFrame("Button", nil, modeFrame, "GameMenuButtonTemplate")
btnSolo:SetSize(160, 30)
btnSolo:SetPoint("TOP", 0, -40)
btnSolo:SetText(AT.L["Solo Mode"])
btnSolo:SetScript("OnClick", function()
    modeFrame:Hide()
    frame:Show()
    if not currentRound then
        StartNewRound()
    end
end)

local btnMP = CreateFrame("Button", nil, modeFrame, "GameMenuButtonTemplate")
btnMP:SetSize(160, 30)
btnMP:SetPoint("TOP", btnSolo, "BOTTOM", 0, -10)
btnMP:SetText(AT.L["Multiplayer"])
btnMP:SetScript("OnClick", function()
    modeFrame:Hide()
    AT.MP:JoinOrHost()
end)

local btnSettings = CreateFrame("Button", nil, modeFrame, "GameMenuButtonTemplate")
btnSettings:SetSize(160, 30)
btnSettings:SetPoint("TOP", btnMP, "BOTTOM", 0, -10)
btnSettings:SetText(AT.L["Settings"])
btnSettings:SetScript("OnClick", function()
    AT:OpenSettings()
end)

modeFrame:SetSize(250, 190)

function AT:UpdateEscapeConfig(enable)
    local frames = {"ATModeSelectFrame", "ATLobbyFrame", "ATMPGameFrame", "AzerothTrivialFrame"}
    for _, frameName in ipairs(frames) do
        local found = false
        local foundIndex = nil
        for i, name in ipairs(UISpecialFrames) do
            if name == frameName then
                found = true
                foundIndex = i
                break
            end
        end
        
        if enable then
            if not found then
                table.insert(UISpecialFrames, frameName)
            end
        else
            if found then
                table.remove(UISpecialFrames, foundIndex)
            end
        end
    end
end

SLASH_AZEROTHTRIVIAL1 = "/at"
SlashCmdList["AZEROTHTRIVIAL"] = function(msg)
    if msg == "mp" then
         if IsInGroup() then
             AT.MP:JoinOrHost()
         else
             print(AT.L["You must be in a group to start Multiplayer."])
         end
    else
        AT.ModeFrame:Show()
    end
end