local addonName, AT = ...
local _G = _G
local ipairs, table, tonumber, math = _G.ipairs, _G.table, _G.tonumber, _G.math
local CreateFrame, UIParent, PlaySoundFile, StaticPopup_Show, PlaySound, StopSound = _G.CreateFrame, _G.UIParent, _G.PlaySoundFile, _G.StaticPopup_Show, _G.PlaySound, _G.StopSound
local MP = AT.MP

local lobbyFrame = CreateFrame("Frame", "ATLobbyFrame", UIParent, "BasicFrameTemplateWithInset")
lobbyFrame:SetSize(400, 300)
lobbyFrame:SetPoint("CENTER")
lobbyFrame:SetMovable(true)
lobbyFrame:EnableMouse(true)
lobbyFrame:RegisterForDrag("LeftButton")
lobbyFrame:SetScript("OnDragStart", lobbyFrame.StartMoving)
lobbyFrame:SetScript("OnDragStop", lobbyFrame.StopMovingOrSizing)
lobbyFrame:Hide()
lobbyFrame:SetScript("OnHide", function()
    if not MP.IsInternalHide then
        MP:Leave()
    end
end)

lobbyFrame.title = lobbyFrame:CreateFontString(nil, "OVERLAY")
lobbyFrame.title:SetFontObject("GameFontHighlight")
lobbyFrame.title:SetPoint("CENTER", lobbyFrame.TitleBg, "CENTER", 0, 0)
lobbyFrame.title:SetText(AT.L["Azeroth Trivia - Lobby"])

local listBg = CreateFrame("Frame", nil, lobbyFrame, "BackdropTemplate")
listBg:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
listBg:SetBackdropColor(0, 0, 0, 0.5)
listBg:SetSize(360, 180)
listBg:SetPoint("TOP", 0, -40)

local playerListText = listBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
playerListText:SetPoint("TOPLEFT", 10, -10)
playerListText:SetJustifyH("LEFT")
playerListText:SetText(AT.L["Players"] .. ":\n")

local btnInvite = CreateFrame("Button", nil, lobbyFrame, "GameMenuButtonTemplate")
btnInvite:SetSize(120, 30)
btnInvite:SetPoint("BOTTOMLEFT", 20, 40)
btnInvite:SetText(AT.L["Invite Group"])
btnInvite:SetScript("OnClick", function()
    MP:InviteGroup()
end)
MP.BtnInvite = btnInvite

local btnStart = CreateFrame("Button", nil, lobbyFrame, "GameMenuButtonTemplate")
btnStart:SetSize(120, 30)
btnStart:SetPoint("BOTTOMRIGHT", -20, 40)
btnStart:SetText(AT.L["Start Game"])
btnStart:SetScript("OnClick", function()
    MP:StartGame()
end)

local btnBack = CreateFrame("Button", nil, lobbyFrame, "GameMenuButtonTemplate")
btnBack:SetSize(80, 25)
btnBack:SetPoint("BOTTOM", 0, 10)
btnBack:SetText(AT.L["Leave"])
btnBack:SetScript("OnClick", function()
    MP:Leave()
    if AT.ModeFrame then AT.ModeFrame:Show() end
end)

MP.LobbyFrame = lobbyFrame
MP.PlayerListText = playerListText

function MP:UpdateLobbyUI()
    if MP.IsSearching then
        MP.PlayerListText:SetText(AT.L["Searching for game..."])
        btnStart:Disable()
        btnInvite:Disable()
        return
    end

    local text = AT.L["Players"] .. " (" .. #MP.LobbyMembers .. "):\n"
    for _, name in ipairs(MP.LobbyMembers) do
        text = text .. "- " .. name .. "\n"
    end
    MP.PlayerListText:SetText(text)
    
    if MP.IsLeader then
        btnStart:Enable()
        btnInvite:Enable()
    else
        btnStart:Disable()
        btnInvite:Disable()
    end
end

local gameFrame = CreateFrame("Frame", "ATMPGameFrame", UIParent, "BasicFrameTemplateWithInset")
gameFrame:SetSize(320, 315)
gameFrame:SetPoint("CENTER")
gameFrame:SetMovable(true)
gameFrame:EnableMouse(true)
gameFrame:RegisterForDrag("LeftButton")
gameFrame:SetScript("OnDragStart", gameFrame.StartMoving)
gameFrame:SetScript("OnDragStop", gameFrame.StopMovingOrSizing)
gameFrame:Hide()
gameFrame:SetScript("OnHide", function()
    if not MP.IsInternalHide then
        MP:Leave()
    end
end)

gameFrame.title = gameFrame:CreateFontString(nil, "OVERLAY")
gameFrame.title:SetFontObject("GameFontHighlight")
gameFrame.title:SetPoint("CENTER", gameFrame.TitleBg, "CENTER", 0, 0)
gameFrame.title:SetText(AT.L["Azeroth Trivia - MP"])

local progressText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
progressText:SetPoint("TOP", 0, -22)
progressText:SetText("")
MP.ProgressText = progressText

local qText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
qText:SetPoint("TOP", 0, -45) 
qText:SetSize(280, 180) 
qText:SetJustifyH("CENTER")
qText:SetJustifyV("TOP")
qText:SetText(AT.L["Waiting for question..."])

local btnPlayAudio = CreateFrame("Button", nil, gameFrame, "GameMenuButtonTemplate")
btnPlayAudio:SetPoint("TOP", 0, -40)
btnPlayAudio:SetSize(160, 40)
btnPlayAudio:SetText(AT.L["Play Audio"])
btnPlayAudio:Hide()

local btnPlayAgain = CreateFrame("Button", nil, gameFrame, "GameMenuButtonTemplate")
btnPlayAgain:SetPoint("BOTTOMLEFT", 10, 30)
btnPlayAgain:SetSize(120, 25)
btnPlayAgain:SetText(AT.L["Play Again"])
btnPlayAgain:Hide()
btnPlayAgain:SetScript("OnClick", function()
    MP:PlayAgain()
end)

local btnEndGame = CreateFrame("Button", nil, gameFrame, "GameMenuButtonTemplate")
btnEndGame:SetSize(100, 25)
btnEndGame:SetPoint("BOTTOMRIGHT", -10, 30)
btnEndGame:SetText(AT.L["End Game"])
btnEndGame:Hide()
btnEndGame:SetScript("OnClick", function()
    if MP.IsLeader then
        MP:EndGame()
    end
end)

local mpButtons = {}
for i=1, 4 do
    local btn = CreateFrame("Button", nil, gameFrame, "GameMenuButtonTemplate")
    btn:SetSize(200, 30)
    if i == 1 then
        btn:SetPoint("TOP", 0, -100)
    else
        btn:SetPoint("TOP", mpButtons[i-1], "BOTTOM", 0, -10)
    end
    btn:SetScript("OnClick", function(self)
        MP:Send("ANSWER;" .. (self.originalIndex or i))
        for _, b in ipairs(mpButtons) do b:Disable() end
    end)
    table.insert(mpButtons, btn)
end

MP.GameFrame = gameFrame
MP.QuestionText = qText

function MP:InitGameUI()
    MP.IsInternalHide = true
    MP.LobbyFrame:Hide()
    MP.IsInternalHide = false
    MP.GameFrame:Show()
    qText:Show()
    qText:SetText(AT.L["Preparing game..."])
    MP.ProgressText:SetText("")
    btnPlayAudio:Hide()
    MP.TimerBar:Hide()
    
    for _, btn in ipairs(mpButtons) do btn:Disable() btn:SetText("") btn:Show() end
    
    btnPlayAgain:Hide()
    if MP.IsLeader then
        btnEndGame:Show()
        btnEndGame:Disable()
    else
        btnEndGame:Hide()
    end
end

function MP:OnQuestionReceived(parts)
    local uid = tonumber(parts[2])
    local remaining = tonumber(parts[3]) or AT.db.answerTime or 30
    
    local qData = AT.QuestionIndex[uid]
    
    if not qData then
        qText:SetText(string.format(AT.L["Error: Question %s not found!"], tostring(uid or "nil")))
        return
    end

    if MP.IsLeader then
        btnEndGame:Enable()
    end

    local qType = qData.type or "text"
    local locData = AT:GetLocaleData(qData)
    local content = (qType == "voice" or qType == "music") and qData.id or locData.question
    
    if qType == "text" then
        qText:Show()
        btnPlayAudio:Hide()
        qText:SetText(content)
        MP.TimerBar:Show() 
    elseif qType == "voice" or qType == "music" then
         qText:Hide()
         btnPlayAudio:Show()
         local function PlayTriggeredSound()
             AT:StopCurrentSound()
             local fileID = tonumber(content)
             local success, handle
             if fileID then
                 success, handle = PlaySoundFile(fileID, "Master")
             else
                 success, handle = PlaySoundFile(content, "Master")
             end
             if success then
                 AT.CurrentSoundHandle = handle
             end
         end
         
         btnPlayAudio:SetScript("OnClick", PlayTriggeredSound)
         PlayTriggeredSound()
         MP.TimerBar:Show()
    end
    
    MP:StartTimer(remaining)
    
    local answers = {
        {text = locData.answer, originalIndex = 1},
        {text = locData.false_1, originalIndex = 2},
        {text = locData.false_2, originalIndex = 3},
        {text = locData.false_3, originalIndex = 4}
    }
    
    AT:ShuffleTable(answers)

    local currentIndex = tonumber(parts[4])
    local totalCount = tonumber(parts[5])
    
    if currentIndex and totalCount then
        MP.ProgressText:SetText(string.format(AT.L["Question %d of %d"], currentIndex, totalCount))
    end

    for i=1, 4 do
        mpButtons[i]:SetText(answers[i].text)
        mpButtons[i].originalIndex = answers[i].originalIndex
        mpButtons[i]:Enable()
        mpButtons[i]:GetFontString():SetTextColor(1, 0.82, 0)
    end
end

function MP:ShowGameEnd(winnerName)
    qText:Show()
    btnPlayAudio:Hide()
    qText:SetText(AT.L["GAME OVER"] .. "\n" .. (winnerName or ""))
    for _, btn in ipairs(mpButtons) do btn:Hide() end
    MP:StopTimer()
    MP.TimerBar:Hide()
    btnEndGame:Hide()
    MP.ProgressText:SetText("")
    
    if MP.IsLeader then
        btnPlayAgain:Show()
    end
end

function MP:ShowResult(correctIndex, winnerName, remaining)
    remaining = remaining or 10
    AT:StopCurrentSound()
    
    qText:Show()
    btnPlayAudio:Hide()
    
    for i, btn in ipairs(mpButtons) do
        btn:Disable()
        if btn.originalIndex == correctIndex then
            btn:GetFontString():SetTextColor(0, 1, 0)
        else
            btn:GetFontString():SetTextColor(1, 0, 0)
        end
    end
    
    if winnerName then
        qText:SetText("|cff00ff00" .. winnerName .. " " .. AT.L["answered correctly!|r\nLoading next question..."])
    end
    
    MP:StartTimer(remaining)
end

local timerBar = CreateFrame("StatusBar", nil, gameFrame)
timerBar:SetSize(300, 10)
timerBar:SetPoint("BOTTOM", 0, 10)
timerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
timerBar:SetStatusBarColor(0, 1, 0)
timerBar:SetMinMaxValues(0, 10)
timerBar:SetValue(10)

MP.TimerBar = timerBar

function MP:StartTimer(duration)
    timerBar:SetMinMaxValues(0, duration)
    timerBar:SetValue(duration)
    local elapsed = 0
    timerBar:SetScript("OnUpdate", function(self, elaspedTime)
        elapsed = elapsed + elaspedTime
        self:SetValue(duration - elapsed)
        if elapsed >= duration then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

function MP:StopTimer()
    timerBar:SetScript("OnUpdate", nil)
end
