-- 确保AutoCat对象已创建
AutoCat = AutoCat or {}
local AC = AutoCat -- 简写以方便引用

-- 初始化治疗相关的命名空间
AC.Healer = AC.Healer or {} -- 治疗相关函数

-- 治疗模块调试函数（使用Cat的原版方式）
function AC.Healer.IsDebugging()
	return Cat and Cat:IsDebugging()
end

function AC.Healer.GetDebugLevel()
	return Cat and Cat:GetDebugLevel() or 2
end

function AC.Healer.DebugPrint(level, message, ...)
	if not AC.Healer.IsDebugging() or level > AC.Healer.GetDebugLevel() then
		return
	end
	
	local formattedMessage
	if message and arg and getn(arg) > 0 then
		formattedMessage = string.format(message, unpack(arg))
	else
		formattedMessage = tostring(message or "")
	end
	-- 使用Cat的调试系统
	if Cat and Cat:IsDebugging() then
		DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Healer Debug:|r " .. formattedMessage)
	end
end

-- 获取愈合等级配置
function AC.Healer.GetRejuvRank()
    return AutoCat.Options.rejuvRank or 6
end

-- 检查是否启用自动治疗
-- function AC.Healer.IsAutoHealEnabled()
--     return AutoCat.Options.autoHeal == 1
-- end

-- 黑名单系统和施法状态跟踪
AC.Healer.blacklist = {} -- 治疗黑名单
AC.Healer.pendingCast = nil -- 当前待确认的施法
AC.Healer.castTimeout = 0 -- 施法超时时间
AC.Healer.lastErrorTime = 0 -- 最后错误时间，避免重复处理
AC.Healer.eventFrame = nil -- 事件监听帧
AC.Healer.isAsyncHealing = false -- 是否正在异步治疗中

-- 检查是否正在施法
function AC.Healer.IsCasting()
    -- WoW 1.12版本中检查施法状态的方法
    
    -- 方法1：检查施法条
    local castingBarVisible = false
    if CastingBarFrame then
        castingBarVisible = CastingBarFrame:IsVisible()
        if castingBarVisible and AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(3, "检测到施法条可见")
        end
    end
    
    -- 方法2：检查目标选择状态
    local targeting = SpellIsTargeting()
    if targeting and AC.Healer.IsDebugging() then
        AC.Healer.DebugPrint(3, "检测到目标选择状态")
    end
    
    -- 方法3：检查全局变量（1.12可能存在的）
    local globalCasting = false
    if CastingInfo then
        globalCasting = true
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(3, "检测到CastingInfo")
        end
    end
    
    -- 方法4：检查是否有延迟的施法命令正在处理
    -- 在某些情况下，施法可能有延迟
    
    local isCasting = castingBarVisible or targeting or globalCasting
    
    if AC.Healer.IsDebugging() then
        AC.Healer.DebugPrint(3, "施法状态检查详细 - 施法条: %s, 目标选择: %s, 全局施法: %s, 结果: %s", tostring(castingBarVisible), tostring(targeting), tostring(globalCasting), tostring(isCasting))
    end
    
    return isCasting
end

-- 检查单位是否有效
function AC.Healer.IsValidTarget(unit)
    return UnitExists(unit) and 
           not UnitIsDeadOrGhost(unit) and 
           UnitIsVisible(unit)
end

-- 改进的黑名单管理：根据错误类型设置不同时间
function AC.Healer.AddToBlacklist(unit, errorType)
    local name = UnitName(unit)
    if not name then return end
    
    local blacklistTime = 5 -- 默认5秒
    
    -- 根据错误类型调整黑名单时间
    if errorType == "range" then
        blacklistTime = 3    -- 距离问题短一些
    elseif errorType == "los" then
        blacklistTime = 8    -- 视线问题长一些
    elseif errorType == "invalid" then
        blacklistTime = 10   -- 目标无效长一些
    elseif errorType == "dead" then
        blacklistTime = 15   -- 死亡状态长一些
    end
    
    AC.Healer.blacklist[name] = GetTime() + blacklistTime
    
    if AC.Healer.IsDebugging() then
        AC.Healer.DebugPrint(2, "将 %s 加入治疗黑名单%d秒 (原因: %s)", name, blacklistTime, errorType)
    end
end

-- 检查单位是否在黑名单中
function AC.Healer.IsBlacklisted(unit)
    local name = UnitName(unit)
    if not name then
        return false
    end
    
    if AC.Healer.blacklist[name] then
        -- 检查黑名单是否已过期
        if GetTime() > AC.Healer.blacklist[name] then
            AC.Healer.blacklist[name] = nil
            return false
        end
        return true
    end
    
    return false
end

-- 清理过期黑名单并动态调整
function AC.Healer.UpdateBlacklist()
    local currentTime = GetTime()
    for name, expireTime in pairs(AC.Healer.blacklist) do
        if currentTime > expireTime then
            AC.Healer.blacklist[name] = nil
        end
    end
end

-- 获取所有需要治疗的目标列表，按优先级排序
function AC.Healer.GetHealTargets()
    -- 清理过期黑名单
    AC.Healer.UpdateBlacklist()
    
    local targets = {}
    
    -- 检查团队成员
    local numRaidMembers = GetNumRaidMembers()
    if numRaidMembers > 0 then
        -- 在团队中循环
        for i = 1, numRaidMembers do
            local unit = "raid"..i
            if AC.Healer.IsValidTarget(unit) and not AC.Healer.IsBlacklisted(unit) then
                -- 使用UnitXP_SP3计算距离，超过40码的不加入治疗列表
                local distance = UnitXP and UnitXP("distanceBetween", "player", unit) or nil
                if distance and distance <= 40 then
                    local currentHealth = UnitHealth(unit)
                    local maxHealth = UnitHealthMax(unit)
                    local healthLost = maxHealth - currentHealth
                    local hasRejuvenation = AC.Lib.Buff("愈合", unit)
                    local hasClawBlessing = AC.Lib.Buff("利爪祝福", unit)
                    
                    -- 过滤条件：
                    -- 1. 满血且有愈合或利爪祝福buff的不加入治疗列表
                    -- 2. 有利爪祝福且失血量少于400的不加入治疗列表
                    if (healthLost == 0 and (hasRejuvenation or hasClawBlessing)) or
                       (hasClawBlessing and healthLost < 400) then
                        -- 跳过此目标
                    else
                        -- 添加到目标列表，记录优先级信息
                        table.insert(targets, {
                            unit = unit,
                            healthLost = healthLost,
                            hasRejuvenation = hasRejuvenation,
                            priority = healthLost > 0 and 1 or (not hasRejuvenation and 2 or 3)
                        })
                    end
                else
                    -- 距离过远或无法计算距离，跳过此目标
                    if AC.Healer.IsDebugging() then
                        if not distance then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd"..UnitName(unit).." 无法计算距离，跳过治疗|r")
                        else
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd"..UnitName(unit).." 距离"..string.format("%.1f", distance).."码，超过40码，跳过治疗|r")
                        end
                    end
                end
            end
        end
    else
        -- 在小队中循环
        local numPartyMembers = GetNumPartyMembers()
        for i = 1, numPartyMembers do
            local unit = "party"..i
            if AC.Healer.IsValidTarget(unit) and not AC.Healer.IsBlacklisted(unit) then
                -- 使用UnitXP_SP3计算距离，超过40码的不加入治疗列表
                local distance = UnitXP and UnitXP("distanceBetween", "player", unit) or nil
                if distance and distance <= 40 then
                    local currentHealth = UnitHealth(unit)
                    local maxHealth = UnitHealthMax(unit)
                    local healthLost = maxHealth - currentHealth
                    local hasRejuvenation = AC.Lib.Buff("愈合", unit)
                    local hasClawBlessing = AC.Lib.Buff("利爪祝福", unit)
                    
                    -- 过滤条件：
                    -- 1. 满血且有愈合或利爪祝福buff的不加入治疗列表
                    -- 2. 有利爪祝福且失血量少于400的不加入治疗列表
                    if (healthLost == 0 and (hasRejuvenation or hasClawBlessing)) or
                       (hasClawBlessing and healthLost < 400) then
                        -- 跳过此目标
                    else
                        table.insert(targets, {
                            unit = unit,
                            healthLost = healthLost,
                            hasRejuvenation = hasRejuvenation,
                            priority = healthLost > 0 and 1 or (not hasRejuvenation and 2 or 3)
                        })
                    end
                else
                    -- 距离过远或无法计算距离，跳过此目标
                    if AC.Healer.IsDebugging() then
                        if not distance then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd"..UnitName(unit).." 无法计算距离，跳过治疗|r")
                        else
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd"..UnitName(unit).." 距离"..string.format("%.1f", distance).."码，超过40码，跳过治疗|r")
                        end
                    end
                end
            end
        end
        
        -- 检查自己（自己不需要距离检查）
        if AC.Healer.IsValidTarget("player") and not AC.Healer.IsBlacklisted("player") then
            local currentHealth = UnitHealth("player")
            local maxHealth = UnitHealthMax("player")
            local healthLost = maxHealth - currentHealth
            local hasRejuvenation = AC.Lib.Buff("愈合", "player")
            local hasClawBlessing = AC.Lib.Buff("利爪祝福", "player")
            
            -- 过滤条件：
            -- 1. 满血且有愈合或利爪祝福buff的不加入治疗列表
            -- 2. 有利爪祝福且失血量少于400的不加入治疗列表
            if (healthLost == 0 and (hasRejuvenation or hasClawBlessing)) or
               (hasClawBlessing and healthLost < 400) then
                -- 跳过此目标
            else
                table.insert(targets, {
                    unit = "player",
                    healthLost = healthLost,
                    hasRejuvenation = hasRejuvenation,
                    priority = healthLost > 0 and 1 or (not hasRejuvenation and 2 or 3)
                })
            end
        end
    end
    
    -- 按优先级排序：优先级1（掉血的）> 优先级2（没愈合buff的）> 优先级3（其他）
    -- 同优先级内按掉血量排序
    table.sort(targets, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        else
            return a.healthLost > b.healthLost
        end
    end)
    
    return targets
end

-- 改进的施法函数：使用事件监听机制
function AC.Healer.CastRejuvenation(target, callback)
    if not target then
        if callback then callback(false) end
        return false
    end
    
    if AC.Healer.IsDebugging() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd开始对 "..UnitName(target).." 施放愈合|r")
    end
    
    -- 施法前检查
    if AC.Healer.IsCasting() then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "当前正在施法中，无法开始新的施法")
        end
        if callback then callback(false) end
        return false
    end
    
    -- 检查法力值
    local currentMana = UnitMana("player")
    local maxMana = UnitManaMax("player")
    if AC.Healer.IsDebugging() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd当前法力: "..currentMana.."/"..maxMana.."|r")
    end
    
    -- 检查愈合法术是否可用
    local currentRank = AC.Healer.GetRejuvRank()
    local rejuvName = "愈合(等级 " .. currentRank .. ")"
    local rejuvIndex = AC.Event and AC.Event.GetSpellIndex and AC.Event.GetSpellIndex("愈合", "等级 " .. currentRank)
    
    if AC.Healer.IsDebugging() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd愈合法术检查 - 法术名: "..rejuvName..", 索引: "..(rejuvIndex or "无").."|r")
    end
    
    -- 记录施法前的状态
    local preCastMana = UnitMana("player")
    local preCastHasRejuv = AC.Lib.Buff("愈合", target)
    
    if AC.Healer.IsDebugging() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd施法前状态 - 法力: "..preCastMana..", 目标有愈合: "..tostring(preCastHasRejuv).."|r")
    end
    
    -- 清理之前的状态
    if AC.Healer.pendingCast then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "清理之前的待确认施法状态")
        end
        AC.Healer.pendingCast = nil
    end
    
    -- 停止之前的异步检查
    if AC.Healer.eventFrame and AC.Healer.eventFrame.checkCallback then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "停止之前的事件监听")
        end
        AC.Healer.eventFrame.checkCallback = nil
    end
    
    -- 保存当前目标
    local originalTarget = UnitName("target")
    if AC.Healer.IsDebugging() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd保存原目标: "..(originalTarget or "无").."|r")
    end
    
    -- 选中治疗目标
    if AC.Healer.IsDebugging() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd选择目标: "..UnitName(target).."|r")
    end
    TargetUnit(target)
    
    -- 确认目标已被选中
    local currentTargetName = UnitName("target")
    if currentTargetName ~= UnitName(target) then
        if AC.Healer.IsDebugging() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd目标选择失败，当前目标: "..(currentTargetName or "无")..", 期望目标: "..UnitName(target).."|r")
        end
        if callback then callback(false) end
        return false
    end
    
    -- 设置施法状态跟踪
    AC.Healer.pendingCast = {
        target = target,
        spell = "愈合",
        startTime = GetTime(),
        targetName = UnitName(target),  -- 保存目标名称用于调试
        preCastMana = preCastMana,
        preCastHasRejuv = preCastHasRejuv
    }
    AC.Healer.castTimeout = GetTime() + 2 -- 2秒超时
    
    if AC.Healer.IsDebugging() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd设置待确认施法状态，目标: "..AC.Healer.pendingCast.targetName..", 开始时间: "..string.format("%.2f", AC.Healer.pendingCast.startTime).."|r")
    end
    
    -- 施放愈合 - 尝试多种方法
    local castSuccess = false
    local castMethod = ""
    
    -- 方法1：使用法术索引（如果可用）
    if rejuvIndex and rejuvIndex > 0 then
        if AC.Healer.IsDebugging() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd尝试方法1：使用法术索引 "..rejuvIndex.."|r")
        end
        CastSpell(rejuvIndex, BOOKTYPE_SPELL)
        castSuccess = true
        castMethod = "索引"
    else
        -- 方法2：使用法术名称
        if AC.Healer.IsDebugging() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd尝试方法2：使用法术名称 "..rejuvName.."|r")
        end
        CastSpellByName(rejuvName)
        castSuccess = true
        castMethod = "名称"
    end
    
    if AC.Healer.IsDebugging() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd施法命令已执行，方法: "..castMethod.."|r")
    end
    
    -- 如果有回调函数，启动事件监听
    if callback then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "启动事件监听")
        end
        
        AC.Healer.StartEventBasedSpellCheck(target, function(success)
            -- 进行更详细的成功验证
            local actualSuccess = success
            
            if success then
                -- 额外验证：检查buff是否真的被应用
                local postCastHasRejuv = AC.Lib.Buff("愈合", target)
                local postCastMana = UnitMana("player")
                local manaUsed = AC.Healer.pendingCast and (AC.Healer.pendingCast.preCastMana - postCastMana) or 0
                
                if AC.Healer.IsDebugging() then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd施法后验证 - 目标有愈合: "..tostring(postCastHasRejuv)..", 消耗法力: "..manaUsed.."|r")
                end
                
                -- 如果目标之前没有愈合buff，现在应该有
                if AC.Healer.pendingCast and not AC.Healer.pendingCast.preCastHasRejuv and not postCastHasRejuv then
                    if AC.Healer.IsDebugging() then
                        AC.Healer.DebugPrint(2, "警告：未检测到愈合buff被应用，但事件显示成功")
                    end
                    -- 这里不修改actualSuccess，相信事件的结果
                end
            end
            
            -- 确保清除待确认状态
            if AC.Healer.pendingCast and AC.Healer.pendingCast.target == target then
                if AC.Healer.IsDebugging() then
                    AC.Healer.DebugPrint(2, "清除待确认状态")
                end
                AC.Healer.pendingCast = nil
            end
            
            -- 恢复原目标
            if originalTarget and originalTarget ~= UnitName(target) then
                AC.Healer.RestoreTarget(originalTarget)
                if AC.Healer.IsDebugging() then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd恢复原目标: "..originalTarget.."|r")
                end
            end
            
            if AC.Healer.IsDebugging() then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd事件监听最终结果: "..tostring(actualSuccess).."|r")
            end
            
            callback(actualSuccess)
        end)
        return true -- 表示异步处理中
    else
        -- 同步模式（向后兼容）
        local success = AC.Healer.CheckSpellCastResult(target)
        
        if AC.Healer.IsDebugging() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd施法结果: "..tostring(success).."|r")
        end
        
        -- 恢复原目标
        if originalTarget and originalTarget ~= UnitName(target) then
            AC.Healer.RestoreTarget(originalTarget)
            if AC.Healer.IsDebugging() then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd恢复原目标: "..originalTarget.."|r")
            end
        end
        
        return success
    end
end

-- 新增：检查施法结果的函数
function AC.Healer.CheckSpellCastResult(target)
    if AC.Healer.IsDebugging() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd开始检查施法结果，目标: "..UnitName(target).."|r")
    end
    
    -- 检查是否需要目标选择
    if SpellIsTargeting() then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "需要目标选择，正在选择目标")
        end
        
        -- 尝试选择目标
        SpellTargetUnit(target)
        
        -- 短暂等待让系统处理
        local waitTime = GetTime() + 0.05
        while GetTime() < waitTime do
            -- 短暂等待
        end
        
        if SpellIsTargeting() then
            -- 仍然在等待目标，说明目标选择失败
            if AC.Healer.IsDebugging() then
                AC.Healer.DebugPrint(2, "目标选择失败，仍在等待目标状态")
            end
            
            SpellStopTargeting()
            AC.Healer.AddToBlacklist(target, "invalid")
            AC.Healer.pendingCast = nil
            
            if AC.Healer.IsDebugging() then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd对 "..UnitName(target).." 目标选择失败，已加入黑名单|r")
            end
            return false
        else
            if AC.Healer.IsDebugging() then
                AC.Healer.DebugPrint(2, "目标选择成功")
            end
        end
    else
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "无需目标选择，直接施法")
        end
    end
    
    -- 增加等待时间到0.5秒来确保捕获所有错误消息
    local checkTime = GetTime() + 0.5
    if AC.Healer.IsDebugging() then
        AC.Healer.DebugPrint(2, "等待0.5秒检查错误消息")
    end
    
    while GetTime() < checkTime do
        -- 在等待期间检查是否有新的错误
        if AC.Healer.lastErrorTime > AC.Healer.pendingCast.startTime then
            -- 有新的错误产生，施法失败
            if AC.Healer.IsDebugging() then
                AC.Healer.DebugPrint(2, "检测到新的错误，施法失败")
            end
            AC.Healer.pendingCast = nil
            return false
        end
    end
    
    -- 清除待确认状态
    if AC.Healer.IsDebugging() then
        AC.Healer.DebugPrint(2, "未检测到错误，施法成功")
    end
    AC.Healer.pendingCast = nil
    return true
end

-- 恢复原目标
function AC.Healer.RestoreTarget(targetName)
    -- 尝试重新选择原目标
    local numRaidMembers = GetNumRaidMembers()
    if numRaidMembers > 0 then
        for i = 1, numRaidMembers do
            if UnitName("raid"..i) == targetName then
                TargetUnit("raid"..i)
                return
            end
        end
    else
        for i = 1, GetNumPartyMembers() do
            if UnitName("party"..i) == targetName then
                TargetUnit("party"..i)
                return
            end
        end
        if UnitName("player") == targetName then
            TargetUnit("player")
        end
    end
end

-- 主要的治疗函数
function AC.Healer.Heal()
    if AC.Healer.IsDebugging() then
        AC.Healer.DebugPrint(2, "开始执行治疗功能")
    end
    
    -- 如果正在异步治疗中，不执行治疗
    if AC.Healer.isAsyncHealing then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "正在异步治疗中，跳过治疗")
        end
        return false
    end
    
    -- 如果正在施法，不执行治疗
    if AC.Healer.IsCasting() then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "正在施法中，跳过治疗")
        end
        return false
    end
    
    -- 检查是否有超时的施法
    if AC.Healer.pendingCast and GetTime() > AC.Healer.castTimeout then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "施法超时，清除待确认状态")
        end
        AC.Healer.pendingCast = nil
    end
    
    -- 获取所有治疗目标，按优先级排序
    local targets = AC.Healer.GetHealTargets()
    if getn(targets) == 0 then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "没有找到需要治疗的目标")
        end
        return false
    end
    
    -- 设置异步治疗状态
    AC.Healer.isAsyncHealing = true
    
    -- 使用异步模式逐个尝试治疗目标
    AC.Healer.TryHealTargets(targets, 1)
    return true
end

-- 新增：异步治疗目标处理函数
function AC.Healer.TryHealTargets(targets, index)
    if index > getn(targets) then
        -- 所有目标都尝试完了，清除异步状态
        AC.Healer.isAsyncHealing = false
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "没有找到有效的治疗目标")
        end
        return
    end
    
    if AC.Healer.IsDebugging() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd准备处理目标 "..index.." / "..getn(targets).."|r")
    end
    
    -- 检查是否仍在施法中
    if AC.Healer.IsCasting() then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "仍在施法中，结束本次调用")
        end
        AC.Healer.isAsyncHealing = false
        return
    end
    
    local targetInfo = targets[index]
    local target = targetInfo.unit
    
    -- 再次检查目标是否仍然有效（可能状态已改变）
    if not AC.Healer.IsValidTarget(target) then
        if AC.Healer.IsDebugging() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd目标 "..UnitName(target).." 已无效，尝试下一个|r")
        end
        -- 尝试下一个目标
        AC.Healer.TryHealTargets(targets, index + 1)
        return
    end
    
    -- 检查目标是否在黑名单中（可能在等待期间被加入）
    if AC.Healer.IsBlacklisted(target) then
        if AC.Healer.IsDebugging() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd目标 "..UnitName(target).." 在黑名单中，尝试下一个|r")
        end
        -- 尝试下一个目标
        AC.Healer.TryHealTargets(targets, index + 1)
        return
    end
    
    if AC.Healer.IsDebugging() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd尝试治疗目标 "..index..": "..UnitName(target)..", 掉血: "..targetInfo.healthLost..", 优先级: "..targetInfo.priority.."|r")
    end
    
    -- 使用异步模式施法，但只处理当前目标
    AC.Healer.CastRejuvenation(target, function(success)
        if AC.Healer.IsDebugging() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd目标 "..index.." ("..UnitName(target)..") 异步回调触发，结果: "..tostring(success).."|r")
        end
        
        -- 无论成功还是失败，都清除异步状态，结束本次调用
        AC.Healer.isAsyncHealing = false
        
        if success then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Tip:|r |cFFf9cdfd成功对 "..UnitName(target).." 施放愈合|r")
        else
            if AC.Healer.IsDebugging() then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd对 "..UnitName(target).." 施法失败，等待下次调用处理其他目标|r")
            end
            -- 失败的目标已经在CastRejuvenation中被加入黑名单
            -- 不需要在这里继续处理下一个目标，让下次高频调用来处理
        end
    end)
    
    if AC.Healer.IsDebugging() then
        AC.Healer.DebugPrint(2, "已调用CastRejuvenation，等待异步结果")
    end
end

-- 定义公共函数，可以被外部调用
function HealCat()
    AC.Healer.Heal()
end

-- 注册独立的斜杠命令
SLASH_HEALREJ1 = "/healrej"
SLASH_HEALREJ2 = "/rejuv"

-- 处理斜杠命令
SlashCmdList["HEALREJ"] = function(msg)
    if not msg or msg == "" then
        -- 默认执行治疗
        AC.Healer.Heal()
    else
        local command, param = string.match(msg, "^(%S+)%s*(.*)$")
        command = string.lower(command or "")
        
        if command == "rank" then
            -- 设置愈合等级
            AC.Healer.SetRejuvRank(param)
        elseif command == "help" then
            -- 显示帮助信息
            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Help:|r |cFFf9cdfd治疗插件命令帮助|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00/healrej|r |cFFf9cdfd- 执行治疗|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00/healrej rank|r |cFFf9cdfd- 查看当前愈合等级|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00/healrej rank <1-9>|r |cFFf9cdfd- 设置愈合等级|r")
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFFF00/healrej help|r |cFFf9cdfd- 显示帮助信息|r")
        else
            -- 未知命令，执行治疗
            AC.Healer.Heal()
        end
    end
end

-- 输出加载信息
DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Tip:|r |cFFf9cdfd治疗模块已加载，使用 |r|cFFFFFF00/healrej|r |cFFf9cdfd或 |r|cFFFFFF00/script HealCat()|r |cFFf9cdfd来使用团队治疗功能|r")

-- 改进的错误消息处理：参考QuickHeal的分类机制
local originalUIErrorsFrame_OnEvent = UIErrorsFrame_OnEvent
UIErrorsFrame_OnEvent = function(...)
    -- 记录错误时间
    AC.Healer.lastErrorTime = GetTime()
    
    -- 添加事件日志
    if AC.Healer.IsDebugging() then
        if event == "UI_ERROR_MESSAGE" and arg1 then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd收到错误事件: "..tostring(arg1).." (时间: "..string.format("%.2f", AC.Healer.lastErrorTime)..")|r")
        end
    end
    
    -- 检查是否是施法错误且有待确认的施法
    if event == "UI_ERROR_MESSAGE" and arg1 and AC.Healer.pendingCast then
        local errorMsg = arg1
        local target = AC.Healer.pendingCast.target
        local errorType = "unknown"
        local shouldBlacklist = true
        
        if AC.Healer.IsDebugging() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd处理施法错误，目标: "..UnitName(target)..", 错误消息: "..errorMsg.."|r")
        end
        
        -- 分析错误类型并设置相应的黑名单时间
        if string.find(errorMsg, "范围") or string.find(errorMsg, "距离") or string.find(errorMsg, "Out of range") then
            errorType = "range"
        elseif string.find(errorMsg, "视线") or string.find(errorMsg, "视野") or string.find(errorMsg, "阻挡") or 
               string.find(errorMsg, "Line of Sight") or string.find(errorMsg, "line of sight") or
               string.find(errorMsg, "视线被阻挡") or string.find(errorMsg, "看不见目标") then
            errorType = "los"
        elseif string.find(errorMsg, "无效") or string.find(errorMsg, "Invalid target") or
               string.find(errorMsg, "无效的目标") or string.find(errorMsg, "不是有效目标") then
            errorType = "invalid"
        elseif string.find(errorMsg, "死亡") or string.find(errorMsg, "Dead") or
               string.find(errorMsg, "已死亡") or string.find(errorMsg, "目标已死亡") then
            errorType = "dead"
        elseif string.find(errorMsg, "法力") or string.find(errorMsg, "mana") or
               string.find(errorMsg, "法力值不足") or string.find(errorMsg, "Not enough mana") then
            errorType = "mana"
            shouldBlacklist = false -- 法力不足不加入黑名单，只是暂停治疗
            if AC.Healer.IsDebugging() then
                AC.Healer.DebugPrint(2, "法力不足，暂停治疗")
            end
            AC.Healer.pendingCast = nil
            return originalUIErrorsFrame_OnEvent(unpack(arg))
        elseif string.find(errorMsg, "冷却") or string.find(errorMsg, "cooldown") or
               string.find(errorMsg, "正在冷却") or string.find(errorMsg, "Spell is not ready yet") then
            errorType = "cooldown"
        elseif string.find(errorMsg, "打断") or string.find(errorMsg, "interrupted") or
               string.find(errorMsg, "施法被打断") then
            errorType = "interrupted"
            shouldBlacklist = false -- 被打断不加黑名单
        elseif string.find(errorMsg, "移动") or string.find(errorMsg, "moving") or
               string.find(errorMsg, "不能在移动时施法") then
            errorType = "moving"
            shouldBlacklist = false -- 移动中不加黑名单
        else
            -- 未知错误类型，记录完整消息用于调试
            if AC.Healer.IsDebugging() then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd未识别的错误类型，完整消息: '"..errorMsg.."'|r")
            end
        end
        
        if AC.Healer.IsDebugging() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd错误分类结果: "..errorType..", 是否加黑名单: "..tostring(shouldBlacklist).."|r")
        end
        
        -- 根据分析结果处理
        if shouldBlacklist then
            -- 将目标加入黑名单
            AC.Healer.AddToBlacklist(target, errorType)
            
            if AC.Healer.IsDebugging() then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd施法错误: "..errorMsg.." (类型: "..errorType..")，已将 "..UnitName(target).." 加入黑名单|r")
            end
        else
            if AC.Healer.IsDebugging() then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd施法错误: "..errorMsg.." (类型: "..errorType..")，不加入黑名单|r")
            end
        end
        
        -- 清除待确认状态
        AC.Healer.pendingCast = nil
    elseif event == "UI_ERROR_MESSAGE" and arg1 then
        -- 即使没有待确认的施法，也记录错误消息用于调试
        -- 这可能是延迟到达的错误消息
        if AC.Healer.IsDebugging() then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd收到延迟错误消息: "..tostring(arg1).." (无待确认施法)|r")
        end
        
        -- 对于治疗相关的错误，即使延迟也要记录
        local errorMsg = arg1
        if string.find(errorMsg, "范围") or string.find(errorMsg, "距离") or string.find(errorMsg, "Out of range") or
           string.find(errorMsg, "视线") or string.find(errorMsg, "视野") or string.find(errorMsg, "阻挡") or 
           string.find(errorMsg, "Line of Sight") or string.find(errorMsg, "line of sight") or
           string.find(errorMsg, "视线被阻挡") or string.find(errorMsg, "看不见目标") or
           string.find(errorMsg, "无效") or string.find(errorMsg, "Invalid target") then
            
            if AC.Healer.IsDebugging() then
                AC.Healer.DebugPrint(2, "这是一个治疗相关的延迟错误消息")
            end
        end
    end
    
    -- 调用原始函数
    return originalUIErrorsFrame_OnEvent(unpack(arg))
end

-- 创建事件监听帧
local function CreateEventListenerFrame()
    if AC.Healer.eventFrame then
        return AC.Healer.eventFrame
    end
    
    local frame = CreateFrame("Frame")
    frame.checkCallback = nil
    frame.target = nil
    frame.startTime = 0
    frame.eventReceived = false
    frame.eventResult = nil
    frame.eventTime = 0
    
    -- 事件处理已移至CatEvent.lua统一管理
    -- 不再在此处注册事件
    
    -- 异步处理事件结果和超时检查
    frame:SetScript("OnUpdate", function()
        if not frame.checkCallback then
            return
        end
        
        local elapsed = GetTime() - frame.startTime
        
        -- 如果收到了事件，等待0.1秒后处理（让游戏状态完全更新）
        if frame.eventReceived and GetTime() - frame.eventTime >= 0.1 then
            if AC.Healer.IsDebugging() then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd异步处理事件结果: "..tostring(frame.eventResult).."|r")
            end
            
            local callback = frame.checkCallback
            local result = frame.eventResult
            
            -- 清理状态
            frame.checkCallback = nil
            frame.eventReceived = false
            frame.eventResult = nil
            frame.eventTime = 0
            
            if callback then
                callback(result)
            end
            return
        end
        
        -- 超时保护：如果2秒内没有收到任何有效事件，认为施法失败
        if elapsed > 2.0 and not frame.eventReceived then
            if AC.Healer.IsDebugging() then
                AC.Healer.DebugPrint(2, "事件监听超时，认为施法失败")
            end
            
            local callback = frame.checkCallback
            
            -- 清理状态
            frame.checkCallback = nil
            frame.eventReceived = false
            frame.eventResult = nil
            frame.eventTime = 0
            
            if callback then
                callback(false)
            end
        end
    end)
    
    AC.Healer.eventFrame = frame
    return frame
end

-- 基于事件的异步施法结果检查
function AC.Healer.StartEventBasedSpellCheck(target, callback)
    local frame = CreateEventListenerFrame()
    
    -- 停止之前的检查
    if frame.checkCallback then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "停止之前的事件监听")
        end
        frame.checkCallback = nil
    end
    
    frame.startTime = GetTime()
    frame.checkCallback = callback
    frame.target = target
    frame.eventReceived = false
    frame.eventResult = nil
    frame.eventTime = 0
    
    if AC.Healer.IsDebugging() then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r |cFFf9cdfd开始异步事件监听，目标: "..UnitName(target).."|r")
    end
end

-- 设置愈合等级的函数（现在只显示信息，实际设置请使用配置界面）
function AC.Healer.SetRejuvRank(rank)
    if not rank then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Tip:|r |cFFf9cdfd当前愈合等级: "..AC.Healer.GetRejuvRank().."|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Tip:|r |cFFf9cdfd请使用配置界面修改愈合等级设置|r")
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Tip:|r |cFFf9cdfd请使用配置界面修改愈合等级设置|r")
    -- local newRank = tonumber(rank)
    -- if not newRank or newRank < 1 or newRank > 9 then
    --     DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Error:|r |cFFff0000愈合等级必须是1-9之间的数字|r")
    --     return
    -- end
    -- 
    -- AC.Healer.config.rejuvRank = newRank
    -- AC.Healer.defaultRejuvRank = newRank
    -- DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Tip:|r |cFFf9cdfd愈合等级已设置为: "..newRank.."级|r")
end

-- 统一事件处理函数，供CatEvent.lua调用
AC.Healer.OnSpellcastStart = function()
    local frame = AC.Healer.eventFrame
    if frame and frame.checkCallback then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "施法开始事件")
        end
        -- 不立即处理，只记录事件
    end
end

AC.Healer.OnSpellcastStop = function()
    local frame = AC.Healer.eventFrame
    if frame and frame.checkCallback then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "施法完成事件: SPELLCAST_STOP, 将在0.1秒后处理")
        end
        frame.eventReceived = true
        frame.eventResult = true
        frame.eventTime = GetTime()
    end
end

AC.Healer.OnSpellcastFailed = function()
    local frame = AC.Healer.eventFrame
    if frame and frame.checkCallback then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "施法失败事件: SPELLCAST_FAILED, 将在0.1秒后处理")
        end
        frame.eventReceived = true
        frame.eventResult = false
        frame.eventTime = GetTime()
    end
end

AC.Healer.OnSpellcastInterrupted = function()
    local frame = AC.Healer.eventFrame
    if frame and frame.checkCallback then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "施法失败事件: SPELLCAST_INTERRUPTED, 将在0.1秒后处理")
        end
        frame.eventReceived = true
        frame.eventResult = false
        frame.eventTime = GetTime()
    end
end

AC.Healer.OnSpellcastSucceeded = function(unit, spell, rank, target, spellId)
    local frame = AC.Healer.eventFrame
    if frame and frame.checkCallback then
        if AC.Healer.IsDebugging() then
            AC.Healer.DebugPrint(2, "施法完成事件: UNIT_SPELLCAST_SUCCEEDED, 将在0.1秒后处理")
        end
        frame.eventReceived = true
        frame.eventResult = true
        frame.eventTime = GetTime()
    end
end