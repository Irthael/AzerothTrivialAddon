local addonName, AT = ...
local _G = _G
local string, table, math, pairs, ipairs = _G.string, _G.table, _G.math, _G.pairs, _G.ipairs
local GetTime, C_Timer, UnitName, IsInGroup, IsInRaid = _G.GetTime, _G.C_Timer, _G.UnitName, _G.IsInGroup, _G.IsInRaid
local C_ChatInfo, StaticPopup_Show, strsplit, tonumber = _G.C_ChatInfo, _G.StaticPopup_Show, _G.strsplit, _G.tonumber
local PlaySound, PlaySoundFile, StopSound = _G.PlaySound, _G.PlaySoundFile, _G.StopSound
AT.MP = {}
local MP = AT.MP
MP.PREFIX = "AT_TRIVIA"
MP.GameState = {
    IDLE = "IDLE",
    LOBBY = "LOBBY",
    PLAYING = "PLAYING",
    FINISHED = "FINISHED"
}
MP.CurrentState = MP.GameState.IDLE
MP.LobbyMembers = {}
MP.IsLeader = false
MP.TotalQuestions = 10
MP.CurrentQuestionIndex = 0
MP.Scores = {}
MP.ActiveButtons = true
MP.LastQMsg = nil
MP.lastWarningTime = 0

local function CompareVersions(v1, v2)
    local a = { strsplit(".", v1) }
    local b = { strsplit(".", v2) }
    for i = 1, math.max(#a, #b) do
        local n1 = tonumber(a[i]) or 0
        local n2 = tonumber(b[i]) or 0
        if n1 > n2 then return 1 end
        if n1 < n2 then return -1 end
    end
    return 0
end

function MP:ShowVersionWarning()
    local now = GetTime()

    if (now - (MP.lastWarningTime or 0)) < 60 then return end
    MP.lastWarningTime = now
    
    local versionText = string.format(AT.L["Your version is: %s"], "|cffff0000" .. AT.Version .. "|r")
    _G.print("|cffff0000Azeroth Trivia: " .. AT.L["An inferior version of Azeroth Trivia has been detected, please update."] .. " " .. versionText .. "|r")
end



local mpFrame = CreateFrame("Frame")
mpFrame:RegisterEvent("CHAT_MSG_ADDON")
mpFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
mpFrame:RegisterEvent("GROUP_JOINED")

function MP:Send(msg)
    if IsInGroup() then
        C_ChatInfo.SendAddonMessage(MP.PREFIX, msg, (IsInRaid() and "RAID" or "PARTY"))
    else
        C_ChatInfo.SendAddonMessage(MP.PREFIX, msg, "WHISPER", UnitName("player"))
    end
end

C_ChatInfo.RegisterAddonMessagePrefix(MP.PREFIX)

mpFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == MP.PREFIX then
            MP:HandleMessage(message, sender)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if MP.CurrentState ~= MP.GameState.IDLE and not IsInGroup() then
            MP:Leave()
        elseif MP.CurrentState ~= MP.GameState.IDLE and MP.LeaderName then

            local leaderFound = false
            for i=1, _G.GetNumGroupMembers() do
                local name = _G.GetRaidRosterInfo(i)
                if name == MP.LeaderName then
                    leaderFound = true
                    break
                end
            end
            if not leaderFound and not MP.IsLeader then
                MP:Leave()
                _G.print("|cffff0000Azeroth Trivia: " .. AT.L["Leader has left the group. Game ended."] .. "|r")
            end
        end
    elseif event == "GROUP_JOINED" then
        C_Timer.After(2, function()
            MP:Send("VERSION_CHECK;" .. AT.Version)
        end)
    end
end)

StaticPopupDialogs["AT_MP_INVITE"] = {
    text = "%s " .. AT.L["wants to play Azeroth Trivia. Join?"],
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self)
        MP.LeaderName = self.data
        MP.CurrentState = MP.GameState.LOBBY
        MP:Send("JOIN;" .. UnitName("player"))
    end,
    timeout = 30,
    whileDead = true,
    hideOnEscape = true,
}

local CommandHandlers = {
    ["INVITE"] = function(parts, sender)
        if sender ~= UnitName("player") then 
             if AT.db and AT.db.blockInvites then return end
             
             local hostVersion = parts[2]
             if hostVersion and hostVersion ~= AT.Version then
                 local comp = CompareVersions(AT.Version, hostVersion)
                 local color = (comp == -1) and "|cffff0000" or "|cff00ff00"
                 local versionText = string.format(AT.L["Your version is: %s"], color .. AT.Version .. "|r")
                 
                 _G.print("|cffff0000Azeroth Trivia: " .. AT.L["You cannot join this game because your version does not match the host's version."] .. " (".. (hostVersion or "?.?.?") ..") " .. versionText .. "|r")
                 return
             end
             
             StaticPopup_Show("AT_MP_INVITE", sender, nil, sender)
        end
    end,
    ["VERSION_CHECK"] = function(parts, sender)
        if sender ~= UnitName("player") then
            local remoteVersion = parts[2]
            if remoteVersion then
                
                if CompareVersions(remoteVersion, AT.Version) == 1 then
                    MP:ShowVersionWarning()
                end
                MP:Send("VERSION_REP;" .. AT.Version)
            end
        end
    end,
    ["VERSION_REP"] = function(parts, sender)
        if sender ~= UnitName("player") then
            local remoteVersion = parts[2]
            if remoteVersion and CompareVersions(remoteVersion, AT.Version) == 1 then
                MP:ShowVersionWarning()
            end
        end
    end,
    ["JOIN"] = function(parts, sender, originalSender)
        local joinedPlayer = parts[2] or sender
        if MP.IsLeader then
            local exists = false
            for _, v in ipairs(MP.LobbyMembers) do
                if v == joinedPlayer then exists = true end
            end
            if not exists then
                table.insert(MP.LobbyMembers, joinedPlayer)
                
                local cleanJoiner = string.match(joinedPlayer, "([^%-]+)")
                if MP.Scores and not MP.Scores[cleanJoiner] then
                    MP.Scores[cleanJoiner] = 0
                end

                MP:UpdateLobbyUI()
                MP:BroadcastLobbyUpdate()
                
                if MP.CurrentState == MP.GameState.PLAYING and MP.LastQMsg then
                    local elapsed = GetTime() - (MP.PhaseStartTime or GetTime())
                    local totalAnswer = AT.db.answerTime or 30
                    local remaining = math.max(1, totalAnswer - elapsed)
                    
                    local qParts = { strsplit(";", MP.LastQMsg) }
                    local joinMsg = string.format("QUESTION;%s;%d;%s;%s", qParts[2] or "0", math.floor(remaining), qParts[4] or "1", qParts[5] or "1")
                    
                    C_ChatInfo.SendAddonMessage(MP.PREFIX, joinMsg, "WHISPER", originalSender)
                    
                    if MP.RoundEnded then
                        local rElapsed = GetTime() - (MP.ResultPhaseStartTime or GetTime())
                        local totalInter = AT.db.intermissionTime or 10
                        local rRemaining = math.max(1, totalInter - rElapsed)
                        
                        if MP.LastWinnerName then
                             C_ChatInfo.SendAddonMessage(MP.PREFIX, "RESULT_CORRECT;"..MP.LastWinnerName..";1;"..math.floor(rRemaining), "WHISPER", originalSender)
                        else
                             C_ChatInfo.SendAddonMessage(MP.PREFIX, "TIMEOUT;1;"..math.floor(rRemaining), "WHISPER", originalSender)
                        end
                    end
                end
            end
        end
    end,
    ["UPDATE_LOBBY"] = function(parts, sender)
        if not MP.IsLeader and MP.LeaderName == sender and MP.CurrentState ~= MP.GameState.IDLE then
            MP.LobbyMembers = {}
            local listStr = parts[2]
            if listStr then
                for p in string.gmatch(listStr, "([^,]+)") do
                    table.insert(MP.LobbyMembers, p)
                end
            end
            
            if MP.CurrentState ~= MP.GameState.PLAYING then
                MP.CurrentState = MP.GameState.LOBBY
                if MP.GameFrame then MP.GameFrame:Hide() end
                MP.LobbyFrame:Show()
            end
            MP:UpdateLobbyUI()
        end
    end,
    ["START_GAME"] = function(parts, sender)
        if sender == MP.LeaderName then
            MP.CurrentState = MP.GameState.PLAYING
            MP:InitGameUI()
        end
    end,
    ["ANSWER"] = function(parts, sender)
        if MP.IsLeader then
             local ansIndex = tonumber(parts[2])
             if ansIndex then MP:ValidateAnswer(sender, ansIndex) end
        end
    end,
    ["QUESTION"] = function(parts, sender)
        if MP.CurrentState == MP.GameState.PLAYING and sender == MP.LeaderName then
            MP:OnQuestionReceived(parts)
        end
    end,
    ["RESULT_CORRECT"] = function(parts, sender)
        if MP.CurrentState == MP.GameState.PLAYING and sender == MP.LeaderName then
            local pName = parts[2]
            local correctIndex = tonumber(parts[3])
            local remaining = tonumber(parts[4])
            if correctIndex then MP:ShowResult(correctIndex, pName, remaining) end
        end
    end,
    ["TIMEOUT"] = function(parts, sender)
        if MP.CurrentState == MP.GameState.PLAYING and sender == MP.LeaderName then
            local correctIndex = tonumber(parts[2])
            local remaining = tonumber(parts[3])
            if correctIndex then MP:ShowResult(correctIndex, nil, remaining) end
        end
    end,
    ["GAME_OVER"] = function(parts, sender)
        if MP.CurrentState == MP.GameState.PLAYING and sender == MP.LeaderName then
            MP:ShowGameEnd(parts[2])
        end
    end,
    ["RETURN_TO_LOBBY"] = function(parts, sender)
        if sender == MP.LeaderName then
            MP.CurrentState = MP.GameState.LOBBY
            MP.IsInternalHide = true
            if MP.GameFrame then MP.GameFrame:Hide() end
            MP.IsInternalHide = false
            MP.LobbyFrame:Show()
            MP:UpdateLobbyUI()
        end
    end,
    ["LEAVE"] = function(parts, sender)
        local leftPlayer = parts[2] or sender
        if MP.IsLeader then
            for i, v in ipairs(MP.LobbyMembers) do
                if v == leftPlayer then
                    table.remove(MP.LobbyMembers, i)
                    break
                end
            end
            MP:UpdateLobbyUI()
            MP:BroadcastLobbyUpdate()
        elseif sender == MP.LeaderName then
            MP:Leave()
        end
    end,
    ["CHECK_STATUS"] = function(parts, sender)
        if MP.IsLeader then
            MP:Send("STATUS_REP;" .. MP.CurrentState)
        end
    end,
    ["STATUS_REP"] = function(parts, sender)
        if MP.JoinTimer then
            MP.JoinTimer:Cancel()
            MP.JoinTimer = nil
            
            local state = parts[2]
            MP.LeaderName = sender
            MP:Send("JOIN;" .. UnitName("player"))
            
            if state == MP.GameState.PLAYING then
                MP.CurrentState = MP.GameState.PLAYING
                MP:InitGameUI()
                if MP.QuestionText then
                    MP.QuestionText:SetText(AT.L["Waiting for question..."])
                end
            else
                MP.CurrentState = MP.GameState.LOBBY
                if MP.GameFrame then MP.GameFrame:Hide() end
                MP.LobbyFrame:Show()
            end
            MP.IsSearching = false
            MP:UpdateLobbyUI()
        end
    end,
}

function MP:HandleMessage(msg, sender)
    local originalSender = sender
    sender = string.match(sender, "([^%-]+)")
    
    local parts = { strsplit(";", msg) }
    local cmd = parts[1]
    
    if CommandHandlers[cmd] then
        CommandHandlers[cmd](parts, sender, originalSender)
    end
end

function MP:PrepareSessionQuestions()
    local qDB = AT.QuestionDB
    local filteredDB = {}
    local allowed = (AT.db and AT.db.allowedTypes) or {text = true, voice = true, music = true}
    
    for _, q in ipairs(qDB) do
        if allowed[q.type] then
            table.insert(filteredDB, q)
        end
    end
    
    if #filteredDB == 0 then
        filteredDB = { unpack(qDB) }
    end

    AT:ShuffleTable(filteredDB)
    MP.SessionPool = filteredDB
end

function MP:StartGame()
    if not MP.IsLeader then return end
    MP:ClearTimers()
    
    MP:PrepareSessionQuestions()
    local availableCount = #MP.SessionPool
    
    local selected = AT.db.numMultiplayerQuestions or 10
    if selected == 0 or selected > availableCount then
        MP.TotalQuestions = availableCount
    else
        MP.TotalQuestions = selected
    end

    MP:Send("START_GAME")
    MP:InitGameUI()
    MP.Scores = {}
    for _, name in ipairs(MP.LobbyMembers) do
        local cleanName = string.match(name, "([^%-]+)")
        MP.Scores[cleanName] = 0
    end
    MP.CurrentQuestionIndex = 0
    MP.RoundEnded = false
    MP.CurrentRoundAnswerIndex = nil
    
    MP.NextQTimer = C_Timer.NewTimer(2, function() MP:NextQuestion() end)
end

function MP:NextQuestion()
     if not MP.IsLeader then return end
     AT:StopCurrentSound()
     MP.CurrentQuestionIndex = MP.CurrentQuestionIndex + 1
     if MP.CurrentQuestionIndex > MP.TotalQuestions or not MP.SessionPool[MP.CurrentQuestionIndex] then
          MP:EndGame()
          return
     end
     
     MP.RoundEnded = false
     MP.LastWinnerName = nil
     MP.RoundAnswers = {}
     
     local qData = MP.SessionPool[MP.CurrentQuestionIndex]
     MP.CurrentQuestionData = qData
     
     local duration = AT.db.answerTime or 30
     local msg = string.format("QUESTION;%d;%d;%d;%d", qData.uid, duration, MP.CurrentQuestionIndex, MP.TotalQuestions)
     
     MP.PhaseStartTime = GetTime()
     MP.PhaseDuration = duration
     MP.LastQMsg = msg
     MP:Send(msg)
     
     MP.RoundTimer = C_Timer.NewTimer(MP.PhaseDuration + 1, function()
         if not MP.RoundEnded then
             MP:HandleTimeout()
         end
     end)
end

function MP:HandleTimeout()
    MP.RoundEnded = true
    MP.LastWinnerName = nil
    MP.ResultPhaseStartTime = GetTime()
    MP.ResultPhaseDuration = AT.db.intermissionTime or 10
    MP:Send("TIMEOUT;1;"..MP.ResultPhaseDuration)
    MP:ShowResult(1, nil, MP.ResultPhaseDuration)
    MP.NextQTimer = C_Timer.NewTimer(MP.ResultPhaseDuration, function() MP:NextQuestion() end)
end

function MP:ValidateAnswer(player, index)
    if MP.RoundEnded then return end
    
    MP.RoundAnswers = MP.RoundAnswers or {}
    if MP.RoundAnswers[player] then return end 
    MP.RoundAnswers[player] = true

    if index == 1 then
        MP.RoundEnded = true
        MP.LastWinnerName = player
        MP.ResultPhaseStartTime = GetTime()
        MP.ResultPhaseDuration = AT.db.intermissionTime or 10
        if MP.RoundTimer then MP.RoundTimer:Cancel() end
        MP.Scores[player] = (MP.Scores[player] or 0) + 1
        MP:Send("RESULT_CORRECT;"..player..";1;"..MP.ResultPhaseDuration)
        MP:ShowResult(1, player, MP.ResultPhaseDuration)
        MP.NextQTimer = C_Timer.NewTimer(MP.ResultPhaseDuration, function() MP:NextQuestion() end)
    else
        MP:Send("RESULT_WRONG;"..player)
        
        local count = 0
        for _ in pairs(MP.RoundAnswers) do count = count + 1 end
        
        if count >= #MP.LobbyMembers then
            if MP.RoundTimer then MP.RoundTimer:Cancel() end
            MP:HandleTimeout()
        end
    end
end

function MP:EndGame()
    MP.RoundEnded = true
    AT:StopCurrentSound()
    MP:ClearTimers()
    MP.LastQMsg = nil

    local maxScore = 0
    for _, s in pairs(MP.Scores) do
        if s > maxScore then maxScore = s end
    end
    
    local winners = {}
    for p, s in pairs(MP.Scores) do
        if s == maxScore and maxScore > 0 then
            table.insert(winners, p)
        end
    end
    
    local resultText = AT.L["Winner: None"]
    if #winners == 1 then
        resultText = AT.L["Winner"] .. ": " .. winners[1]
    elseif #winners > 1 then
        resultText = AT.L["Tie: "] .. table.concat(winners, " & ")
    end
    
    resultText = resultText .. "\n\n" .. AT.L["Scores:"]
    local sortedScores = {}
    for p, s in pairs(MP.Scores) do
        table.insert(sortedScores, {name = p, score = s})
    end
    table.sort(sortedScores, function(a, b) return a.score > b.score end)
    
    for _, entry in ipairs(sortedScores) do
        resultText = resultText .. "\n" .. entry.name .. " - " .. entry.score
    end

    MP:Send("GAME_OVER;"..resultText)
    MP:ShowGameEnd(resultText)
end

function MP:BroadcastLobbyUpdate()
    local listStr = table.concat(MP.LobbyMembers, ",")
    MP:Send("UPDATE_LOBBY;" .. listStr)
end

function MP:JoinOrHost()
    MP:ClearTimers()
    MP.IsSearching = true
    MP.LeaderName = nil
    MP.LobbyMembers = {}
    
    if IsInGroup() then
        MP:Send("CHECK_STATUS")
        MP.LobbyFrame:Show()
        MP:UpdateLobbyUI()
        
        MP.JoinTimer = C_Timer.NewTimer(1.2, function()
             MP.JoinTimer = nil
             if MP.IsSearching then
                 MP:CreateLobby()
             end
        end)
    else
        MP:CreateLobby()
    end
end

function MP:CreateLobby()
    MP:ClearTimers()
    MP.IsSearching = false
    MP.CurrentState = MP.GameState.LOBBY
    MP.IsLeader = true
    MP.LeaderName = UnitName("player")
    MP.LobbyMembers = {UnitName("player")}
    if MP.GameFrame then MP.GameFrame:Hide() end
    MP.LobbyFrame:Show()
    MP:UpdateLobbyUI()
end

function MP:InviteGroup()
    if IsInGroup() then
        MP:Send("INVITE;" .. AT.Version)
    else
        print(AT.L["You are not in a group."])
    end
end

function MP:PlayAgain()
    if not MP.IsLeader then return end
    MP:Send("RETURN_TO_LOBBY")
    MP:ClearTimers()
    MP.CurrentState = MP.GameState.LOBBY
    MP.IsInternalHide = true
    if MP.GameFrame then MP.GameFrame:Hide() end
    MP.IsInternalHide = false
    MP.LobbyFrame:Show()
    MP:UpdateLobbyUI()
end

function MP:Leave()
    MP:Send("LEAVE;" .. UnitName("player"))
    MP:ClearTimers()
    MP.CurrentState = MP.GameState.IDLE
    MP.LeaderName = nil
    MP.LobbyMembers = {}
    MP.IsLeader = false
    MP.IsInternalHide = true
    if MP.LobbyFrame then MP.LobbyFrame:Hide() end
    if MP.GameFrame then MP.GameFrame:Hide() end
    MP.IsInternalHide = false
end

function MP:ClearTimers()
    if MP.RoundTimer then MP.RoundTimer:Cancel() MP.RoundTimer = nil end
    if MP.NextQTimer then MP.NextQTimer:Cancel() MP.NextQTimer = nil end
    if MP.JoinTimer then MP.JoinTimer:Cancel() MP.JoinTimer = nil end
end
