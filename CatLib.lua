-- 创建全局AutoCat对象
AutoCat = AutoCat or {}
local AC = AutoCat -- 简写以方便引用

-- 初始化AutoCat的命名空间
AC.Lib = AC.Lib or {} -- 库函数
AC.Config = AC.Config or {} -- 配置
AC.Event = AC.Event or {} -- 事件相关

-- 创建本地变量以存储原来的全局变量
local _tipColor = "|cFF906d96Cat Tip:|r |cFFf9cdfd"

-- 配置变量
AC.Config.targetBleed = true -- 目标是否可以流血
AC.Config.targetArcaneImmune = false -- 目标是否奥术免疫
AC.Config.targetNatureImmune = false -- 目标是否自然免疫
AC.Config.clawEnergy = 40 -- 爪击所需能量
AC.Config.rakeEnergy = 35 -- 扫击所需能量
AC.Config.tearEnergy = 60 -- 撕扯所需能量
AC.Config.rakeDuration = 9 -- 扫击持续时间
AC.Config.ripDuration = 12 -- 撕扯持续时间
AC.Config.shapeshiftMana = 435 -- 变身所需蓝量
AC.Config.manaValue = 1000 -- 当前蓝量

-- 创建本地工具提示框
local CatPlusTooltip = CreateFrame("GameTooltip", "CatPlusTooltip", UIParent, "GameTooltipTemplate")

-- 开始自动攻击
function AC.Lib.StartAttack()
	
	if ( not PlayerFrame.inCombat ) then CastSpellByName("攻击") end
	for A=1,172 do if IsAttackAction(A)then if not IsCurrentAction(A)then UseAction(A) end end end
end

-- 获取对象buff
function AC.Lib.Buffed(buffname, unit)
	CatPlusTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	if (not buffname) then
		return;
	end;
	if (not unit) then
		unit="player";
	end;
	if string.lower(unit) == "mainhand" then
		CatPlusTooltip:ClearLines();
		CatPlusTooltip:SetInventoryItem("player",GetInventorySlotInfo("MainHandSlot"));
		for i = 1,CatPlusTooltip:NumLines() do
			if getglobal("CatPlusTooltipTextLeft"..i):GetText() == buffname then
				return true
			end;
		end
		return false
	end
	if string.lower(unit) == "offhand" then
		CatPlusTooltip:ClearLines();
		CatPlusTooltip:SetInventoryItem("player",GetInventorySlotInfo("SecondaryHandSlot"));
		for i=1,CatPlusTooltip:NumLines() do
			if getglobal("CatPlusTooltipTextLeft"..i):GetText() == buffname then
				return true
			end;
		end
		return false
	end
	local i = 1;
	while UnitBuff(unit, i) do
		CatPlusTooltip:ClearLines();
		CatPlusTooltip:SetUnitBuff(unit,i);
		if CatPlusTooltipTextLeft1:GetText() == buffname then
			return true, i
		end;
		i = i + 1;
	end;
	local i = 1;
	while UnitDebuff(unit, i) do
		CatPlusTooltip:ClearLines();
		CatPlusTooltip:SetUnitDebuff(unit,i);
		if CatPlusTooltipTextLeft1:GetText() == buffname then
			return true, i
		end;
		i = i + 1;
	end;
end

function AC.Lib.PlayerBuffNameByIndex(index)
	CatPlusTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	CatPlusTooltip:SetPlayerBuff(index);
	local buffName = CatPlusTooltipTextLeft1:GetText();
	CatPlusTooltip:Hide();

	if buffName then
		return true, buffName
	end

	return false, "未发现BUFF"
end

-- 内部调用
function AC.Lib.GetBuffNameByIndex(unit, index)
	if UnitBuff(unit, index) then
		CatPlusTooltip:SetOwner(UIParent, "ANCHOR_NONE");
		CatPlusTooltip:SetUnitBuff(unit, index);
		local buffName = CatPlusTooltipTextLeft1:GetText();
		CatPlusTooltip:Hide();

		if buffName then
			return true, buffName
		end
	end

	return false, "未发现BUFF"
end

-- 内部调用
function AC.Lib.GetDebuffNameByIndex(unit, index)
	if UnitDebuff(unit, index) then
		CatPlusTooltip:SetOwner(UIParent, "ANCHOR_NONE");
		CatPlusTooltip:SetUnitDebuff(unit, index);
		local buffName = CatPlusTooltipTextLeft1:GetText();
		CatPlusTooltip:Hide();

		if buffName then
			return true, buffName
		end
	end

	return false, "未发现BUFF"
end

-- 查找 Aura（BUFF 或 DEBUFF）并返回 (found, index)
function AC.Lib.Buff(buffName, unit)
	unit = unit or "player";  -- 默认检查玩家自己
	local maxIndex = 64;

	if unit == "player" then
		-- 扫描buff位
		for i = 0, maxIndex do
			-- 通过索引尝试访问buff
			local found, name = AC.Lib.PlayerBuffNameByIndex(i)
			if not found then
				break
			end

			-- 找到buff，并名称正确
			if name==buffName then
				return true, i
			end
		end
	else
		-- 扫描debuff位
		for i = 1, maxIndex do
			-- 通过索引尝试访问buff
			local found, name = AC.Lib.GetDebuffNameByIndex(unit,i)
			if not found then
				break
			end

			-- 找到buff，并名称正确
			if name==buffName then
				return true, i
			end
		end

		-- 扫描buff位
		for i = 1, maxIndex do
			-- 通过索引尝试访问buff
			local found, name = AC.Lib.GetBuffNameByIndex(unit,i)
			if not found then
				break
			end

			-- 找到buff，并名称正确
			if name==buffName then
				return true, i
			end
		end
	end

	return false, -1  -- 未找到
end

-- 取消自己身上的buff
function AC.Lib.CancelBuffByName(buffName)
	local f, i = AC.Lib.Buff(buffName)
	if f then
		CancelPlayerBuff(i)
	end
end


-- 获取技能是否CD结束
function AC.Lib.SpellReady(name)
	local spell_id = AC.Lib.GetSpellID(name)
	if GetSpellCooldown(spell_id, "spell") == 0 then
		return true
	end
	return false
end

-- 获取技能是否CD结束，增加可以判断还差多久结束
function AC.Lib.SpellReadyOffset(name, offset)
	if not offset then offset=0.5 end
	if AC.Lib.GetSpellCooldown(name) < offset then
		return true
	end
	return false
end

function AC.Lib.GetSpellCooldown(spell)
	local i = AC.Lib.GetSpellID(spell)
	local start, dur = GetSpellCooldown(i, "spell")
	local time = dur-(GetTime()-start);
	if time < 0 then time=0 end
	return time
end

function AC.Lib.GetSpellID(name)
	local i = 0
	local spellName = nil
	while spellName ~= name do
		i = i + 1
		spellName = GetSpellName(i, "spell")
	end
	return i
end

-- 获取当前姿态，战士、德鲁伊可用
function AC.Lib.GetShape(id)
	local _,_,a=GetShapeshiftFormInfo(id)
	if a then return true end
	return false
end

-- 德鲁伊变形后的蓝获取
function AC.Lib.DriudMana()
	-- Nampower扩展了变形状态下 UnitMana 的返回值。
	if AC.Event.nampowerEnabled then
		local e,m = UnitMana("player")
		if not m then
			return AC.Config.manaValue
		end
		return m
	end
	return AC.Config.manaValue
end

-- 查找背包中的物品（内部函数，返回bag和slot）
local function FindItemInBag(itemName)
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local _, _, name = string.find(itemLink, "%[(.-)%]")
                if name == itemName then
                    return bag, slot
                end
            end
        end
    end
    return nil, nil
end

-- 检查物品是否在背包中
function AC.Lib.HasItemInBag(itemName)
	local bag, slot = FindItemInBag(itemName)
	return bag ~= nil
end

-- 使用背包中物品
function AC.Lib.UseItemByName(itemName)
	local bag, slot = FindItemInBag(itemName)
	if not bag then
		return false
	end
	
	-- 创建隐藏的tooltip用于扫描物品描述
	if not AC.ItemScanTooltip then
		AC.ItemScanTooltip = CreateFrame("GameTooltip", "AutoCatItemScanTooltip", nil, "GameTooltipTemplate")
		AC.ItemScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
	end
	
	-- 清除之前的内容并设置当前物品
	AC.ItemScanTooltip:ClearLines()
	AC.ItemScanTooltip:SetBagItem(bag, slot)
	
	-- 扫描tooltip文本查找冷却时间相关字样
	local hasCooldownRemaining = false
	for i = 1, AC.ItemScanTooltip:NumLines() do
		local line = getglobal("AutoCatItemScanTooltipTextLeft" .. i)
		if line and line:GetText() then
			local text = line:GetText()
			-- 检查是否包含冷却时间相关字样
			if text and (strfind(text, "冷却时间剩余") or strfind(text, "冷却时间：")) then
				hasCooldownRemaining = true
				break
			end
		end
	end
	
	-- 如果有冷却时间剩余，不使用物品并返回false
	if hasCooldownRemaining then
		return false
	end
	
	-- 没有冷却时间剩余，正常使用物品
	UseContainerItem(bag, slot)
	return true
end

-- 德鲁伊刷新特性状态
function AC.Lib.DriudRefreshInfo()
	-- 非德鲁伊，则无效执行
	local _, class = UnitClass("player")
	if class ~= "DRUID" then
		return 0
	end

	local oldTear = AC.Config.tearEnergy
	local oldClaw = AC.Config.clawEnergy
	local oldRake = AC.Config.rakeEnergy
	local oldRakeDuration = AC.Config.rakeDuration
	local oldRipDuration = AC.Config.ripDuration
	local oldDriudShapeshift = AC.Config.shapeshiftMana

	local count = 0
	if AC.Lib.CheckInventoryItemName(1,"起源皮盔") then count=count+1 end
	if AC.Lib.CheckInventoryItemName(3,"起源肩垫") then count=count+1 end
	if AC.Lib.CheckInventoryItemName(5,"起源长袍") then count=count+1 end
	if AC.Lib.CheckInventoryItemName(7,"起源短裤") then count=count+1 end
	if AC.Lib.CheckInventoryItemName(8,"起源便靴") then count=count+1 end

	local rage = 0
	if count > 2 then rage = 3 end

	-- 保存撕碎能量为常量
	-- 60固定 - 天赋（强化撕碎）- T2.5三件套
	AC.Config.tearEnergy = 60 - AC.Lib.IsTalentLearned(2,10)*6 - rage

	if AC.Lib.CheckInventoryItemName(18,"凶猛神像") then rage=rage+3 end

	-- 常量回归，重新检测
	AC.Config.rakeDuration = 9
	AC.Config.ripDuration = 12
	if AC.Lib.CheckInventoryItemName(18,"野蛮神像") then
		AC.Config.rakeDuration = AC.Config.rakeDuration * 0.9
		AC.Config.ripDuration = AC.Config.ripDuration * 0.9
	end

	-- 保存爪击能量为常量
	AC.Config.clawEnergy = 45 - AC.Lib.IsTalentLearned(2,1) - rage
	AC.Config.rakeEnergy = 40 - AC.Lib.IsTalentLearned(2,1) - rage

	-- 保存变身所需要的蓝量
	if AC.Lib.CheckInventoryItemName(18,"狂野变形者神像") then
		AC.Config.shapeshiftMana = 435 - 75
	else
		AC.Config.shapeshiftMana = 435
	end
	AC.Config.shapeshiftMana = math.floor(AC.Config.shapeshiftMana * (1 - AC.Lib.IsTalentLearned(1,8) * 0.1))

	-- 信息提示状态变化
	if Cat:IsDebugging() then -- 开关，是否显示变化信息
		if oldDriudShapeshift ~= AC.Config.shapeshiftMana then
			DEFAULT_CHAT_FRAME:AddMessage(_tipColor.."变身耗蓝: "..AC.Config.shapeshiftMana.."|r")
		end
		if oldTear ~= AC.Config.tearEnergy then
			DEFAULT_CHAT_FRAME:AddMessage(_tipColor.."[撕碎] 能量消耗: "..AC.Config.tearEnergy.."|r")
		end
		if oldClaw ~= AC.Config.clawEnergy then
			DEFAULT_CHAT_FRAME:AddMessage(_tipColor.."[爪击] 能量消耗: "..AC.Config.clawEnergy.."|r")
		end
		if oldRake ~= AC.Config.rakeEnergy then
			DEFAULT_CHAT_FRAME:AddMessage(_tipColor.."[扫击] 能量消耗: "..AC.Config.rakeEnergy.."|r")
		end
		if oldRakeDuration ~= AC.Config.rakeDuration then
			DEFAULT_CHAT_FRAME:AddMessage(_tipColor.."[扫击] 持续时间: "..AC.Config.rakeDuration.."|r")
		end
		if oldRipDuration ~= AC.Config.ripDuration then
			DEFAULT_CHAT_FRAME:AddMessage(_tipColor.."[撕扯] 持续时间: "..AC.Config.ripDuration.."|r")
		end
	end

	-- 同时检查饰品可用性
	if AC.CheckTrinketUsability then
		if Cat and Cat:IsDebugging() then
			DEFAULT_CHAT_FRAME:AddMessage("|cFF906d96Trinket Debug:|r 从 CatLib 调用 CheckTrinketUsability")
		end
		AC.CheckTrinketUsability()
	else
		if Cat and Cat:IsDebugging() then
			DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Trinket Error:|r CheckTrinketUsability 函数不存在!")
		end
	end

	return rage
end

-- 检查身上装备格子的装备名称
function AC.Lib.CheckInventoryItemName(slot, name)
	local Link = GetInventoryItemLink("player",slot)
	if Link and strfind(Link,name) then return true end
	return false
end

-- 获取天赋参数
function AC.Lib.IsTalentLearned(tabIndex, talentIndex)
	local _, _, _, _, rank = GetTalentInfo(tabIndex, talentIndex)
	return rank
end


-- 无法流血的怪物列表
local monsterList = {
	-- 木喉
	["裂地者欧曼诺斯"] = true,
	["欧曼诺斯的颤岩"] = true,

	-- K40
    ["地狱之怒碎片"] = true,
    ["噩梦爬行者"] = true,
    ["麦迪文的回响"] = true,
    ["恶魔之心"] = true,
    ["战争使者监军"] = true,
    ["兵卒"] = true,
    ["共鸣水晶"] = true,
    ["徘徊的魔法师"] = true,
    ["徘徊的占星家"] = true,
    ["徘徊的魔术师"] = true,
    ["徘徊的工匠"] = true,
    ["鬼灵训练师"] = true,
    ["荒芜的入侵者"] = true,

	-- 卡拉赞下层
	["幻影守卫"] = true,
	["幽灵厨师"] = true,
	["闹鬼铁匠"] = true,
	["幻影仆从"] = true,
	["莫罗斯"] = true,

	-- NAXX
    ["瘟疫战士"] = true,
    ["白骨构造体"] = true,
    ["邪恶之斧"] = true,
    ["邪恶法杖"] = true,
    ["邪恶之剑"] = true,
    ["纳克萨玛斯之魂"] = true,
    ["纳克萨玛斯之影"] = true,
    ["憎恨吟唱者"] = true,
    ["死灵骑士"] = true,
    ["死灵骑士卫兵"] = true,
    ["骷髅骏马"] = true,

	-- TAQ

	-- 黑龙
	["奥妮克希亚火嗣"] = true,

	-- FX
	["莫阿姆"] = true,

	-- MC
    ["熔核巨人"] = true,
    ["暗炉卫士"] = true,
    ["暗炉织焰者"] = true,
    ["暗炉圣职者"] = true,
    ["法师领主索瑞森"] = true,
	["巫王索瑞森"] = true,
	["熔核摧毁者"] = true,

	-- STSM
	["安娜丝塔丽男爵夫人"] = true,
	["埃提耶什"] = true,

	-- 龙吼居所
	["被遗忘的先祖"] = true,
	["哈尔甘·红标"] = true,

	-- 黑石深渊
	["弗莱拉斯大使"] = true,
	["安格雷尔"] = true,
	["西斯雷尔"] = true,
	["多普雷尔"] = true,
	["格鲁雷尔"] = true,
	["瓦勒雷尔"] = true,
	["黑特雷尔"] = true,
	["杜姆雷尔"] = true,
	["玛格姆斯"] = true,

	-- 玛拉顿
	["瑟莱德丝公主"] = true,

	-- 暴风城地牢
	["戴米安"] = true,

	-- 其他
    ["黑衣守卫斥候"] = true,
    ["哀嚎的女妖"] = true,
    ["尖叫的女妖"] = true,
    ["无眼观察者"] = true,
    ["黑暗法师"] = true,
    ["幽灵训练师"] = true,
    ["受难的上层精灵"] = true,
    ["死亡歌手"] = true,
    ["恐怖编织者"] = true,
    ["哀嚎的死者"] = true,
    ["亡鬼幻象"] = true,
    ["恐惧骸骨"] = true,
    ["骷髅刽子手"] = true,
    ["骷髅剥皮者"] = true,
    ["骷髅守护者"] = true,
    ["骷髅巫师"] = true,
    ["骷髅军官"] = true,
    ["骷髅侍僧"] = true,
    ["游荡的骷髅"] = true,
    ["骷髅铁匠"] = true,
    ["鬼魅随从"] = true,
    ["艾德雷斯妖灵"] = true,
    ["天灾勇士"] = true,
	["天灾卫兵"] = true,
    ["不安宁的阴影"] = true,
    ["不死的看守者"] = true,
    ["哀嚎的鬼怪"] = true,
    ["被诅咒的灵魂"] = true,
    ["不死的居民"] = true,
    ["不死的看守者"] = true,
    ["幽灵工人"] = true,
	["鬼灵工人"] = true,
	["徘徊的农夫"] = true,
	["被诅咒的水兵"] = true,
	["峭壁咆哮者"] = true,
	["峭壁行者"] = true,
	["峭壁击碎者"] = true,
	["古拉巴什狂暴者"] = true,
	["腐烂古树"] = true,
	["黑色新娘"] = true,
	["阿克提阿斯"] = true,
}
-- 元素生物,机械中的白名单列表
local MPmonsterWhiteList = {

	-- K40
    ["失控的骑士"] = true,

	-- MC
    ["加尔"] = true,
    ["焚化者古雷曼格"] = true,
	["巴萨尔萨"] = true,
	["斯摩达利斯"] = true,

	-- 玛拉顿
	["锐刺鞭笞者"] = true,

	-- World
    ["灌木塑根者"] = true,
    ["灌木露水收集者"] = true,
    ["长瘤的灌木兽"] = true,
	["焦油潜伏者"] = true,
	["焦油爬行者"] = true,
	["焦油兽王"] = true,
	["焦油兽"] = true,
}

-- 奥术免疫怪物名单
local arcaneImmuneList = {
    -- K40
    ["溢出的法力"] = true,
    ["异常的法力"] = true,
    ["不稳定的奥术元素"] = true,
    ["破碎的奥术元素"] = true,
    ["阿诺玛鲁斯"] = true,
    ["绿色亲和"] = true,
}

-- 自然免疫怪物名单
local natureImmuneList = {
	["被污染的胶团"] = true,
	["落潭"] = true,
	["魔力亲和"] = true,
}

-- 精灵之火黑名单
local faerieFireBlockList = {
	-- 木喉
	["被污染的胶团"] = true,

	-- NAXX
	["鬼灵训练师"] = true,
	["鬼灵坐骑"] = true,
	["鬼灵骑兵"] = true,

	-- TAQ
	["维克洛尔大帝"] = true,
	["维克尼拉斯大帝"] = true,

	-- BWL
	["黑翼缚法者"] = true,

	-- 神庙
	["德拉维沃尔"] = true,

	-- 世界BOSS
	["桑德兰王子"] = true,

	-- 世界
	["熔岩元素"] = true,
	["涅玛丝拉"] = true,
	["雷霆流放者"] = true,
	["狂风漩涡"] = true,

	-- 黑石深渊
	["达格兰·索瑞森大帝"] = true,
}

-- 检验单位能否流血
function AC.Lib.CanBleed(unit)
	unit = unit or "target"
	local name = UnitName(unit)

	if not name then
		return false
	end

	-- 元素生物,机械，直接认定为不可流血
	local creature = UnitCreatureType(unit) or "其它"
	local position = string.find("元素生物,机械", creature)
	if position then
		-- 元素生物与机械中的白名单
		if MPmonsterWhiteList[name] == true then
			return true
		end
		return false
	end

	-- 判断怪物名单
	if monsterList[name] == true then
		return false
	end

	return true
end

-- 检验单位是否可被施放精灵之火
function AC.Lib.CanFaerieFire(unit)
	unit = unit or "target"
	local name = UnitName(unit)

	if not name then
		return false
	end

	if faerieFireBlockList[name] == true then
		return false
	end

	return true
end

-- 鸟德可以利用的欧曼诺斯共鸣伤害加成
local ormanosDamageBonus = {
	["板岩的共鸣"] = "arcane",
	["花岗岩的共鸣"] = "nature",
}

function AC.Lib.GetOrmanosDamageBonus(unit)
	unit = unit or "target"
	if UnitName(unit) ~= "裂地者欧曼诺斯" then
		return nil
	end

	local i = 1
	while true do
		local found, name = AC.Lib.GetBuffNameByIndex(unit, i)
		if not found then
			break
		end
		if ormanosDamageBonus[name] then
			return ormanosDamageBonus[name], name
		end
		i = i + 1
	end

	i = 1
	while true do
		local found, name = AC.Lib.GetDebuffNameByIndex(unit, i)
		if not found then
			break
		end
		if ormanosDamageBonus[name] then
			return ormanosDamageBonus[name], name
		end
		i = i + 1
	end

	return nil
end

-- 检验单位是否奥术免疫
function AC.Lib.IsArcaneImmune(unit)
	unit = unit or "target"
	local name = UnitName(unit)

	if not name then
		return false
	end

	if arcaneImmuneList[name] == true then
		return true
	end

	-- 大理石共鸣会使裂地者欧曼诺斯免疫奥术伤害
	if name == "裂地者欧曼诺斯" and AC.Lib.Buff("大理石的共鸣", unit) then
		return true
	end

	return false
end

-- 检验单位是否自然免疫
function AC.Lib.IsNatureImmune(unit)
	unit = unit or "target"
	local name = UnitName(unit)

	if not name then
		return false
	end

	if natureImmuneList[name] == true then
		return true
	end

	-- 石英共鸣会使裂地者欧曼诺斯免疫自然伤害
	if name == "裂地者欧曼诺斯" and AC.Lib.Buff("石英的共鸣", unit) then
		return true
	end

	return false
end

-- 检查目标是否在近战距离内（用于饰品等物品使用）
-- 同时检查目标是否为敌对单位且未死亡
function AC.Lib.IsTargetInRange()
	-- 检查目标是否存在、是否死亡、是否为敌对单位
	if not UnitExists("target") or UnitIsDead("target") or not UnitCanAttack("player", "target") then
		return false
	end
	
	-- 优先使用TargetDistance的UnitXP判断逻辑
	if AC.Event.UnitXP_SP3 then
		-- 近战距离：距离小于1码
		local distance = UnitXP("distanceBetween", "player", "target")
		return (distance and distance < 2)
	else
		-- 回退到原有的距离判断
		return CheckInteractDistance("target", 3)  -- 近战交互距离
	end
end

-- 统一的目标类型判断函数
function AC.Lib.GetTargetType()
	if not UnitExists("target") then
		return "none"
	end
	
	local targetMaxHealth = UnitHealthMax("target")
	
	-- 统一判断标准：世界Boss或血量大于等于200000的为Boss，其他都是小怪
	local classification = UnitClassification("target")
	local isWorldBoss = classification == "worldboss"
	
	-- 如果没有血量信息，只检查是否为世界Boss
	if not targetMaxHealth then
		if isWorldBoss then
			return "boss"
		else
			return "trash"  -- 无法获取血量信息的目标默认为小怪
		end
	end
	
	if isWorldBoss or targetMaxHealth >= 200000 then
		return "boss"
	else
		return "trash"
	end
end

-- 判断目标是否为小怪
function AC.Lib.IsTrashTarget()
	return AC.Lib.GetTargetType() == "trash"
end

-- 判断目标是否为Boss
function AC.Lib.IsBossTarget()
	return AC.Lib.GetTargetType() == "boss"
end

