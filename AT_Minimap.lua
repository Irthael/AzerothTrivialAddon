local addonName, AT = ...
local _G = _G
local CreateFrame, Minimap, GameTooltip, GetCursorPosition = _G.CreateFrame, _G.Minimap, _G.GameTooltip, _G.GetCursorPosition
local math, cos, sin, deg, rad, atan2 = _G.math, _G.math.cos, _G.math.sin, _G.math.deg, _G.math.rad, _G.math.atan2

function AT:InitializeMinimapIcon()
    local db = AT.db.minimap
    
    local icon = CreateFrame("Button", "AzerothTriviaMinimapButton", Minimap)
    icon:SetSize(31, 31)
    icon:SetFrameLevel(8)
    icon:SetToplevel(true)
    icon:SetMovable(true)
    icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    icon:RegisterForDrag("LeftButton")
    
    local background = icon:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("CENTER")
    
    local iconTexture = icon:CreateTexture(nil, "ARTWORK")
    iconTexture:SetTexture("Interface\\Icons\\Inv_misc_questionmark")
    iconTexture:SetSize(18, 18)
    iconTexture:SetPoint("CENTER")
    
    local border = icon:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT")
    
    icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Azeroth Trivia")
        GameTooltip:AddLine("|cffeda55f" .. AT.L["Left-Click:|r Open Addon"], 1, 1, 1)
        GameTooltip:AddLine("|cffeda55f" .. AT.L["Right-Click:|r Open Settings"], 1, 1, 1)
        GameTooltip:AddLine("|cffeda55f" .. AT.L["Drag:|r Move Icon"], 1, 1, 1)
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    local function UpdatePosition()
        local angle = rad(db.minimapPos or 45)
        local radius = 102
        local x = radius * cos(angle)
        local y = radius * sin(angle)
        icon:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    
    icon:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            mx, my = mx / scale, my / scale
            local cx, cy = Minimap:GetCenter()
            local angle = atan2(my - cy, mx - cx)
            db.minimapPos = deg(angle)
            UpdatePosition()
        end)
    end)
    
    icon:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    
    icon:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            AT.ModeFrame:Show()
        elseif button == "RightButton" then
            AT:OpenSettings()
        end
    end)
    
    AT.MinimapIcon = icon
    UpdatePosition()
    
    if db.hide then
        icon:Hide()
    else
        icon:Show()
    end
end

function AT:UpdateMinimapIconVisibility()
    if not AT.MinimapIcon then return end
    if AT.db.minimap.hide then
        AT.MinimapIcon:Hide()
    else
        AT.MinimapIcon:Show()
    end
end
