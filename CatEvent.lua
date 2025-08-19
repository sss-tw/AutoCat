-- 确保AutoCat对象已创建
AutoCat = AutoCat or {}
local AC = AutoCat -- 简写以方便引用

-- 初始化命名空间
AC.Event = AC.Event or {} -- 事件相关的变量和函数
AC.EventHandlers = AC.EventHandlers or {} -- 事件处理程序

-- 检查饰品可用性的函数
function AC.CheckTrinketUsability()
	-- 调试输出
	if Cat and Cat:IsDebugging() then
		DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Trinket Debug:|r 开始检查饰品可用性")
	end
	
	-- 创建隐藏的tooltip用于扫描装备描述
	if not AC.TrinketScanTooltip then
		AC.TrinketScanTooltip = CreateFrame("GameTooltip", "AutoCatTrinketScanTooltip", nil, "GameTooltipTemplate")
		AC.TrinketScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
	end
	
	-- 检查上部饰品（槽位13）
	local itemLink = GetInventoryItemLink("player", 13)
	if itemLink then
		AC.TrinketScanTooltip:ClearLines()
		AC.TrinketScanTooltip:SetInventoryItem("player", 13)
		
		-- 扫描tooltip文本查找"使用："并获取物品名称
		local hasUseEffect = false
		local tooltipTexts = {}
		local itemName = nil
		for i = 1, AC.TrinketScanTooltip:NumLines() do
			local line = getglobal("AutoCatTrinketScanTooltipTextLeft" .. i)
			if line and line:GetText() then
				local text = line:GetText()
				table.insert(tooltipTexts, text)
				-- 第一行就是物品名称
				if i == 1 then
					itemName = text
				end
				if text and (strfind(text, "使用：") or strfind(text, "Use:")) then
					hasUseEffect = true
				end
			end
		end
		AutoCat.TrinketUsable.upper = hasUseEffect
		
		-- 调试输出
		if Cat and Cat:IsDebugging() then
			local displayName = itemName or "未知"
			
			DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Trinket Debug:|r 上部饰品 " .. displayName .. " - " .. (hasUseEffect and "可使用" or "不可使用"))
			DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Trinket Debug:|r 上部饰品tooltip行数: " .. AC.TrinketScanTooltip:NumLines())
			for j, tooltipText in ipairs(tooltipTexts) do
				DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Trinket Debug:|r   第" .. j .. "行: " .. tooltipText)
			end
		end
	else
		AutoCat.TrinketUsable.upper = false
		if Cat and Cat:IsDebugging() then
			DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Trinket Debug:|r 上部饰品槽位为空")
		end
	end
	
	-- 检查下部饰品（槽位14）
	itemLink = GetInventoryItemLink("player", 14)
	if itemLink then
		AC.TrinketScanTooltip:ClearLines()
		AC.TrinketScanTooltip:SetInventoryItem("player", 14)
		
		-- 扫描tooltip文本查找"使用："并获取物品名称
		local hasUseEffect = false
		local tooltipTexts = {}
		local itemName = nil
		for i = 1, AC.TrinketScanTooltip:NumLines() do
			local line = getglobal("AutoCatTrinketScanTooltipTextLeft" .. i)
			if line and line:GetText() then
				local text = line:GetText()
				table.insert(tooltipTexts, text)
				-- 第一行就是物品名称
				if i == 1 then
					itemName = text
				end
				if text and (strfind(text, "使用：") or strfind(text, "Use:")) then
					hasUseEffect = true
				end
			end
		end
		AutoCat.TrinketUsable.below = hasUseEffect
		
		-- 调试输出
		if Cat and Cat:IsDebugging() then
			local displayName = itemName or "未知"
			
			DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Trinket Debug:|r 下部饰品 " .. displayName .. " - " .. (hasUseEffect and "可使用" or "不可使用"))
			DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Trinket Debug:|r 下部饰品tooltip行数: " .. AC.TrinketScanTooltip:NumLines())
			for j, tooltipText in ipairs(tooltipTexts) do
				DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Trinket Debug:|r   第" .. j .. "行: " .. tooltipText)
			end
		end
	else
		AutoCat.TrinketUsable.below = false
		if Cat and Cat:IsDebugging() then
			DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Trinket Debug:|r 下部饰品槽位为空")
		end
	end
end

-- 检查UnitXP函数是否可用
local UnitXP_SP3 = pcall(UnitXP, "nop", "nop");

-- 事件相关变量
AC.Event.UnitXP_SP3 = UnitXP_SP3 -- 暴露UnitXP可用性到命名空间
AC.Event.superWowEnabled = false -- SuperWow模组是否启用
AC.Event.errorBehind = true -- 是否能打背标记变量
AC.Event.errorBehindTimer = 0 -- 背标记计时器
AC.Event.castStartTime = {} -- 施法计时器
AC.Event.mainHandBeginTime = 0 -- 普攻计时器(主手)
AC.Event.mainHandDuration = 0 -- 普攻持续时间
AC.Event.gcdTimer = 0 -- GCD计时器
AC.Event.isCast = false -- 是否正在施法
AC.Event.oldEnergy = 0 -- 旧能量值
AC.Event.restoredEnergyTime = 0.0 -- 回能时间点
AC.Event.rakeCheck = {} -- 扫击检查
AC.Event.rakeDelayTime = {} -- 扫击延迟时间
AC.Event.ripCheck = {} -- 撕扯检查
AC.Event.ripDelayTime = {} -- 撕扯延迟时间
AC.Event.lastRakeTime = 0 -- 上次扫击时间
AC.Event.lastRipTime = 0 -- 上次撕扯时间
AC.Event.bleenCheckDelay = 0.3 -- 流血检查延迟
AC.Event.dotDurationDelay = 0.08 -- 新增：网络延迟补偿

-- 创建一个 Frame 并监听事件
local frame = CreateFrame("Frame")

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_ENERGY")
frame:RegisterEvent("SPELLCAST_START")
frame:RegisterEvent("SPELLCAST_STOP")
frame:RegisterEvent("SPELLCAST_FAILED")
frame:RegisterEvent("SPELLCAST_INTERRUPTED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

-- 熊德相关事件
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

-- 熊德通报相关事件（这些是AceLibrary事件，需要通过Cat addon注册）
-- SpellStatus和SpecialEvents事件将在Bear模块初始化时注册

-- SuperWow专有事件
frame:RegisterEvent("UNIT_CASTEVENT")
frame:RegisterEvent("RAW_COMBATLOG")



-- 事件处理函数
function AC.EventHandlers.OnEvent()
    -- 初始化
    if event == "PLAYER_LOGIN" then
        -- 简化加载信息

        -- SuperWoW检查（静默）
        if SUPERWOW_STRING then
            AC.Event.superWowEnabled = true
        end

        -- UnitXP和等级检查（静默）
        -- 确保Ace插件初始化
        if Cat then
            Cat:OnInitialize()
        end
        
        -- 熊德模块初始化
        if AC.Bear and AC.Bear.Initialize then
            AC.Bear:Initialize()
        end
        

    -- 进入游戏世界刷新常量值
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- 刷新化爪击、撕碎能量等状态值
        AC.Lib.DriudRefreshInfo()

    -- 装备变化刷新常量值
    elseif event == "UNIT_INVENTORY_CHANGED" then
        -- 刷新爪击、撕碎能量等状态值（包含饰品可用性检查）
        AC.Lib.DriudRefreshInfo()

    -- 目标变化刷新流血状态
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- 检测目标是否可以流血
        AC.Config.targetBleed = AC.Lib.CanBleed()
        
        -- 熊德目标变化处理
        if AC.Bear then
            AC.Bear:OnTargetChanged()
        end

    -- 背面判断
    elseif event == "UI_ERROR_MESSAGE" then
        if arg1=="你必须位于目标背后" then
            AC.Event.errorBehindTimer = GetTime()
            AC.Event.errorBehind = false
            -- DEFAULT_CHAT_FRAME:AddMessage("|cFFff647e提示：|r|cFFfca4bc1秒内打正面。|r")
        end

    -- 进入战斗
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- 熊德进入战斗处理
        if AC.Bear then
            AC.Bear:OnEnterCombat()
        end

    -- 离开战斗
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- 熊德离开战斗处理
        if AC.Bear then
            AC.Bear:OnLeaveCombat()
        end

        -- DEFAULT_CHAT_FRAME:AddMessage("|cFFff647e提示：|r|cFFfca4bc"..arg1.."|r")
    -- 施法事件处理，用于处理GCD
    elseif event == "SPELLCAST_START" then
        isCast = true

        -- GCD时间启动
        gcdtimer = GetTime()
        
        -- 治疗模块施法开始处理
        if AC.Healer and AC.Healer.OnSpellcastStart then
            AC.Healer.OnSpellcastStart()
        end
        
    elseif event == "SPELLCAST_STOP" then
        if isCast then
            isCast = false
        else
        -- 未读条，应该是瞬发，GCD时间启动
        gcdtimer = GetTime()
        end
        
        -- 治疗模块施法停止处理
        if AC.Healer and AC.Healer.OnSpellcastStop then
            AC.Healer.OnSpellcastStop()
        end
        
    elseif event == "SPELLCAST_FAILED" then
        if isCast then
            isCast = false
        end
        
        -- 治疗模块施法失败处理
        if AC.Healer and AC.Healer.OnSpellcastFailed then
            AC.Healer.OnSpellcastFailed()
        end
        
    elseif event == "SPELLCAST_INTERRUPTED" then
        if isCast then
            isCast = false
        end
        
        -- 治疗模块施法中断处理
        if AC.Healer and AC.Healer.OnSpellcastInterrupted then
            AC.Healer.OnSpellcastInterrupted()
        end
        
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- 治疗模块法术成功处理
        if AC.Healer and AC.Healer.OnSpellcastSucceeded then
            AC.Healer.OnSpellcastSucceeded(arg1, arg2, arg3, arg4, arg5)
        end


    -- 回能量事件处理
    elseif event == "UNIT_ENERGY" and arg1 == "player" then
        local e = UnitMana("player")
        if e < 100 then -- 防止获取到蓝
            local Difference = e-AC.Event.oldEnergy
            --message("起始"..AC.Event.oldEnergy.."  当前"..e.."  差值"..Difference)
            AC.Event.oldEnergy = e

            -- 重置回能时间节点
            if Difference <= 20 then
                AC.Event.restoredEnergyTime = GetTime()
            end
        end



    -- 施法、攻击事件处理
    elseif event == "UNIT_CASTEVENT" then

        -- 施法事件监测
        if arg3 == "START" then
            AC.Event.castStartTime[arg1] = arg5

        elseif arg3 == "CAST" then
            -- 用于打断
            if AC.Event.castStartTime[arg1] then
                AC.Event.castStartTime[arg1] = nil
            end

            -- 监控双流血
            -- 扫击
            if arg4 == 9904 then
                AC.Event.rakeDelayTime[arg2] = GetTime()
                AC.Event.lastRakeTime = GetTime() -- 记录上次扫击时间
            -- 撕扯
            elseif arg4 == 9896 then
                AC.Event.ripDelayTime[arg2] = GetTime()
                AC.Event.lastRipTime = GetTime() -- 记录上次撕扯时间
            -- 会重置普攻的技能（针对职业：战士）
            -- 英勇打击或顺劈斩
            elseif arg4 == 25286 or arg4 == 20569 then
                -- 记录挥击开始时间
                AC.Event.mainHandBeginTime = GetTime()
                -- 记录挥击时的普攻总时长
                AC.Event.mainHandDuration = UnitAttackSpeed("player")
            end

        elseif arg3 == "FAIL" and AC.Event.castStartTime[arg1] then
            AC.Event.castStartTime[arg1] = nil

        -- 挥击监测，这里只监测主手武器
        elseif arg3 == "MAINHAND" then
            -- 记录挥击开始时间
            AC.Event.mainHandBeginTime = GetTime()
            -- 记录挥击时的普攻总时长
            AC.Event.mainHandDuration = UnitAttackSpeed("player")
        end




-- SpellStatus_SpellCastInstant 和 SpecialEvents_UnitBuffGained 事件
-- 现在通过AceEvent在CatBear.lua中直接注册和处理

-- 战斗日志事件处理
elseif event == "RAW_COMBATLOG" then

    -- 分发给熊德模块处理
    if AC.Bear and AC.Bear.OnRawCombatLog then
        AC.Bear:OnRawCombatLog(arg1, arg2, arg3, arg4, arg5)
    end

    -- 攻击
    if arg1 == "CHAT_MSG_SPELL_SELF_DAMAGE" then

        if string.find( arg2, "你的扫击.*招架.*" ) or string.find( arg2, "你的扫击.*躲闪.*" ) or string.find( arg2, "你的扫击.*格挡.*" ) or string.find( arg2, "你的扫击.*没有击中.*" ) then
            local targetGUID = string.match(arg2,"0x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x")
            if AC.Event.rakeDelayTime[targetGUID] then
                local timer = GetTime() - AC.Event.rakeDelayTime[targetGUID]
                if timer <= AC.Event.bleenCheckDelay then
                    AC.Event.rakeDelayTime[targetGUID] = nil
                end
            end
        end

        if string.find( arg2, "你的撕扯.*招架.*" ) or string.find( arg2, "你的撕扯.*躲闪.*" ) or string.find( arg2, "你的撕扯.*格挡.*" ) or string.find( arg2, "你的撕扯.*没有击中.*" ) then
            local targetGUID = string.match(arg2,"0x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x")
            if AC.Event.ripDelayTime[targetGUID] then
                local timer = GetTime() - AC.Event.ripDelayTime[targetGUID]
                if timer <= AC.Event.bleenCheckDelay then
                    AC.Event.ripDelayTime[targetGUID] = nil
                end
            end
        end
    end
end
end

local interval = 0.05  -- 轮询间隔（秒）
local elapsed = 0

-- 轮询更新函数
function AC.EventHandlers.OnUpdate()
local begin_timer = GetTime()
local timer = begin_timer - AC.Event.restoredEnergyTime
if timer >= 2.0 then
    AC.Event.restoredEnergyTime = begin_timer
end

-- 更新德鲁伊蓝量
local manaMax = UnitManaMax("player")
if manaMax > 100 then
    AC.Config.manaValue = UnitMana("player")
end
end

-- 本地Update函数，用于Frame
local function OnUpdate()
elapsed = elapsed + arg1
if elapsed >= interval then
    elapsed = 0  -- 重置计时器
    AC.EventHandlers.OnUpdate()  -- 调用轮询函数
end
end

-- 设置事件处理函数
frame:SetScript("OnEvent", function() AC.EventHandlers.OnEvent() end)
frame:SetScript("OnUpdate", OnUpdate)


-- 获取当前回能时间（盗贼、猫德使用）
-- 注：双流血猫德不建议使用
function AC.Event.GetRestoredEnergy()
    local timer = GetTime() - AC.Event.restoredEnergyTime
    return timer
end

-- 获取当前技能GCD
-- 适用于瞬发技能，读条技能不适用
function AC.Event.GetGCD()
    return GetTime() - AC.Event.gcdTimer
end

-- 获取当前目标是否有扫击效果
-- 注：优先使用Cursive插件，其次SuperWow支持更加准确
function AC.Event.GetRakeDot()
    -- 优先检测是否有Cursive插件（需要SuperWow支持获取GUID）
    if Cursive and Cursive.curses and AC.Event.superWowEnabled then
        local a, guid = UnitExists("target")
        if guid then
            return Cursive.curses:HasCurse("扫击", guid)
        end
    end

    -- 检测是否有SuperWow模组
    if not AC.Event.superWowEnabled then
        local hasRakeBuff = AC.Lib.Buff("扫击", "target")
        -- 如果没有扫击buff且上次扫击超过5秒，返回false强制补扫击
        if not hasRakeBuff and (GetTime() - AC.Event.lastRakeTime) > 5 then
            return false
        end
        return hasRakeBuff
    end

    -- 获取目标GUID，并确保其存在
    local a, guid = UnitExists("target")
    if not guid then
        return false
    end

    -- 0.3秒监测期里
    if AC.Event.rakeDelayTime[guid] then
        local timer = GetTime() - AC.Event.rakeDelayTime[guid]
        if timer <= AC.Event.bleenCheckDelay then
            -- 还在等待认证期
            return AC.Event.GetRakeDotCheck(guid)
        else
            -- 已经过了认证期
            AC.Event.rakeCheck[guid] = AC.Event.rakeDelayTime[guid]
        end
    end

    local hasRake = AC.Event.GetRakeDotCheck(guid)
    
    -- 兜底逻辑：如果SuperWow检测不到扫击且上次扫击超过5秒，强制返回false
    if not hasRake and (GetTime() - AC.Event.lastRakeTime) > 5 then
        return false
    end
    
    return hasRake
end

function AC.Event.GetRakeDotCheck(guid)
    if AC.Event.rakeCheck[guid] then
        local timer = GetTime() - AC.Event.rakeCheck[guid]
        if timer < (AC.Config.rakeDuration - AC.Event.dotDurationDelay) then
            return true
        end
    end

    return false
end

-- 获取当前目标是否有撕扯效果
-- 注：优先使用Cursive插件，其次SuperWow支持更加准确
function AC.Event.GetRipDot()
    -- 优先检测是否有Cursive插件（需要SuperWow支持获取GUID）
    if Cursive and Cursive.curses and AC.Event.superWowEnabled then
        local a, guid = UnitExists("target")
        if guid then
            return Cursive.curses:HasCurse("撕扯", guid)
        end
    end

    -- 检测是否有SuperWow模组
    if not AC.Event.superWowEnabled then
        local hasRipBuff = AC.Lib.Buff("撕扯", "target")
        -- 如果没有撕扯buff且上次撕扯超过10秒，返回false强制补撕扯
        if not hasRipBuff and (GetTime() - AC.Event.lastRipTime) > 10 then
            return false
        end
        return hasRipBuff
    end

    -- 获取目标GUID，并确保其存在
    local a, guid = UnitExists("target")
    if not guid then
        return false
    end

    -- 0.3秒监测期里
    if AC.Event.ripDelayTime[guid] then
        local timer = GetTime() - AC.Event.ripDelayTime[guid]
        if timer <= AC.Event.bleenCheckDelay then
            -- 还在等待认证期
            return AC.Event.GetRipDotCheck(guid)
        else
            -- 已经过了认证期
            AC.Event.ripCheck[guid] = AC.Event.ripDelayTime[guid]
        end
    end

    local hasRip = AC.Event.GetRipDotCheck(guid)
    
    -- 兜底逻辑：如果SuperWow检测不到撕扯且上次撕扯超过10秒，强制返回false
    if not hasRip and (GetTime() - AC.Event.lastRipTime) > 10 then
        return false
    end
    
    return hasRip
end

function AC.Event.GetRipDotCheck(guid)
    if AC.Event.ripCheck[guid] then
        local timer = GetTime() - AC.Event.ripCheck[guid]
        if timer < (AC.Config.ripDuration - AC.Event.dotDurationDelay) then
            return true
        end
    end

    return false
end


-- 获取目标的朝向
function AC.Event.CheckBehind(value)
    -- 检测异常捕获的方向错误
    if AC.Event.errorBehind == false then
        if GetTime() - AC.Event.errorBehindTimer > 1.2 then
            AC.Event.errorBehind = true
        else
            return false
        end
    end

    -- 任意参数，则不进行UnitXP调用，用于特殊情况下，UnitXP无法正常使用下的临时处理
    if value == 0 then
        return true
    end

    -- 如果UnityXP模组存在，通过模组返回
    if UnitXP_SP3 then
        return UnitXP("behind", "player", "target")
    end

    return true
end

-- 获取目标是否正在施法
-- 注：需要SuperWow支持
function AC.Event.TargetCast()
    -- 检测是否有SuperWow模组
    if not AC.Event.superWowEnabled then
        return false
    end

    -- 获取目标GUID，并确保其存在
    local a, guid = UnitExists("target")
    if not guid then
        return false
    end

    if AC.Event.castStartTime[guid] ~= nil then
        return true
    end

    return false
end

-- 获取普攻剩余时间（主手）
function AC.Event.GetMainHandLeft()
    local t = GetTime() - AC.Event.mainHandBeginTime
    local left = AC.Event.mainHandDuration - t;

    if left < 0 then
        return 0
    end

    return left
end

-- 获取法术索引
-- name: 法术名称
-- rank: 法术等级，可选
-- 返回: 法术索引，如果未找到返回nil
function AC.Event.GetSpellIndex(name, rank)
    local i = 1
    local spellName, spellRank
    
    while true do
        spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
        
        if not spellName or spellName == "" then
            break
        end
        
        if spellName == name then
            if not rank or spellRank == rank then
                return i
            end
        end
        
        i = i + 1
    end
    
    return nil
end

-- 检查单位是否有特定光环
-- name: 光环名称
-- unit: 单位ID，默认为"player"
-- 返回: 有光环返回true，否则返回false
function AC.Event.UnitHasAura(unit, name)
    unit = unit or "player"
    
    local i = 1
    while UnitBuff(unit, i) do
        local buffTexture = UnitBuff(unit, i)
        CatPlusTooltip:ClearLines()
        CatPlusTooltip:SetUnitBuff(unit, i)
        local buffName = CatPlusTooltipTextLeft1:GetText()
        
        if buffName == name then
            return true
        end
        
        i = i + 1
    end
    
    i = 1
    while UnitDebuff(unit, i) do
        local debuffTexture = UnitDebuff(unit, i)
        CatPlusTooltip:ClearLines()
        CatPlusTooltip:SetUnitDebuff(unit, i)
        local debuffName = CatPlusTooltipTextLeft1:GetText()
        
        if debuffName == name then
            return true
        end
        
        i = i + 1
    end
    
    return false
end

-- 记录扫击施放时间（供外部调用）
function AC.Event.RecordRakeCast()
    AC.Event.lastRakeTime = GetTime()
end

-- 获取距离上次扫击的时间
function AC.Event.GetTimeSinceLastRake()
    return GetTime() - AC.Event.lastRakeTime
end

-- 统一事件管理函数
function AC.Event.UnregisterAllEvents()
    -- 注销标准事件（frame会在游戏结束时自动清理）
    if frame then
        frame:UnregisterAllEvents()
    end
end

-- 设置事件处理函数
frame:SetScript("OnEvent", function() AC.EventHandlers.OnEvent() end)

-- CatEvent.lua 文件结尾