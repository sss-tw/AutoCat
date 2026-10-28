-- -------------------------------------
-- AutoCat 熊德功能模块
-- 合并自 DruidBear 插件
-- -------------------------------------

-- 简写以方便引用
local AC = AutoCat

-- 非德鲁伊退出运行
local _, playerClass = UnitClass("player")
if playerClass ~= "DRUID" then
	return
end

-- 确保AutoCat对象已创建
AutoCat = AutoCat or {}
AC.Bear = AC.Bear or {}
local Bear = AC.Bear

local reportBuffs = {
	["狂暴回复"] = true,
	["狂暴"] = true,
	["树皮术（野性）"] = true,
}
local activeReportBuffs = {}

local function SendChat(channel, message)
	if message and message ~= "" then
		SendChatMessage(message, channel)
	end
end

local function HasAuraContaining(name, unit)
	unit = unit or "player"
	local index = 1
	while true do
		local found, auraName = AC.Lib.GetBuffNameByIndex(unit, index)
		if not found then
			break
		end
		if string.find(auraName, name, 1, true) then
			return true
		end
		index = index + 1
	end

	index = 1
	while true do
		local found, auraName = AC.Lib.GetDebuffNameByIndex(unit, index)
		if not found then
			break
		end
		if string.find(auraName, name, 1, true) then
			return true
		end
		index = index + 1
	end
	return false
end

local function GetRemainingHealthPercent(unit)
	local maximum = UnitHealthMax(unit)
	if not maximum or maximum <= 0 then
		return 0
	end
	return math.floor(UnitHealth(unit) / maximum * 100)
end

-- 熊德配置
Bear.Options = {
	-- 时机设置
	timing = {
		-- 挥击
		swipe = {
			use = true,      -- 使用挥击
			start = 30,      -- 起始怒气
		},
		-- 狂暴回复
		frenziedRegeneration = {
			start = 30,      -- 起始损失
			swipe = false,   -- 狂暴回复时是否挥击
			savageBite = false, -- 狂暴回复时是否野蛮撕咬
			maul = false     -- 狂暴回复时是否槌击
		},
		-- 狂怒
		enrage = {
			start = 10,      -- 起始怒气
			frenziedRegeneration = true -- 狂暴回复时
		},
		-- 狂暴
		frenzied = {
			start = 30,      -- 起始损失
			frenziedRegeneration = true,
		},
		maul = 30,           -- 槌击起始怒气
		savageBite = 60,     -- 野蛮撕咬起始怒气
		demoralizingRoar = false, -- 挫志咆哮
		faerieFireWild = "ready", -- 精灵之火（野性）
		growl = true,        -- 嘲讽
	},
	-- 通报设置
	report = {
		["低吼"] = true,
		["挑战咆哮"] = true,
		["狂暴回复"] = true,
		["狂暴"] = true,
		["树皮术（野性）"] = true,
	}
}

-- 私有变量
Bear.currentMaulRage = 7  -- 槌击当前怒气限制（初始为7，打过一次后变为配置值）
Bear.debugging = false    -- 调试开关
Bear.debugLevel = 2       -- 调试等级

-- 检查是否开启调试（使用Cat的方式）
function Bear:IsDebugging()
	return Cat and Cat:IsDebugging() and self.debugging
end

-- 获取调试等级（使用Cat的方式）  
function Bear:GetDebugLevel()
	return Cat and Cat:GetDebugLevel() or self.debugLevel
end

-- 调试输出函数（使用Cat的原版方式）
function Bear:DebugPrint(level, message, value1, value2, value3, value4, value5, value6, value7, value8, value9, value10, value11, value12)
	if not self:IsDebugging() or level > self:GetDebugLevel() then
		return
	end
	
	local formattedMessage
	if message and value1 ~= nil then
		formattedMessage = string.format(message, value1, value2, value3, value4, value5, value6, value7, value8, value9, value10, value11, value12)
	else
		formattedMessage = tostring(message or "")
	end
	-- 使用Cat的调试系统
	if Cat and Cat:IsDebugging() then
		DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Bear Debug:|r " .. formattedMessage)
	end
end

-- 设置调试模式（统一到Cat）
function Bear:SetDebugging(enabled)
	self.debugging = enabled
	if Cat and Cat.SetDebugging then
		Cat:SetDebugging(enabled)
	end
	self:DebugPrint(1, "调试模式已%s", enabled and "开启" or "关闭")
end

-- 设置调试等级（统一到Cat）
function Bear:SetDebugLevel(level)
	self.debugLevel = level
	if Cat and Cat.SetDebugLevel then
		Cat:SetDebugLevel(level)
	end
	self:DebugPrint(1, "调试等级设置为%d", level)
end

-- 初始化函数
function Bear:Initialize()
	self:DebugPrint(1, "熊德模块初始化开始")
	self:UpdateReportBuffs(true)
	self:DebugPrint(1, "熊德模块初始化完成")
end

-- 玩家技能施放成功后的通报入口，由 CatEvent.lua 的 Nampower 事件调用。
function Bear:OnPlayerSpellCast(name)
	self:DebugPrint(1, "玩家施法事件：name=%s", name or "nil")
	-- 低吼和挑战咆哮均使用喊话，避免白字说话频道。
	if (name ~= "低吼" and name ~= "挑战咆哮")
		or not AC.Options.bear
		or not AC.Options.bear.report
		or not AC.Options.bear.report[name] then
		return
	end
	if name == "挑战咆哮" then
		SendChat("YELL", "已群嘲，A起来！6秒不要怕！")
	else
		SendChat("YELL", "施放<" .. name .. ">！")
	end
end

function Bear:OnReportBuffGained(buff)
	self:DebugPrint(1, "获得增益事件：单位=player，增益=%s", buff or "nil")
	-- 检查配置
	if not AC.Options.bear or not AC.Options.bear.report then
		self:DebugPrint(1, "熊德通报配置未初始化")
		return
	end

	-- 是否通报
	if not AC.Options.bear.report[buff] then
		self:DebugPrint(2, "增益<%s>通报已禁用", buff)
		return
	end

	self:DebugPrint(1, "准备通报增益：%s", buff)
	if buff == "狂暴回复" then
		SendChat("YELL", "开启<" .. buff .. ">怒气转为生命！加大治疗量！我的血，我的血！")
	elseif buff == "狂暴" then
		SendChat("YELL", "开启<" .. buff .. ">生命上限提升！")
	elseif buff == "树皮术（野性）" then
		SendChat("YELL", "开启<" .. buff .. ">受到近战伤害减半！加大治疗量！")
	end
end

function Bear:UpdateReportBuffs(initializing)
	for buff in pairs(reportBuffs) do
		local active = AC.Lib.Buff(buff, "player") and true or false
		if active and not activeReportBuffs[buff] and not initializing then
			self:OnReportBuffGained(buff)
		end
		activeReportBuffs[buff] = active
	end
end

-- 目标变化事件处理
function Bear:OnTargetChanged()
	-- 重置槌击怒气限制
	self.currentMaulRage = 7
end

-- 进入战斗事件处理
function Bear:OnEnterCombat()
	-- 可在此添加进入战斗的逻辑
end

-- 离开战斗事件处理
function Bear:OnLeaveCombat()
	-- 重置槌击怒气限制
	self.currentMaulRage = 7
end

-- 熊德主要战斗循环
function Bear:PullAll(noTaunt)
	-- 抉择技能
	local health = GetRemainingHealthPercent("player")
	local mana = UnitMana("player")
	local powerType = UnitPowerType("player")
	local name, _ = UnitName("player")
	local targettarget,_= UnitName("targettarget")
	
	-- 确保在熊形态下
	if (powerType~=1) then 
		CastSpellByName("巨熊形态(变形)")
	end

	-- 当怒气限制为7时，优先使用槌击代替自动攻击
	local currentRage = UnitMana("player")
	local maulReady = AC.Lib.SpellReady("槌击")
	
	if self.currentMaulRage == 7 and currentRage >= 7 and maulReady then
		CastSpellByName("槌击")
		-- 打过一次槌击后，将怒气限制设为配置值
		self.currentMaulRage = AC.Options.bear.timing.maul
	else
		-- 自动攻击
		AC.Lib.StartAttack()
	end
	
	-- 使用共通饰品设置（使用缓存的可用性检查结果，需要有目标且在近战范围）
	if AC.Lib.IsTargetInRange() then
		if GetInventoryItemCooldown("player", 13) == 0 and AC.Options.trinketUpper == 1 and AC.TrinketUsable.upper then
			UseInventoryItem(13)
		end
		if GetInventoryItemCooldown("player", 14) == 0 and AC.Options.trinketBelow == 1 and AC.TrinketUsable.below then
			UseInventoryItem(14)
		end
	end

	-- 精灵之火（野性）
	if AC.Lib.CanFaerieFire("target") and AC.Options.bear.timing.faerieFireWild == "ready" and AC.Lib.SpellReady("精灵之火（野性）") then
		-- 当法术就绪时：骗节能
		CastSpellByName("精灵之火（野性）")
	elseif AC.Lib.CanFaerieFire("target") and AC.Options.bear.timing.faerieFireWild == "none" and not HasAuraContaining("精灵之火", "target") and AC.Lib.SpellReady("精灵之火（野性）") then
		-- 当目标无精灵之火时：减护甲
		CastSpellByName("精灵之火（野性）")
	-- 狂暴回复
	elseif health <= AC.Options.bear.timing.frenziedRegeneration.start and not HasAuraContaining("狂暴回复") and AC.Lib.SpellReady("狂暴回复") then
		-- 当生命小于或等于该百分比时：怒气转生命
		CastSpellByName("狂暴回复")
	-- 狂怒
	elseif mana < AC.Options.bear.timing.enrage.start and not UnitAffectingCombat("player") and AC.Lib.SpellReady("狂怒") then
		-- 当怒气小于该值且未在战斗中时：涨怒气
		CastSpellByName("狂怒")
	elseif AC.Options.bear.timing.enrage.frenziedRegeneration and HasAuraContaining("狂暴回复") and AC.Lib.SpellReady("狂怒") then
		-- 当有狂暴回复时：涨怒气
		CastSpellByName("狂怒")
	-- 狂暴
	elseif health <= AC.Options.bear.timing.frenzied.start and AC.Lib.SpellReady("狂暴") then
		-- 当损失小于或等于该值时：提升生命上限
		CastSpellByName("狂暴")
	elseif AC.Options.bear.timing.frenzied.frenziedRegeneration and HasAuraContaining("狂暴回复") and AC.Lib.SpellReady("狂暴") then
		-- 当有狂暴回复时：提升生命上限
		CastSpellByName("狂暴")
	-- 嘲讽（可通过参数禁用）
	elseif not noTaunt and AC.Options.bear.timing.growl and name~=targettarget and targettarget~=nil and AC.Lib.SpellReady("低吼") then
		-- 目标的目标不是我时嘲讽
		CastSpellByName("低吼")
	-- 节能施法
	elseif HasAuraContaining("节能施法") then
		-- 当有节能施法时：白嫖技能
		if AC.Lib.SpellReady("野蛮撕咬") then
			CastSpellByName("野蛮撕咬")
		elseif AC.Options.bear.timing.swipe.use then
			CastSpellByName("挥击")
		else
			CastSpellByName("槌击")
		end
	-- 野蛮撕咬
	elseif mana >= AC.Options.bear.timing.savageBite and not HasAuraContaining("狂暴回复") and AC.Lib.SpellReady("野蛮撕咬") then
		-- 当怒气大于或等于该值且无狂暴回复时：泄怒气
		CastSpellByName("野蛮撕咬")
	-- 挥击
	elseif AC.Options.bear.timing.swipe.use and mana >= AC.Options.bear.timing.swipe.start and not HasAuraContaining("狂暴回复") and AC.Lib.SpellReady("挥击") then
		-- 当怒气大于或等于该值且无狂暴回复时：挥击
		CastSpellByName("挥击")
	-- 槌击
	elseif mana >= self.currentMaulRage and not HasAuraContaining("狂暴回复") and AC.Lib.SpellReady("槌击") then
		-- 当怒气大于或等于该值且无狂暴回复时：槌击
		CastSpellByName("槌击")
		-- 打过一次槌击后，将怒气限制设为配置值
		self.currentMaulRage = AC.Options.bear.timing.maul
	-- 挫志咆哮
	elseif AC.Options.bear.timing.demoralizingRoar and mana >= 10 and not HasAuraContaining("挫志咆哮", "target") and not HasAuraContaining("挫志怒吼", "target") and AC.Lib.SpellReady("挫志咆哮") then
		-- 当目标挫志咆哮和挫志怒吼时：减攻击强度
		CastSpellByName("挫志咆哮")
	-- 狂暴回复状态下的技能
	elseif HasAuraContaining("狂暴回复") then
		if mana >= AC.Options.bear.timing.savageBite and AC.Options.bear.timing.frenziedRegeneration.savageBite and AC.Lib.SpellReady("野蛮撕咬") then
			-- 当怒气大于或等于该值且无狂暴回复时：泄怒气
			CastSpellByName("野蛮撕咬")
		elseif AC.Options.bear.timing.swipe.use and mana >= AC.Options.bear.timing.swipe.start and AC.Options.bear.timing.frenziedRegeneration.swipe and AC.Lib.SpellReady("挥击") then
			-- 当怒气大于或等于该值且无狂暴回复时：挥击
			CastSpellByName("挥击")
		elseif mana >= self.currentMaulRage and AC.Options.bear.timing.frenziedRegeneration.maul and AC.Lib.SpellReady("槌击") then
			-- 当怒气大于或等于该值且无狂暴回复时：槌击
			CastSpellByName("槌击")
			-- 打过一次槌击后，将怒气限制设为配置值
			self.currentMaulRage = AC.Options.bear.timing.maul
		end
	end
end


-- 销毁函数
function Bear:Destroy()
	self:DebugPrint(1, "熊德模块销毁开始")
	-- 所有事件注销由CatEvent.lua统一管理
	self:DebugPrint(1, "熊德模块销毁完成")
end

-- 注册熊德斜杠命令
SLASH_BEAR1 = "/autobear"
SLASH_BEAR2 = "/AutoBear"

-- 处理熊德斜杠命令
SlashCmdList["BEAR"] = function(msg)
    if AC.Bear then
        AC.Bear:PullAll(false)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Bear Tip:|r |cFFf9cdfd熊德模块未加载！|r")
    end
end
