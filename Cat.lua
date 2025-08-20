-- -------------------------------------
-- 乌龟服 - 全自动猫德一键宏
-- 发布日期：2025-05-29 （后面根据时间来判断版本）
-- 发布者：旧德二世 - 卡拉赞 - 亚服
-- 感谢：妖姬变 树先生 Crazydru
-- 有问题游戏里或者kook-德鲁伊频道交流
--
-- 可选模组：SuperWoW UnitXP_SP3 Interact cat
--
-- 说明：
-- 全自动判断->目标是否吃流血->目标正反面朝向
-- 自动根据以上条件选择施放技能
--
-- 监测内容：
-- 目标可否吃流血（持续更新怪物名录）
-- 目标正反面朝向，可扩展支持UnitXP
-- 扫击、撕扯流血效果持续时间
-- 技能所需要能量的自动计算（3件T2.5特效、凶蛮神像、野蛮神像以及天赋影响）
-- GCD（公共冷却时间）的监测，近无缝变身
-- 2秒回能，背刺流优化变身时机
-- 自己、目标生命值
--
-- -------------------------------------
--
-- 功能配置：
-- 这些变量现在从CatOptions.lua中获取，可以通过UI界面设置
--
-- 使用方法：
-- 1. 游戏中输入 /cat 打开设置界面
-- 2. 或者创建宏，在宏里填入"/script AutoCat()"，不包含引号
-- 无参数强制打法类型，则通过配置来决定
-- 一键宏的技能模式，取值范围(1,2,3,4)，1=自动选择，2=仅进行背刺流打法，3=仅进行双流血打法，4=流血撕碎打法
-- 例如："/script AutoCat(2)"，只打背刺流
-- -------------------------------------

-- 确保AutoCat对象已创建
AutoCat = AutoCat or {}
local AC = AutoCat -- 简写以方便引用

-- 初始化命名空间
AC.Combat = AC.Combat or {} -- 战斗相关的函数

-- 私有变量
local lastLootTime = 0  -- 上次拾取时间

-- 主函数，作为AutoCat表的方法
AutoCat.Run = function(type)

	-- 无参数强制打法类型，则通过配置来决定
	-- 一键宏的技能模式，取值范围(1,2,3,4)
	if not type then
		type = AC.Options.type
	else
		if type < 1 or type > 4 then
			type = AC.Options.type
		end
	end

	local myPower = UnitMana("player")
	local dmMana = AC.Lib.DriudMana()
	local gcdLeft = AC.Lib.GetSpellCooldown("愤怒")
	local comboPoints = GetComboPoints("target")
	local playerHealth = UnitHealth("player")
	local isStealthed = AC.Lib.Buff("潜行")
	local hasPredatorReveal = AC.Lib.Buff("节能施法")
	local isBehind = AC.Event.CheckBehind(AC.Options.useUnitXP)
	local combat = UnitAffectingCombat("player")

	-- OT处理：当成为怪物攻击目标时的应对策略（在变身前处理）
	if combat and UnitExists("target") and UnitExists("targettarget") and UnitIsUnit("player", "targettarget") then
		local targetMaxHealth = UnitHealthMax("target")
		if targetMaxHealth > 100000 then
            local hasLimitedInvulBuff = AC.Lib.Buff("无敌")
            if hasLimitedInvulBuff then
                -- 成功使用有限无敌，继续猫德攻击
                if Cat and Cat:IsDebugging() then
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r OT检测到，成功使用有限无敌药水")
                end
            else
                local useBeaForm = false
                -- 检查有限无敌药水状态
                if AC.Options.otLimitedInvulnerability == 1 then
                    -- 检查有限无敌药水是否在CD中
                    local potionOnCooldown = false
                    
                    -- 遍历背包查找有限无敌药水并检查CD
                    for bag = 0, 4 do
                        for slot = 1, GetContainerNumSlots(bag) do
                            local itemLink = GetContainerItemLink(bag, slot)
                            if itemLink then
                                local itemName = GetItemInfo(itemLink)
                                if itemName and (itemName == "有限无敌药水" or itemName == "Limited Invulnerability Potion") then
                                    local startTime, duration = GetContainerItemCooldown(bag, slot)
                                    if duration > 0 then
                                        potionOnCooldown = true
                                    end
                                    break
                                end
                            end
                        end
                        if potionOnCooldown then break end
                    end
                    
                    -- 如果药水不在CD中，尝试使用
                    if not potionOnCooldown then
                        AC.Lib.UseItemByName("有限无敌药水")
                    else
                        useBeaForm = true
                        if Cat and Cat:IsDebugging() then
                            DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r 有限无敌药水CD中，需要使用熊形态应对")
                        end
                    end
                else
                    useBeaForm = true
                end
                
                -- OT变熊处理
                if AC.Options.otBearForm == 1 and useBeaForm then
                    if Cat and Cat:IsDebugging() then
                        DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Debug:|r OT检测到，使用熊形态应对")
                    end
                    
                    -- 调用熊德攻击逻辑（PullAll内部会自动变熊）
                    if AC.Bear and AC.Bear.PullAll then
                        AC.Bear:PullAll(true)  -- 传入true禁用嘲讽
                    end
                    
                    return  -- 使用熊德攻击逻辑，不再执行猫德攻击
                end
            end
        end
	end

	-- 确保在豹子形态下
	if not AC.Lib.GetShape(3) then
		CastSpellByName("猎豹形态(变形)")
	end

	-- 非战斗状态下根据设置决定是否进入潜行
	if not combat and not isStealthed and AC.Options.pounce == 1 and AC.Lib.SpellReady("潜行") then
		CastSpellByName("潜行")
		return
	end

	-- 如果没有目标并且未在战斗中时，并且安装了UnitXP_SP3的话，使用UnitXP选择目标
	if not UnitExists("target") and AC.Event.UnitXP_SP3 then
		UnitXP("target", "nextEnemyConsideringDistance")
	end

	-- 在潜行状态
	if isStealthed and isBehind then
		if AC.Options.pounce == 1 then
			if AC.Config.targetBleed then
				-- 目标可流血用突袭
				CastSpellByName("突袭")
				return
			else
				-- 目标不可流血就毁灭
				CastSpellByName("毁灭")
				return
			end
            return
		end
	end

	-- 自动拾取
	if AC.Options.loot == 1 then
		local currentTime = GetTime()
		-- 满足条件：1.没有选中目标 2.距离上次拾取已超过设定间隔
		if not UnitExists("target") and (currentTime - lastLootTime >= AC.Options.lootInterval) then
			-- 使用UnitXP函数进行拾取
			UnitXP("interact", 1)
			lastLootTime = currentTime
		end
	end

	-- 检查目标是否是玩家，如果是则不进行攻击并切换目标
	if AC.Options.avoidPlayerTarget == 1 and UnitExists("target") and UnitIsPlayer("target") then
		-- 清除当前目标（这会自动停止攻击）
		ClearTarget()
		
		-- 如果有UnitXP_SP3，尝试选择新的敌方目标
		if AC.Event.UnitXP_SP3 then
			UnitXP("target", "nextEnemyConsideringDistance")
		end
		
		-- 输出提示信息
		-- DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Cat Tip:|r |cFFf9cdfd检测到玩家目标，已停止攻击并切换目标|r")
		return
	end

	-- 开启自动攻击
	AC.Lib.StartAttack()

	-- 自动开启饰品（使用缓存的可用性检查结果）
	if GetInventoryItemCooldown("player",13)==0 and AC.Options.trinketUpper==1 and AC.TrinketUsable.upper then
		UseInventoryItem(13)
	end
	if GetInventoryItemCooldown("player",14)==0 and AC.Options.trinketBelow==1 and AC.TrinketUsable.below then
		UseInventoryItem(14)
	end

	-- 血量危险时处理，潜行下不吃药
	if playerHealth < AC.Options.healthStoneValue and AC.Options.healthStone==1 then
		AC.Lib.UseItemByName("特效治疗石")
	end
	if playerHealth < AC.Options.herbalTeaValue and AC.Options.herbalTea==1 then
		AC.Lib.UseItemByName("诺达纳尔草药茶")
	end
	-- 献祭之油：战斗中且没有火焰之盾buff时使用
	if AC.Options.sacrificeOil==1 and combat and not AC.Lib.Buff("火焰之盾") then
		AC.Lib.UseItemByName("献祭之油")
	end

	-- 攻击流程
	if type == 1 then
		if AC.Config.targetBleed then	-- 目标可流血
			AC.Combat.Bleed()
		else					-- 目标不可流血
			AC.Combat.Backstab()
		end
	elseif type == 2 then
		AC.Combat.Backstab()		-- 背刺流
	elseif type == 3 then
		AC.Combat.Bleed()		-- 双流血
	elseif type == 4 then
		AC.Combat.RendBleed()		-- 流血撕碎
	end
end


-- 流血猫攻击流程
AC.Combat.t1 = nil
AC.Combat.tigerFuryTimer = nil

function AC.Combat.Bleed()
    -- 初始化计时器
    if not AC.Combat.t1 then AC.Combat.t1 = GetTime() - 12 end
    if not AC.Combat.tigerFuryTimer then AC.Combat.tigerFuryTimer = GetTime() - 18 end
    
    -- 获取当前状态
    local targetHealth = UnitHealth("target")
    -- 使用AutoCat的DOT检测系统
    local rakeDot = AC.Event.GetRakeDot()
    local ripDot = AC.Event.GetRipDot()
    local myPower = UnitMana("player")
    local comboPoints = GetComboPoints("target")
    local energyConserve = AC.Event.GetRestoredEnergy()
    local isBehind = AC.Event.CheckBehind(AC.Options.useUnitXP)
    local hasPredatorReveal = AC.Lib.Buff("节能施法")
    local dmMana = AC.Lib.DriudMana()
    local gcdLeft = AC.Lib.GetSpellCooldown("愤怒")
    local isStealthed = AC.Lib.Buff("潜行")
    -- 神像选择逻辑
    if AC.Options.idolDance == 1 then
        -- 满足凶猛撕咬或撕扯条件时使用腐败翡翠神像
        if (comboPoints >= 5 and myPower >= 35) or
           (comboPoints >= 3 and myPower >= 30 and GetTime() - AC.Combat.t1 > 9) or
           (not ripDot and comboPoints > 0 and targetHealth > AC.Options.rendValue and myPower >= 30) then
            UseItemByName("腐败翡翠神像")
        else
            -- 不满足条件时使用凶猛神像
            UseItemByName("凶猛神像")
        end
    end
    
    -- 保持猛虎之怒（积极版本）
    if AC.Options.tigerFury == 1 and not AC.Lib.Buff("猛虎之怒") and myPower >= 30 then
        CastSpellByName("猛虎之怒")
        AC.Combat.tigerFuryTimer = GetTime()
        return
    end

    -- 计算流血状态数量（用于清晰预兆判断）
    local bleedcount = 0
    if rakeDot then bleedcount = bleedcount + 1 end
    if ripDot then bleedcount = bleedcount + 1 end


    -- 清晰预兆触发时，在背面且三流血状态下优先撕碎
    if hasPredatorReveal and isBehind and bleedcount < 3 and not AC.Lib.Buff("血袭") then
        CastSpellByName("撕碎")
        return
    end

    -- 补撕扯（5星）
    if not ripDot and comboPoints >= 5 and targetHealth > AC.Options.rendValue and (myPower >= 30 or hasPredatorReveal) then
        CastSpellByName("撕扯")
        AC.Combat.t1 = GetTime()
        return
    end

    -- 补扫击
    if not rakeDot and (myPower >= AC.Config.rakeEnergy or hasPredatorReveal) and not AC.Lib.Buff("血袭") then
        CastSpellByName("扫击")
        return
    end

    -- 凶猛撕咬（满星消耗）
    if comboPoints >= 5 and myPower >= 35 then
        CastSpellByName("凶猛撕咬")
        return
    end

    -- 撕裂神像触发时撕碎
    if isBehind and AC.Lib.Buff("撕裂神像") and (myPower >= AC.Config.tearEnergy or hasPredatorReveal) then
        CastSpellByName("撕碎")
        return
    end

    -- 高能量撕碎策略（能量富余时）
    if isBehind and myPower >= 75 then
        CastSpellByName("撕碎")
        return
    end

    -- 爪击填充空挡
    if myPower >= AC.Config.clawEnergy or hasPredatorReveal then
        CastSpellByName("爪击")
        return
    end

    -- 变身回能逻辑
    if dmMana >= AC.Config.shapeshiftMana and gcdLeft < 0.05 and
       not AC.Lib.Buff("狂暴") and not hasPredatorReveal and
       (myPower < AC.Config.clawEnergy - 24 or (AC.Combat.tigerFuryTimer and GetTime() - AC.Combat.tigerFuryTimer > 10 and myPower < AC.Config.rakeEnergy)) then
        CastSpellByName("重整")
        return
    end

    -- 补精灵之火（能量不足时的填充）
    if not AC.Lib.Buff("精灵之火（野性）", "target") and 
        AC.Options.faerieFire == 1 and AC.Lib.SpellReady("精灵之火（野性）") and
        not isStealthed and myPower < 30 then
        CastSpellByName("精灵之火（野性）")
        return
    end


    
    -- 三星撕咬（已过9秒）
    -- if comboPoints > 2 and myPower < 60 and not hasPredatorReveal and GetTime() - AC.Combat.t1 > 9 then
    --     CastSpellByName("凶猛撕咬")
    --     return
    -- end
    
    -- 强化攻击处理
    if AC.Lib.Buff("强化攻击") then
        if isBehind and myPower >= AC.Config.tearEnergy then
            CastSpellByName("撕碎")
        else
            CastSpellByName("爪击")
        end
        return
    end

    -- 爪击填充空挡
    if myPower >= AC.Config.clawEnergy then
        CastSpellByName("爪击")
        return
    end
    
    -- 能量空挡时补精灵之火
    if myPower < AC.Config.clawEnergy and
       myPower >= AC.Config.clawEnergy - 20 and
       not AC.Lib.Buff("精灵之火（野性）", "target") and
       AC.Options.faerieFire == 1 and
       AC.Lib.SpellReady("精灵之火（野性）") then
        CastSpellByName("精灵之火（野性）")
    end
end

-- 背刺猫攻击流程
function AC.Combat.Backstab()
    local myPower = UnitMana("player")
    local dmMana = AC.Lib.DriudMana()
    local energyConserve = AC.Event.GetRestoredEnergy()
    local comboPoints = GetComboPoints("target")
    local isBehind = AC.Event.CheckBehind(AC.Options.useUnitXP)
    local hasPredatorReveal = AC.Lib.Buff("节能施法")
    local gcdLeft = AC.Lib.GetSpellCooldown("愤怒")

    -- 神像选择逻辑
    if AC.Options.idolDance == 1 then
        -- 满足凶猛撕咬条件时使用腐败翡翠神像
        if comboPoints >= 3 and myPower < 60 and not hasPredatorReveal then
            UseItemByName("腐败翡翠神像")
        else
            -- 不满足条件时使用凶猛神像
            UseItemByName("凶猛神像")
        end
    end

    -- 清晰预兆触发时，根据正反面选择撕碎/爪击
    if hasPredatorReveal then
        if isBehind then
            CastSpellByName("撕碎")
            return
        else
            CastSpellByName("爪击")
            return
        end
    end

    -- 三星，无清晰预兆，再撕咬
    if comboPoints > 2 and (myPower < 60 and not hasPredatorReveal) then
        CastSpellByName("凶猛撕咬")
    end

    -- 根据正反面撕碎/爪击填充空挡
    if myPower >= AC.Config.tearEnergy and isBehind then
        CastSpellByName("撕碎")
    end
    if myPower >= AC.Config.clawEnergy and not isBehind then
        CastSpellByName("爪击")
    end

    -- 变身回能
    -- if dmMana >= AC.Config.shapeshiftMana and energyConserve < 1.7 and gcdLeft < 0.05
    --    and not AC.Lib.Buff("狂暴") and not hasPredatorReveal
    --    and myPower < AC.Config.tearEnergy - 20 then
    --     if AC.Options.catFormMacro == 1 then
    --         CastSpellByName("追踪人形生物")
    --     else
    --         CastSpellByName("猎豹形态(变形)")
    --     end
    -- end
    if dmMana >= AC.Config.shapeshiftMana and energyConserve < 1.7
       and not AC.Lib.Buff("狂暴") and not hasPredatorReveal
       and myPower < AC.Config.tearEnergy - 20 then
        CastSpellByName("重整")
    end

    -- 能量空挡时补精灵之火
    if myPower < AC.Config.tearEnergy and myPower >= AC.Config.tearEnergy - 20
       and not AC.Lib.Buff("精灵之火（野性）", "target")
       and AC.Options.faerieFire == 1
       and AC.Lib.SpellReady("精灵之火（野性）") then
        CastSpellByName("精灵之火（野性）")
    end
end

-- 流血撕碎攻击流程
AC.Combat.rendBleedT1 = nil
AC.Combat.rendBleedTigerFuryTimer = nil

function AC.Combat.RendBleed()
    -- 初始化计时器
    if not AC.Combat.rendBleedT1 then AC.Combat.rendBleedT1 = GetTime() - 12 end
    if not AC.Combat.rendBleedTigerFuryTimer then AC.Combat.rendBleedTigerFuryTimer = GetTime() - 18 end
    
    -- 获取当前状态
    local targetHealth = UnitHealth("target")
    -- 使用AutoCat的DOT检测系统
    local rakeDot = AC.Event.GetRakeDot()
    local ripDot = AC.Event.GetRipDot()
    local myPower = UnitMana("player")
    local comboPoints = GetComboPoints("target")
    local isBehind = AC.Event.CheckBehind(AC.Options.useUnitXP)
    local hasPredatorReveal = AC.Lib.Buff("节能施法")
    local dmMana = AC.Lib.DriudMana()
    local gcdLeft = AC.Lib.GetSpellCooldown("愤怒")
    
    -- 神像选择逻辑
    if AC.Options.idolDance == 1 then
        -- 满足凶猛撕咬或撕扯条件时使用腐败翡翠神像
        if (comboPoints >= 5 and myPower >= 35) or
           (comboPoints >= 3 and myPower >= 30 and GetTime() - AC.Combat.rendBleedT1 > 9) or
           (not ripDot and comboPoints > 0 and targetHealth > AC.Options.rendValue and myPower >= 30) then
            UseItemByName("腐败翡翠神像")
        else
            -- 不满足条件时使用凶猛神像
            UseItemByName("凶猛神像")
        end
    end
    
    -- 保持猛虎之怒（积极版本）
    if AC.Options.tigerFury == 1 and not AC.Lib.Buff("猛虎之怒") and myPower >= 30 then
        CastSpellByName("猛虎之怒")
        AC.Combat.rendBleedTigerFuryTimer = GetTime()
        return
    end

    -- 计算流血状态数量（用于清晰预兆判断）
    local bleedcount = 0
    if rakeDot then bleedcount = bleedcount + 1 end
    if ripDot then bleedcount = bleedcount + 1 end


    -- 清晰预兆触发时，根据正反面选择撕碎/爪击（RendBleed模式）
    if hasPredatorReveal then
        if isBehind then
            CastSpellByName("撕碎")
            return
        else
            CastSpellByName("爪击")
            return
        end
    end

    -- 补扫击
    if not rakeDot and myPower >= AC.Config.rakeEnergy and not AC.Lib.Buff("血袭") then
        CastSpellByName("扫击")
        return
    end
    
    -- 补撕扯
    if not ripDot and comboPoints > 0 and targetHealth > AC.Options.rendValue and (myPower >= 30 or hasPredatorReveal) then
        CastSpellByName("撕扯")
        AC.Combat.rendBleedT1 = GetTime()
        return
    end
    
    -- 凶猛撕咬（满星消耗）
    if comboPoints >= 5 and myPower >= 35 then
        CastSpellByName("凶猛撕咬")
        return
    end

    -- 撕裂神像触发时撕碎
    if isBehind and AC.Lib.Buff("撕裂神像") and (myPower >= AC.Config.tearEnergy or hasPredatorReveal) then
        CastSpellByName("撕碎")
        return
    end
    
    -- 三星撕咬（已过9秒）
    if comboPoints > 2 and myPower < 60 and not hasPredatorReveal and GetTime() - AC.Combat.rendBleedT1 > 9 then
        CastSpellByName("凶猛撕咬")
        return
    end

    -- 高能量撕碎策略（能量富余时）
    if isBehind and myPower >= 75 then
        CastSpellByName("撕碎")
        return
    end
    
    -- 爪击填充空挡
    if myPower >= AC.Config.clawEnergy or hasPredatorReveal then
        CastSpellByName("爪击")
        return
    end

    -- 变身回能逻辑
    if dmMana >= AC.Config.shapeshiftMana and
        not AC.Lib.Buff("狂暴") and not hasPredatorReveal and
        (myPower < AC.Config.clawEnergy - 24 or (AC.Combat.rendBleedTigerFuryTimer and GetTime() - AC.Combat.rendBleedTigerFuryTimer > 10 and myPower < AC.Config.rakeEnergy)) then
        CastSpellByName("重整")
        return
    end
    
    -- 补精灵之火（能量不足时的填充）
    if not AC.Lib.Buff("精灵之火（野性）", "target") and 
        AC.Options.faerieFire == 1 and AC.Lib.SpellReady("精灵之火（野性）") and
        myPower < 30 then
        CastSpellByName("精灵之火（野性）")
    end
end

-- 注册斜杠命令，仅绑定/AutoCat命令
SLASH_AUTOCAT1 = "/autocat"
SLASH_AUTOCAT2 = "/AutoCat"

-- 处理斜杠命令
SlashCmdList["AUTOCAT"] = function(msg)
    if msg == "debug on" then
        Cat:SetDebugging(true)
    elseif msg == "debug off" then
        Cat:SetDebugging(false)  
    elseif string.find(msg, "^debug level %d+$") then
        local level = tonumber(string.gsub(msg, "debug level ", ""))
        if level >= 1 and level <= 3 then
            Cat:SetDebugLevel(level)
        end
    else
        -- 如果有参数，尝试转换为数字
        local param = nil
        if msg and msg ~= "" then
            param = tonumber(msg)
        end
        
        -- 调用AutoCat.Run函数，传入可能的参数
        AutoCat.Run(param)
    end
end
