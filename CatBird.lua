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

-- 鸟德配置
Bird.Options = {
	-- 基础攻击设置
	combat = {
		autoActivate = true,     -- 自动使用激活
		otInvulnerability = true,  -- OT吃有限无敌
		executeThreshold = 19,   -- 斩杀阈值（百分比）
	}
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

-- 鸟德战斗流程（基于平衡德宏逻辑）
function Bird:BirdCombatFlow()
	local mana = UnitMana("player")
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
	
	self:DebugPrint("鸟德攻击流程：法力%d，目标血量%.1f%%", mana, targetHealthPercent)
	
	-- 获取状态信息（使用现有函数）
	
	-- 检查目标DOT状态（使用与猫德相同的检测方式）
	local swarm = AC.Event.GetSwarmDot()
	local moonfire = AC.Event.GetMoonfireDot()
	
	-- 检查自身BUFF状态
	local hasStarshift = AC.Lib.Buff("斗转星移")
	local hasEclipseSun = AC.Lib.Buff("日蚀")
	local hasEclipseMoon = AC.Lib.Buff("月蚀")
	local hasNatureBlessing = AC.Lib.Buff("自然之赐")
	local hasBalance = AC.Lib.Buff("万物平衡")
	local hasDayfall = AC.Lib.Buff("昼至")
	local hasNightfall = AC.Lib.Buff("夜至")
	
	-- 饰品使用已在CastAll中处理，此处移除重复逻辑
	
	-- 斗转星移状态下的优先级
	if hasStarshift then
		if hasEclipseMoon then
			CastSpellByName("星火术")
			self:DebugPrint("斗转星移+月蚀：星火术")
		else
			CastSpellByName("愤怒")
			self:DebugPrint("斗转星移：愤怒")
		end
		return
	end
	
	-- 斩杀阶段优先级最高
	if targetHealthPercent > 0 and targetHealthPercent <= AC.Options.bird.combat.executeThreshold then
		CastSpellByName("愤怒")
		self:DebugPrint("斩杀阶段：使用愤怒")
		return
	end
	
	-- 蓝量不足时使用激活
	if AC.Options.bird.combat.autoActivate then
		if mana < 1000 and AC.Lib.SpellReady("激活") then
			CastSpellByName("激活")
			self:DebugPrint("法力不足(%d)，使用激活", mana)
			return
		end
	end
	
	-- 常规输出循环（参考DruidBird优化）
	if hasEclipseSun then
		-- 日蚀状态：自然伤害增强25%
		if not swarm then
			-- 日蚀时优先虫群（自然伤害DOT）
			CastSpellByName("虫群")
			AC.Event.lastSwarmTime = GetTime()
			self:DebugPrint("日蚀：施放虫群")
			return
		elseif not hasNatureBlessing and not moonfire then
			-- 补月火术（为愤怒减耗做准备）
			CastSpellByName("月火术")
			AC.Event.lastMoonfireTime = GetTime()
			self:DebugPrint("日蚀：施放月火术")
			return
		elseif not AC.Lib.Buff("精灵之火", "target") and targetMaxHealth > 200000 then
			-- Boss目标补精灵之火
			CastSpellByName("精灵之火")
			self:DebugPrint("日蚀Boss：施放精灵之火")
			return
		else
			-- 日蚀时主要输出：愤怒（自然伤害）
			CastSpellByName("愤怒")
			self:DebugPrint("日蚀：愤怒")
			return
		end
	elseif hasEclipseMoon then
		-- 月蚀状态：奥术伤害增强25%
		if not moonfire then
			-- 月蚀时优先月火术（奥术伤害DOT）
			CastSpellByName("月火术")
			AC.Event.lastMoonfireTime = GetTime()
			self:DebugPrint("月蚀：施放月火术")
			return
		elseif not swarm then
			-- 补虫群（为星火术减时做准备）
			CastSpellByName("虫群")
			AC.Event.lastSwarmTime = GetTime()
			self:DebugPrint("月蚀：施放虫群")
			return
		elseif not AC.Lib.Buff("精灵之火", "target") and targetMaxHealth > 200000 then
			-- Boss目标补精灵之火
			CastSpellByName("精灵之火")
			self:DebugPrint("月蚀Boss：施放精灵之火")
			return
		else
			-- 月蚀时主要输出：星火术（奥术伤害）
			CastSpellByName("星火术")
			self:DebugPrint("月蚀：星火术")
			return
		end
	else
		-- 无Eclipse状态：维持DOT，根据BUFF选择技能
		if not swarm then
			-- 虫群优先级最高（获得万物平衡几率）
			CastSpellByName("虫群")
			AC.Event.lastSwarmTime = GetTime()
			self:DebugPrint("常规：施放虫群")
			return
		elseif not hasNatureBlessing and not moonfire then
			-- 没有自然之赐时补月火术（获得自然之赐几率）
			CastSpellByName("月火术")
			AC.Event.lastMoonfireTime = GetTime()
			self:DebugPrint("常规：施放月火术")
			return
		elseif not AC.Lib.Buff("精灵之火", "target") and targetMaxHealth > 200000 then
			-- Boss目标补精灵之火
			CastSpellByName("精灵之火")
			self:DebugPrint("常规Boss：施放精灵之火")
			return
		elseif hasBalance then
			-- 有万物平衡：星火术（减少施法时间）
			CastSpellByName("星火术")
			self:DebugPrint("万物平衡：星火术")
			return
		elseif hasDayfall or not hasNightfall then
			-- 昼至或非夜至：星火术（触发Eclipse几率）
			CastSpellByName("星火术")
			self:DebugPrint("昼至/非夜至：星火术")
			return
		else
			-- 默认：愤怒（触发Eclipse几率）
			CastSpellByName("愤怒")
			self:DebugPrint("默认：愤怒")
			return
		end
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

-- 调试输出确认函数注册
DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96CatBird:|r AutoBird函数和命令已注册")
