-- -------------------------------------
-- AutoCat 鸟德功能模块
-- 基于现有猫德和熊德架构
-- -------------------------------------

-- 非德鲁伊退出运行
local _, playerClass = UnitClass("player")
if playerClass ~= "DRUID" then
	return
end

-- 确保AutoCat对象已创建
AutoCat = AutoCat or {}

-- 简写以方便引用
local AC = AutoCat

AC.Bird = AC.Bird or {}
local Bird = AC.Bird

-- 添加调试输出确认模块加载
DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96CatBird:|r 鸟德模块开始加载...")

-- 鸟德不需要额外的库，使用基础游戏API即可

-- 鸟德配置由共通设置管理，无需在此文件中定义

-- Eclipse状态管理（基于昼至/夜至debuff判断等待）
Bird.Eclipse = {
	-- 当前状态："日蚀"、"月蚀" 或 ""
	state = "",
}


-- 检查是否开启调试（直接使用Cat的方式）
function Bird:IsDebugging()
	return Cat and Cat:IsDebugging()
end

-- 调试输出函数（简化版，无等级）
function Bird:DebugPrint(message, ...)
	if not self:IsDebugging() then
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
		DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Bird Debug:|r " .. formattedMessage)
	end
end

-- Eclipse状态管理方法
function Bird:OnEclipseGained(eclipseName)
	self:DebugPrint("获得Eclipse：%s", eclipseName)
	
	-- 更新状态
	self.Eclipse.state = eclipseName
end

function Bird:OnEclipseLost(eclipseName)
	self:DebugPrint("失去Eclipse：%s", eclipseName)
	
	-- 简化处理：状态保持，等待通过debuff判断
	-- self.Eclipse.state 保持不变，通过昼至/夜至debuff判断等待状态
end

-- 检查当前Eclipse状态（基于昼至/夜至debuff判断等待）
function Bird:GetEclipseState()
	-- 直接检查当前的Eclipse buff状态
	local hasSolarEclipse = AC.Lib.Buff("日蚀")
	local hasLunarEclipse = AC.Lib.Buff("月蚀")
	
	-- 检查昼至/夜至debuff状态
	local hasDayfall = AC.Lib.Buff("昼至")  -- 日蚀相关debuff
	local hasNightfall = AC.Lib.Buff("夜至")  -- 月蚀相关debuff
	
	local currentState = ""
	local isWaiting = false
	
	if hasSolarEclipse then
		-- 有日蚀buff：正常日蚀期
		currentState = "日蚀"
		isWaiting = false
	elseif hasLunarEclipse then
		-- 有月蚀buff：正常月蚀期
		currentState = "月蚀"
		isWaiting = false
	elseif hasDayfall and not hasSolarEclipse then
		-- 有昼至debuff但没有日蚀buff：日蚀等待期
		currentState = "日蚀"
		isWaiting = true
	elseif hasNightfall and not hasLunarEclipse then
		-- 有夜至debuff但没有月蚀buff：月蚀等待期
		currentState = "月蚀"
		isWaiting = true
	else
		-- 无Eclipse状态
		currentState = ""
		isWaiting = false
	end
	
	-- 更新内部状态
	self.Eclipse.state = currentState
	
	return currentState, isWaiting
end

-- 检查Eclipse buff状态变化（由UNIT_AURA事件触发）
function Bird:CheckEclipseBuffs()
	-- 检查当前的Eclipse buff状态
	local hasSolarEclipse = AC.Lib.Buff("日蚀")
	local hasLunarEclipse = AC.Lib.Buff("月蚀")
	
	-- 确定当前应该有的状态
	local currentBuffState = ""
	if hasSolarEclipse then
		currentBuffState = "日蚀"
	elseif hasLunarEclipse then
		currentBuffState = "月蚀"
	end
	
	-- 检查状态变化
	if currentBuffState ~= self.Eclipse.state then
		if currentBuffState ~= "" then
			-- 获得了新的Eclipse buff
			self:OnEclipseGained(currentBuffState)
		elseif self.Eclipse.state ~= "" then
			-- 失去了Eclipse buff
			self:OnEclipseLost(self.Eclipse.state)
		end
	end
end

-- 鸟德调试功能完全依赖Cat的调试系统

-- 初始化函数
function Bird:Initialize()
	self:DebugPrint("鸟德模块初始化开始")
	
	-- 鸟德不需要加载库和事件注册（无通报功能）
	
	self:DebugPrint("鸟德模块初始化完成")
end

-- 移除了通报相关的事件处理函数

-- 目标变化事件处理
function Bird:OnTargetChanged()
	-- 可在此添加目标变化时的逻辑
end

-- 进入战斗事件处理
function Bird:OnEnterCombat()
	-- 可在此添加进入战斗的逻辑
end

-- 离开战斗事件处理
function Bird:OnLeaveCombat()
	-- 可在此添加离开战斗的逻辑
end

-- 鸟德主要战斗循环
function Bird:CastAll()
	-- 获取基础状态信息
	local health = UnitHealth("player")
	local maxHealth = UnitHealthMax("player")
	local healthPercent = (health / maxHealth) * 100
	local mana = UnitMana("player")
	local powerType = UnitPowerType("player")
	local combat = UnitAffectingCombat("player")
	local name, _ = UnitName("player")
	-- 如果没有目标并且安装了UnitXP_SP3的话，使用UnitXP选择目标
	if not UnitExists("target") and AC.Event.UnitXP_SP3 then
		UnitXP("target", "nextEnemyInCycle")
	end
	-- 目标信息
	local targettarget, _ = UnitName("targettarget")
	local targetHealth = UnitHealth("target")
	local targetMaxHealth = UnitHealthMax("target")
	local targetHealthPercent = 0
	if targetMaxHealth and targetMaxHealth > 0 then
		targetHealthPercent = (targetHealth / targetMaxHealth) * 100
	end
	
	self:DebugPrint("鸟德状态：血量%d/%d(%.1f%%)，法力%d，目标血量%.1f%%", 
		health, maxHealth, healthPercent, mana, targetHealthPercent)
	
	-- 确保在正确的形态下
	self:EnsureCorrectForm()

	-- OT处理：当成为怪物攻击目标时的应对策略
	if combat and UnitExists("target") and UnitExists("targettarget") and UnitIsUnit("player", "targettarget") then
		local targetMaxHealth = UnitHealthMax("target")
		if targetMaxHealth > 100000 then -- Boss判断
			if AC.Options.bird.combat.otInvulnerability then
				local hasLimitedInvulBuff = AC.Lib.Buff("无敌")
				if not hasLimitedInvulBuff then
					-- 直接使用有限无敌药水，不检查CD
					AC.Lib.UseItemByName("有限无敌药水")
					self:DebugPrint("OT检测到，直接使用有限无敌药水")
				end
			end
		end
	end

	-- 使用共通饰品设置（进入战斗后才使用）
	if combat then
		if GetInventoryItemCooldown("player", 13) == 0 and AC.Options.trinketUpper == 1 and AC.TrinketUsable.upper then
			UseInventoryItem(13)
		end
		if GetInventoryItemCooldown("player", 14) == 0 and AC.Options.trinketBelow == 1 and AC.TrinketUsable.below then
			UseInventoryItem(14)
		end
	end

	-- 血量危险时处理
	if health < AC.Options.healthStoneValue and AC.Options.healthStone == 1 then
		AC.Lib.UseItemByName("特效治疗石")
	end
	if health < AC.Options.herbalTeaValue and AC.Options.herbalTea == 1 then
		AC.Lib.UseItemByName("诺达纳尔草药茶")
	end



	-- 鸟德攻击流程
	self:BirdCombatFlow()
end

-- 确保在正确的形态下（枭兽形态优先，否则人类形态）
function Bird:EnsureCorrectForm()
	local powerType = UnitPowerType("player")
	
	-- 检查是否有枭兽形态技能
	local hasMoonkinForm = self:HasMoonkinForm()
	
	if hasMoonkinForm then
		-- 有枭兽形态，检查是否已在枭兽形态下
		local inMoonkinForm = self:IsInMoonkinForm()
		
		if not inMoonkinForm then
			-- 进入枭兽形态
			CastSpellByName("枭兽形态")
			self:DebugPrint("进入枭兽形态")
			return
		end
	else
		-- 没有枭兽形态，确保在人类形态下
		if powerType ~= 0 then
			CastSpellByName("取消变形")
			self:DebugPrint("取消变形回到人类形态")
			return
		end
	end
end

-- 检查是否学会了枭兽形态（兼容1.12版本）
function Bird:HasMoonkinForm()
	-- 方法1：尝试通过法术书检查
	local i = 1
	while true do
		local spellName, spellRank = GetSpellName(i, "spell")
		if not spellName then
			break
		end
		if spellName == "枭兽形态" then
			self:DebugPrint("通过法术书发现枭兽形态: %s", spellName)
			return true
		end
		i = i + 1
	end
	
	-- 方法2：检查变身形态栏
	if GetNumShapeshiftForms then
		for i = 1, GetNumShapeshiftForms() do
			local texture, name, isActive, isCastable = GetShapeshiftFormInfo(i)
			if name and string.find(name, "枭兽") then
				self:DebugPrint("通过变身栏发现枭兽形态: %s", name)
				return true
			end
		end
	end
	
	self:DebugPrint("未发现枭兽形态技能")
	return false
end

-- 检查是否在枭兽形态中（兼容1.12版本）
function Bird:IsInMoonkinForm()
	-- 方法1：检查变身形态栏的激活状态
	if GetNumShapeshiftForms then
		for i = 1, GetNumShapeshiftForms() do
			local texture, name, isActive, isCastable = GetShapeshiftFormInfo(i)
			if isActive and name and string.find(name, "枭兽") then
				self:DebugPrint("当前在枭兽形态: %s", name)
				return true
			end
		end
	end
	
	-- 方法2：检查能量类型（枭兽形态使用法力）
	local powerType = UnitPowerType("player")
	if powerType == 0 then
		-- 在法力形态下，检查是否有枭兽形态的buff
		local buffName = AC.Lib.Buff("枭兽形态")
		if buffName then
			self:DebugPrint("通过buff检测到枭兽形态")
			return true
		end
	end
	
	return false
end

-- 鸟德战斗流程（DruidBird技能释放逻辑 + AutoCat buff判断）
function Bird:BirdCombatFlow()
	local targetHealth = UnitHealth("target")
	local targetMaxHealth = UnitHealthMax("target")
	local targetHealthPercent = 0
	if targetMaxHealth and targetMaxHealth > 0 then
		targetHealthPercent = (targetHealth / targetMaxHealth) * 100
	end
	
	-- 没有目标时不继续
	if not UnitExists("target") then
		return
	end
	
	-- 新逻辑不再依赖Eclipse状态，但保留用于调试
	local eclipseState, isEclipseWaiting = self:GetEclipseState()
	
	-- 使用AutoCat的DOT状态检查
	local swarm = AC.Event.GetSwarmDot()
	local moonfire = AC.Event.GetMoonfireDot()
	
	-- 使用AutoCat的BUFF状态检查
	local hasBalance = AC.Lib.Buff("万物平衡")
	local hasDayfall = AC.Lib.Buff("昼至")
	local hasNightfall = AC.Lib.Buff("夜至")
	
	local hasSolarEclipse = AC.Lib.Buff("日蚀")
	local hasLunarEclipse = AC.Lib.Buff("月蚀")
	
	local mana = UnitMana("player")
	
	self:DebugPrint("鸟德攻击流程：目标血量%.1f%%，法力%d，日蚀：%s，月蚀：%s，昼至：%s，夜至：%s，虫群：%s，月火：%s，自然之赐：%s，万物平衡：%s", 
		targetHealthPercent, mana, tostring(not not hasSolarEclipse), tostring(not not hasLunarEclipse), tostring(not not hasDayfall), tostring(not not hasNightfall), tostring(not not swarm), tostring(not not moonfire), tostring(not not AC.Lib.Buff("自然之赐")), tostring(not not hasBalance))
	
	-- 可否减益函数（使用AutoCat的DOT检查）
	local function CanDebuff(name)
		if name == "虫群" then
			return not swarm
		elseif name == "月火术" then
			return not moonfire
		end
		return false
	end
	
	-- DruidBird斩杀逻辑：目标生命小于等于设定百分比时
	if targetHealthPercent > 0 and targetHealthPercent <= AC.Options.bird.combat.executeThreshold then
		if hasBalance then
			-- 有万物平衡，打星火术（愤怒有弹道时间）
			CastSpellByName("星火术")
			self:DebugPrint("斩杀阶段+万物平衡：星火术")
		else
			CastSpellByName("愤怒")
			self:DebugPrint("斩杀阶段：愤怒")
		end
		return
	end
	
	-- 法力管理：激活、草药茶/符文
	-- 1. 激活逻辑：确保给自己使用
	if AC.Options.bird.mana.autoActivate then
		if mana < AC.Options.bird.mana.activateValue and AC.Lib.SpellReady("激活") then
			-- 保存当前目标
			local currentTargetName = UnitName("target")
			-- 目标自己使用激活
			TargetUnit("player")
			CastSpellByName("激活")
			self:DebugPrint("法力不足(%d < %d)，对自己使用激活", mana, AC.Options.bird.mana.activateValue)
			-- 恢复之前的目标
			if currentTargetName then
				TargetByName(currentTargetName)
			else
				ClearTarget()
			end
			return
		end
	end
	
	-- 2. 草药茶/符文逻辑（根据血量条件选择）
	if AC.Options.bird.mana.consumable then
		if mana < AC.Options.bird.mana.consumableValue then
			local health = UnitHealth("player")
			local maxHealth = UnitHealthMax("player")
			local healthPercent = (health / maxHealth) * 100
			
			if healthPercent < 50 then
				-- 血量低于50%，使用草药茶
				AC.Lib.UseItemByName("诺达纳尔草药茶")
				self:DebugPrint("法力不足(%d < %d)，血量%.1f%%，使用草药茶", mana, AC.Options.bird.mana.consumableValue, healthPercent)
			else
				-- 血量>=50%，优先使用恶魔符文，没有则用黑暗符文，如果都没有则用草药茶
				if AC.Lib.UseItemByName("恶魔符文") then
					self:DebugPrint("法力不足(%d < %d)，血量%.1f%%，使用恶魔符文", mana, AC.Options.bird.mana.consumableValue, healthPercent)
				elseif AC.Lib.UseItemByName("黑暗符文") then
					self:DebugPrint("法力不足(%d < %d)，血量%.1f%%，使用黑暗符文", mana, AC.Options.bird.mana.consumableValue, healthPercent)
				else
					-- 没有符文，回退到草药茶
					AC.Lib.UseItemByName("诺达纳尔草药茶")
					self:DebugPrint("法力不足(%d < %d)，血量%.1f%%，无符文可用，使用草药茶", mana, AC.Options.bird.mana.consumableValue, healthPercent)
				end
			end
			-- 注意：这里不return，继续往下走
		end
	end
	
	-- 新的技能释放逻辑
	-- 1. 虫群没了补虫群
	if CanDebuff("虫群") then
		CastSpellByName("虫群")
		AC.Event.lastSwarmTime = GetTime()
		self:DebugPrint("补虫群")
		return
	end
	
	-- 2. 月火没了补月火
	if CanDebuff("月火术") then
		CastSpellByName("月火术")
		AC.Event.lastMoonfireTime = GetTime()
		self:DebugPrint("补月火术")
		return
	end
	
	-- 2.5. 日蚀/月蚀状态优先级（在昼至/夜至之前）
	local hasSolarEclipse = AC.Lib.Buff("日蚀")
	local hasLunarEclipse = AC.Lib.Buff("月蚀")
	
	if hasSolarEclipse then
		CastSpellByName("愤怒")
		self:DebugPrint("日蚀：愤怒")
		return
	end
	
	if hasLunarEclipse then
		CastSpellByName("星火术")
		self:DebugPrint("月蚀：星火术")
		return
	end
	
	-- 3. 检查昼至和夜至状态（剩余时间判断）
	local hasDayfall = AC.Lib.Buff("昼至")
	local hasNightfall = AC.Lib.Buff("夜至")
	local dayfallTimeLeft = self:GetBuffTimeLeft("昼至")
	local nightfallTimeLeft = self:GetBuffTimeLeft("夜至")
	
	-- 昼至剩余2秒以下，不视为昼至状态
	if hasDayfall and dayfallTimeLeft and dayfallTimeLeft <= 2 then
		hasDayfall = false
		self:DebugPrint("昼至剩余%.1f秒，不视为昼至状态", dayfallTimeLeft)
	end
	
	-- 夜至剩余2秒以下，不视为夜至状态
	if hasNightfall and nightfallTimeLeft and nightfallTimeLeft <= 1 then
		hasNightfall = false
		self:DebugPrint("夜至剩余%.1f秒，不视为夜至状态", nightfallTimeLeft)
	end
	
	-- 4. 昼至状态下打星火术
	if hasDayfall and not hasNightfall then
		CastSpellByName("星火术")
		self:DebugPrint("昼至状态：星火术")
		return
	end
	
	-- 5. 夜至状态下打愤怒
	if hasNightfall and not hasDayfall then
		CastSpellByName("愤怒")
		self:DebugPrint("夜至状态：愤怒")
		return
	end
	
	-- 6. 两个状态都有或者都没有的情况
	if (hasDayfall and hasNightfall) or (not hasDayfall and not hasNightfall) then
		local hasNatureBlessing = AC.Lib.Buff("自然之赐")
		local hasBalance = AC.Lib.Buff("万物平衡")
		
		if hasNatureBlessing and hasBalance then
			-- 都有：打星火
			CastSpellByName("星火术")
			self:DebugPrint("自然之赐+万物平衡：星火术")
		elseif hasNatureBlessing and not hasBalance then
			-- 只有自然之赐：打愤怒
			CastSpellByName("愤怒")
			self:DebugPrint("自然之赐：愤怒")
		elseif not hasNatureBlessing and hasBalance then
			-- 只有万物平衡：打星火
			CastSpellByName("星火术")
			self:DebugPrint("万物平衡：星火术")
		else
			-- 都没有：打愤怒
			CastSpellByName("愤怒")
			self:DebugPrint("无buff：愤怒")
		end
		return
	end
end

-- 所有状态检查都使用现有的AC.Lib.Buff系统

-- 销毁函数
function Bird:Destroy()
	self:DebugPrint("鸟德模块销毁开始")
	-- 所有事件注销由CatEvent.lua统一管理
	self:DebugPrint("鸟德模块销毁完成")
end

-- 创建全局AutoBird函数
AutoBird = function()
    if AC.Bird then
        AC.Bird:CastAll()
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Bird Tip:|r |cFFf9cdfd鸟德模块未加载！|r")
    end
end

-- 注册鸟德斜杠命令
SLASH_AUTOCATBIRD1 = "/autobird"
SLASH_AUTOCATBIRD2 = "/AutoBird"

-- 处理鸟德斜杠命令
SlashCmdList["AUTOCATBIRD"] = function(msg)
    AutoBird()
end

-- 获取buff剩余时间（参考CheckBuffer实现）
function Bird:GetBuffTimeLeft(buffName, unit)
    unit = unit or "player"
    
    -- 只支持检查玩家自己的buff
    if unit ~= "player" then
        return nil, "仅支持检查玩家buff"
    end
    
    -- 方法1：使用CheckBuffer的方式（GetPlayerAuraIndex + GetPlayerBuffTimeLeft）
    if GetPlayerAuraIndex and GetPlayerBuffTimeLeft then
        local buffIndex = GetPlayerAuraIndex(buffName)
        if buffIndex and buffIndex >= 0 then
            local timeLeft = GetPlayerBuffTimeLeft(buffIndex)
            return timeLeft, string.format("CheckBuffer方式: 剩余%.1f秒", timeLeft)
        end
    end
    
    -- 方法2：使用AutoCat的方式作为备选
    local found, index = AC.Lib.Buff(buffName, unit)
    if found then
        -- 尝试使用GetPlayerBuffTimeLeft
        if GetPlayerBuffTimeLeft then
            local timeLeft = GetPlayerBuffTimeLeft(index)
            if timeLeft then
                return timeLeft, string.format("AutoCat+时间API: 剩余%.1f秒", timeLeft)
            end
        end
        
        return 0, "找到buff但无法获取剩余时间"
    end
    
    return nil, "未找到buff"
end

-- 增强版Eclipse状态检查（含剩余时间）
function Bird:GetEclipseStateWithTime()
    local eclipseState, isWaiting = self:GetEclipseState()
    
    local eclipseTimeLeft = nil
    local dayfallTimeLeft = nil
    local nightfallTimeLeft = nil
    
    -- 获取各buff剩余时间
    if eclipseState == "日蚀" then
        eclipseTimeLeft = self:GetBuffTimeLeft("日蚀")
    elseif eclipseState == "月蚀" then
        eclipseTimeLeft = self:GetBuffTimeLeft("月蚀")
    end
    
    dayfallTimeLeft = self:GetBuffTimeLeft("昼至")
    nightfallTimeLeft = self:GetBuffTimeLeft("夜至")
    
    return eclipseState, isWaiting, eclipseTimeLeft, dayfallTimeLeft, nightfallTimeLeft
end

-- 注册测试Eclipse状态的斜杠命令
SLASH_BIRDECLIPSE1 = "/birdeclipse"
SLASH_BIRDECLIPSE2 = "/be"

SlashCmdList["BIRDECLIPSE"] = function(msg)
    if not AC.Bird then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Bird:|r 鸟德模块未加载")
        return
    end
    
    local eclipseState, isWaiting = AC.Bird:GetEclipseState()
    
    -- 检查相关buff状态
    local hasSolarEclipse = AC.Lib.Buff("日蚀")
    local hasLunarEclipse = AC.Lib.Buff("月蚀")
    local hasDayfall = AC.Lib.Buff("昼至")
    local hasNightfall = AC.Lib.Buff("夜至")
    
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF906d96Bird Eclipse:|r 状态：%s，等待中：%s", 
        eclipseState or "无", tostring(isWaiting)))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF906d96Bird Buffs:|r 日蚀：%s，月蚀：%s，昼至：%s，夜至：%s", 
        tostring(not not hasSolarEclipse), tostring(not not hasLunarEclipse), tostring(not not hasDayfall), tostring(not not hasNightfall)))
    
    -- 测试buff剩余时间获取
    if msg == "time" then
        local buffsToTest = {"日蚀", "月蚀", "昼至", "夜至", "万物平衡", "自然之赐"}
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Bird Time Test:|r 检测buff剩余时间")
        for _, buffName in ipairs(buffsToTest) do
            local timeLeft, info = AC.Bird:GetBuffTimeLeft(buffName)
            if timeLeft then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF00FF00✓|r %s - %s", buffName, info))
            else
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFF0000✗|r %s - %s", buffName, info))
            end
        end
        return
    end
    
    -- 增强版Eclipse信息显示
    if msg == "full" then
        local eclipseState, isWaiting, eclipseTimeLeft, dayfallTimeLeft, nightfallTimeLeft = AC.Bird:GetEclipseStateWithTime()
        
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF906d96Bird Eclipse Full:|r 状态：%s，等待中：%s", 
            eclipseState or "无", tostring(isWaiting)))
            
        if eclipseTimeLeft then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF00FF00Eclipse:|r 剩余%.1f秒", eclipseTimeLeft))
        end
        if dayfallTimeLeft then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFFFFAA00昼至:|r 剩余%.1f秒", dayfallTimeLeft))
        end
        if nightfallTimeLeft then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cFF0088FF夜至:|r 剩余%.1f秒", nightfallTimeLeft))
        end
        return
    end
    
    -- 测试命令：模拟Eclipse获得/失去
    if msg == "solar" then
        AC.Bird:OnEclipseGained("日蚀")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Bird Test:|r 模拟获得日蚀")
    elseif msg == "lunar" then
        AC.Bird:OnEclipseGained("月蚀")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Bird Test:|r 模拟获得月蚀")
    elseif msg == "losesolar" then
        AC.Bird:OnEclipseLost("日蚀")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Bird Test:|r 模拟失去日蚀")
    elseif msg == "loselunar" then
        AC.Bird:OnEclipseLost("月蚀")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Bird Test:|r 模拟失去月蚀")
    end
end

-- 调试输出确认函数注册
DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96CatBird:|r AutoBird函数和命令已注册")
DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96CatBird:|r Eclipse测试命令：/birdeclipse 或 /be")
DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96CatBird:|r Buff时间测试：/be time")
DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96CatBird:|r 完整信息显示：/be full")
