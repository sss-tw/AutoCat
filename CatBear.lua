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

-- 需要的库（延迟加载）
local Health, Effect, Spell, Chat, SpellStatus, AuraEvents

-- 库加载函数
local function LoadLibraries()
	if not Health then
		local success, result
		
		success, result = pcall(function() return AceLibrary("Wsd-Health-1.0") end)
		if success then Health = result end
		
		success, result = pcall(function() return AceLibrary("Wsd-Effect-1.0") end)
		if success then Effect = result end
		
		success, result = pcall(function() return AceLibrary("Wsd-Spell-1.0") end)
		if success then Spell = result end
		
		success, result = pcall(function() return AceLibrary("Wsd-Chat-1.0") end)
		if success then Chat = result end
		
		-- 通报相关库
		success, result = pcall(function() return AceLibrary("SpellStatus-1.0") end)
		if success then SpellStatus = result end
		
		success, result = pcall(function() return AceLibrary("SpecialEvents-Aura-2.0") end)
		if success then AuraEvents = result end
	end
end
local ParserLib

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
function Bear:DebugPrint(level, message, ...)
	if not self:IsDebugging() or level > self:GetDebugLevel() then
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

-- RAW_COMBATLOG事件处理（统一事件处理方式）
function Bear:OnRawCombatLog(arg1, arg2, arg3, arg4, arg5)
	-- 对应原版DruidBear的SPELL_PERIODIC和SELF_DAMAGE功能
	if arg1 == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
		self:HandleSpellPeriodic(arg2)
	elseif arg1 == "CHAT_MSG_SPELL_SELF_DAMAGE" then
		self:HandleSelfDamage(arg2)
	elseif arg1 == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF" then
		self:HandleSelfDamage(arg2)
	end
end

-- 对应原版DruidBear:SPELL_PERIODIC
function Bear:HandleSpellPeriodic(message)
	self:DebugPrint(3, "造成周期性伤害；消息：%s", message or "")
	-- 原版只有调试输出，没有实际功能
end

-- 对应原版DruidBear:SELF_DAMAGE
function Bear:HandleSelfDamage(message)
	self:DebugPrint(3, "自身造成伤害；消息：%s", message or "")
	
	-- 原版只处理"低吼"技能，且需要配置启用
	-- 由于我们暂时没有Chat库，先用调试输出代替
	-- 实际使用时需要集成Wsd-Chat-1.0库
end

-- 初始化函数
function Bear:Initialize()
	self:DebugPrint(1, "熊德模块初始化开始")
	
	-- 加载所需库
	LoadLibraries()
	
	-- 注册AceEvent事件（通过Cat addon）
	if Cat then
		-- 注册事件并指向Bear的对应方法
		Cat:RegisterEvent("SpellStatus_SpellCastInstant", function(id, name, rank, fullName)
			if AC.Bear and AC.Bear.SpellStatus_SpellCastInstant then
				AC.Bear:SpellStatus_SpellCastInstant(id, name, rank, fullName)
			end
		end)
		Cat:RegisterEvent("SpecialEvents_UnitBuffGained", function(unit, buff)
			if AC.Bear and AC.Bear.SpecialEvents_UnitBuffGained then
				AC.Bear:SpecialEvents_UnitBuffGained(unit, buff)
			end
		end)
	end
	
	self:DebugPrint(1, "熊德模块初始化完成")
end

-- ParserLib事件处理
function Bear:OnParserEvent(event, info)
	if event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
		self:OnSpellPeriodic(event, info)
	elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" or 
		   event == "CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF" then
		self:OnSelfDamage(event, info)
	else
		self:DebugPrint(3, "未处理的Parser事件：%s", event)
	end
end

-- AceEvent风格的瞬间施法事件处理（原版DruidBear兼容）
function Bear:SpellStatus_SpellCastInstant(id, name, rank, fullName)
	self:DebugPrint(1, "瞬间施法事件：id=%s, name=%s, rank=%s, fullName=%s", id or "nil", name or "nil", rank or "nil", fullName or "nil")
	
	-- 确保库已加载
	if not Chat then
		LoadLibraries()
	end
	
	-- 检查配置
	if not AC.Options.bear or not AC.Options.bear.report then
		return
	end
	
	-- 是否通报
	local reportConfig = AC.Options.bear.report[name]
	if not reportConfig then
		return
	end

	-- 通报技能
	if Chat then
		if name == "挑战咆哮" then
			Chat:Say("对周围施放<%s>！", name)
		else
			Chat:Say("施放<%s>！", name)
		end
	end
end

-- AceEvent风格的获得增益事件处理（原版DruidBear兼容）
function Bear:SpecialEvents_UnitBuffGained(unit, buff)
	self:DebugPrint(1, "获得增益事件：单位=%s，增益=%s", unit or "nil", buff or "nil")
	
	-- 仅限自身
	if unit ~= 'player' then
		return
	end

	-- 确保库已加载
	if not Chat then
		LoadLibraries()
	end
	
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
		Chat:Yell("开启<%s>怒气转为生命！加大治疗量！我的血，我的血！", buff)
	elseif buff == "狂暴" then
		Chat:Yell("开启<%s>生命上限提升！", buff)
	elseif buff == "树皮术（野性）" then
		Chat:Yell("开启<%s>受到近战伤害减半！加大治疗量！", buff)
	else 
		Chat:Send("获得<%s>！", buff)
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

-- 周期性伤害事件处理
function Bear:OnSpellPeriodic(event, info)
	if info.type == "unknown" then
		-- 训练假人 is afflicted by 低吼 (1).
		local victim, skill, rank = ParserLib:Deformat(info.message, "%s is afflicted by %s (%d).")
		if victim and skill then
			info.type = "debuff"
			info.victim = victim
			info.skill = skill
			info.amountRank = rank
			info.message = nil
		end
	end

	if not info.skill then
		return
	end

	-- 通报类型
	local type = AC.Options.bear.report[info.skill]
	if not type or type == "disable" then
		return
	end
end

-- 自身造成伤害事件处理
function Bear:OnSelfDamage(event, info)
	if not info.skill then
		return
	end

	-- 是否通报
	if not AC.Options.bear.report[info.skill] or info.skill ~= "低吼" then
		return
	end

	if info.type == "hit" or info.type == "cast" then
		Chat:Say("<%s>作用于<%s>！", info.skill, info.victim)
	elseif info.type == "miss" then
		local types = {
			resist = "抵抗",
			immune = "免疫",
			block = "阻挡",
			deflect = "偏移",
			dodge = "躲闪",
			evade = "回避",
			absorb = "吸收",
			parry = "招架",
			reflect = "反射",
		}
		if types[info.missType] then
			Chat:Yell("<%s>被<%s>%s！", info.skill, info.victim, types[info.missType])
		else
			Chat:Yell("<%s>未命中<%s>！", info.skill, info.victim)
		end
	elseif info.type == "leech" then
		Chat:Yell("<%s>被<%s>吸收！", info.skill, info.victim)
	elseif info.type == "dispel" then
		Chat:Yell("<%s>被<%s>驱散！", info.skill, info.victim)
	else
		Chat:Yell("<%s>未生效！", info.skill)
	end
end

-- 熊德主要战斗循环
function Bear:PullAll(noTaunt)
	-- 抉择技能
	local health = Health:GetRemaining("player")
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
	local maulReady = Spell:IsReady("槌击")
	
	if self.currentMaulRage == 7 and currentRage >= 7 and maulReady then
		CastSpellByName("槌击")
		-- 打过一次槌击后，将怒气限制设为配置值
		self.currentMaulRage = AC.Options.bear.timing.maul
	else
		-- 自动攻击
		Spell:AutoAttack()
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
	if AC.Options.bear.timing.faerieFireWild == "ready" and Spell:IsReady("精灵之火（野性）") then
		-- 当法术就绪时：骗节能
		CastSpellByName("精灵之火（野性）")
	elseif AC.Options.bear.timing.faerieFireWild == "none" and not Effect:FindName("精灵之火", "target") and Spell:IsReady("精灵之火（野性）") then
		-- 当目标无精灵之火时：减护甲
		CastSpellByName("精灵之火（野性）")
	-- 狂暴回复
	elseif health <= AC.Options.bear.timing.frenziedRegeneration.start and not Effect:FindName("狂暴回复") and Spell:IsReady("狂暴回复") then
		-- 当生命小于或等于该百分比时：怒气转生命
		CastSpellByName("狂暴回复")
	-- 狂怒
	elseif mana < AC.Options.bear.timing.enrage.start and not UnitAffectingCombat("player") and Spell:IsReady("狂怒") then
		-- 当怒气小于该值且未在战斗中时：涨怒气
		CastSpellByName("狂怒")
	elseif AC.Options.bear.timing.enrage.frenziedRegeneration and Effect:FindName("狂暴回复") and Spell:IsReady("狂怒") then
		-- 当有狂暴回复时：涨怒气
		CastSpellByName("狂怒")
	-- 狂暴
	elseif health <= AC.Options.bear.timing.frenzied.start and Spell:IsReady("狂暴") then
		-- 当损失小于或等于该值时：提升生命上限
		CastSpellByName("狂暴")
	elseif AC.Options.bear.timing.frenzied.frenziedRegeneration and Effect:FindName("狂暴回复") and Spell:IsReady("狂暴") then
		-- 当有狂暴回复时：提升生命上限
		CastSpellByName("狂暴")
	-- 嘲讽（可通过参数禁用）
	elseif not noTaunt and AC.Options.bear.timing.growl and name~=targettarget and targettarget~=nil and Spell:IsReady("低吼") then
		-- 目标的目标不是我时嘲讽
		CastSpellByName("低吼")
	-- 节能施法
	elseif Effect:FindName("节能施法") then
		-- 当有节能施法时：白嫖技能
		if Spell:IsReady("野蛮撕咬") then
			CastSpellByName("野蛮撕咬")
		elseif AC.Options.bear.timing.swipe.use then
			CastSpellByName("挥击")
		else
			CastSpellByName("槌击")
		end
	-- 野蛮撕咬
	elseif mana >= AC.Options.bear.timing.savageBite and not Effect:FindName("狂暴回复") and Spell:IsReady("野蛮撕咬") then
		-- 当怒气大于或等于该值且无狂暴回复时：泄怒气
		CastSpellByName("野蛮撕咬")
	-- 挥击
	elseif AC.Options.bear.timing.swipe.use and mana >= AC.Options.bear.timing.swipe.start and not Effect:FindName("狂暴回复") and Spell:IsReady("挥击") then
		-- 当怒气大于或等于该值且无狂暴回复时：挥击
		CastSpellByName("挥击")
	-- 槌击
	elseif mana >= self.currentMaulRage and not Effect:FindName("狂暴回复") and Spell:IsReady("槌击") then
		-- 当怒气大于或等于该值且无狂暴回复时：槌击
		CastSpellByName("槌击")
		-- 打过一次槌击后，将怒气限制设为配置值
		self.currentMaulRage = AC.Options.bear.timing.maul
	-- 挫志咆哮
	elseif AC.Options.bear.timing.demoralizingRoar and mana >= 10 and not Effect:FindName("挫志咆哮", "target") and not Effect:FindName("挫志怒吼", "target") and Spell:IsReady("挫志咆哮") then
		-- 当目标挫志咆哮和挫志怒吼时：减攻击强度
		CastSpellByName("挫志咆哮")
	-- 狂暴回复状态下的技能
	elseif Effect:FindName("狂暴回复") then
		if mana >= AC.Options.bear.timing.savageBite and AC.Options.bear.timing.frenziedRegeneration.savageBite and Spell:IsReady("野蛮撕咬") then
			-- 当怒气大于或等于该值且无狂暴回复时：泄怒气
			CastSpellByName("野蛮撕咬")
		elseif AC.Options.bear.timing.swipe.use and mana >= AC.Options.bear.timing.swipe.start and AC.Options.bear.timing.frenziedRegeneration.swipe and Spell:IsReady("挥击") then
			-- 当怒气大于或等于该值且无狂暴回复时：挥击
			CastSpellByName("挥击")
		elseif mana >= self.currentMaulRage and AC.Options.bear.timing.frenziedRegeneration.maul and Spell:IsReady("槌击") then
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
