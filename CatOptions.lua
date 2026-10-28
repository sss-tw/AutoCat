-- 插件核心对象由 Core.lua 创建，不再依赖 Ace2。
Cat = Cat or {}

-- 默认配置
local defaultConfig = {
        -- 战斗设置
        combat = {
                -- 技能模式
                ["type"] = 1,               -- 选择一键宏的技能模式，取值范围(1,2,3,4)
                low_health_backstab = false, -- 自动模式下目标低血量时切换为背刺流
                low_health_backstab_threshold = 100000, -- 低血量背刺流触发阈值
                use_unitxp = true,      -- 是否开启UnitXP，用于强化判断正反面
                tiger_fury = true,      -- 是否保持猛虎之怒
                faerie_fire = true,     -- 是否自动补精灵之火
                faerie_fire_pull = false,  -- 是否使用精灵火开怪
                auto_pounce = true,     -- 是否自动使用突袭
                idol_dance = true,      -- 是否自动使用神像舞
                auto_loot = true,       -- 是否启用自动拾取
                loot_interval = 0.5,    -- 自动拾取间隔时间（秒）
                rend_threshold = 3000,  -- 撕扯使用阈值（目标血量高于此值时使用）
                avoid_player_target = true,  -- 如果目标是玩家则停止攻击并切换目标
                ot_bear_form = true,  -- OT时自动变熊
                cower_enabled = true, -- 仇恨超阈值时自动畏缩
                cower_threshold = 80,  -- 畏缩触发阈值（百分比）
                t35_burst = {
                        berserk = "use",         -- 狂暴：none/use/boss
                        trinket_upper = "use",   -- 上部饰品：none/use/boss/force
                        trinket_below = "none",  -- 下部饰品：none/use/boss/force
                        mighty_rage_potion = "use", -- 强效怒气药水：none/use/boss
                        haste_potion = "none",   -- 加速药水：none/use/boss
                        rake = true,             -- 爆发时补扫击
                        rip = true               -- 爆发时补撕扯
                }
        },
        -- 治疗设置
        healing = {
                rejuv_rank = 6         -- 愈合等级（1-9）
        },
        -- 饰品设置
        trinket = {
                upper = false,          -- 是否自动使用上部饰品
                below = true            -- 是否自动使用下部饰品
        },
        -- 消耗品设置
        consumable = {
                health_stone = true,         -- 是否自动使用治疗石
                health_stone_value = 3000,   -- 治疗石使用血线
                herbal_tea = true,           -- 是否自动使用草药茶
                herbal_tea_value = 2000,     -- 草药茶使用血线
                sacrifice_oil = false,       -- 是否自动使用献祭之油
                ot_limited_invulnerability = false,  -- OT吃有限无敌
                soul_speed_boss = false      -- Boss战中使用魂能之速
        },
        		-- 熊德设置（新增）
		bear = {
			-- 时机设置
			timing = {
				-- 槌击设置
				maul = {
					start = 7,  -- 起始怒气
				},
				-- 野蛮撕咬设置
				savageBite = {
					start = 40, -- 起始怒气
				},
				-- 挥击设置
				swipe = {
					use = true,   -- 是否使用挥击
					start = 20,   -- 起始怒气
				},
				-- 狂暴回复设置
				frenziedRegeneration = {
					start = 70,    -- 起始损失百分比
					swipe = true,  -- 狂暴回复时挥击
					savageBite = false, -- 狂暴回复时野蛮撕咬
					maul = false,  -- 狂暴回复时槌击
				},
				-- 狂怒设置
				enrage = {
					start = 20,    -- 起手怒气
					frenziedRegeneration = false, -- 狂暴回复时狂怒
				},
				-- 狂暴设置
				frenzied = {
					start = 30,    -- 起手损失百分比
					frenziedRegeneration = false, -- 狂暴回复时狂暴
				},
				-- 挫志咆哮
				demoralizingRoar = true,
				-- 精灵之火（野性）
				faerieFireWild = "ready", -- "ready"、"none"、"disable"
				-- 嘲讽
				growl = true,
			},
			-- 通报设置
			report = {
				["低吼"] = true,
				["挑战咆哮"] = true,
				["狂暴回复"] = true,
				["狂暴"] = true,
				["树皮术（野性）"] = true,
			}
		},
	-- 鸟德设置（新增）
	bird = {
		-- 战斗设置
		combat = {
			otInvulnerability = true,    -- OT吃有限无敌
			trashOnlyMoonfireWrath = false,  -- 小怪模式不打虫群
			idol_dance = true,           -- 是否自动使用神像舞
		},
		-- AOE设置（手动飓风连招）
		aoe = {
			usePotion = true,            -- 是否尝试使用有限无敌药水
			trinketUpper = true,         -- 是否尝试使用上饰品
			trinketBelow = true,         -- 是否尝试使用下饰品
		},
		-- 法力管理设置
		mana = {
			autoActivate = true,         -- 自动使用激活
			activateValue = 1000,        -- 激活触发法力阈值
			consumable = false,          -- 自动使用草药茶/符文
			consumableValue = 3000,       -- 草药茶/符文触发法力阈值
		},
	}
}

-- 确保AutoCat对象存在
AutoCat = AutoCat or {}

-- 饰品可用性缓存
AutoCat.TrinketUsable = {
	upper = false,  -- 上部饰品是否可用
	below = false   -- 下部饰品是否可用
}

-- 保存配置到AutoCat对象（保持原版结构）
AutoCat.Options = {
	["type"] = 1,
	lowHealthBackstab = 0,
	lowHealthBackstabThreshold = 100000,
	useUnitXP = 1,
	trinketUpper = 0,
	trinketBelow = 1,
	healthStone = 1,
	healthStoneValue = 3000,
	herbalTea = 1,
	herbalTeaValue = 2000,
	sacrificeOil = 0,
	otLimitedInvulnerability = 0,
	tigerFury = 1,
	faerieFire = 1,
	faerieFirePull = 0,
	pounce = 1,
	idolDance = 1,
	loot = 0,
	lootInterval = 1.5,
	rendValue = 3000,
	singleCatMode = 1,
	avoidPlayerTarget = 1,
        rejuvRank = 6,
        cowerEnabled = 1,
        cowerThreshold = 80,
        t35BurstBerserk = "use",
        t35BurstTrinketUpper = "use",
        t35BurstTrinketBelow = "none",
        t35BurstMightyRagePotion = "use",
        t35BurstHastePotion = "none",
        t35BurstRake = 1,
        t35BurstRip = 1
}

-- 初始化
function Cat:OnInitialize()
	-- 注册数据
	self:RegisterDB("AutoCatDB")
	-- 注册默认值
	self:RegisterDefaults('profile', defaultConfig)
	if not self.db.profile.combat.t35_burst then
		self.db.profile.combat.t35_burst = {}
	end
	local t35Burst = self.db.profile.combat.t35_burst
	if type(t35Burst.berserk) == "boolean" then t35Burst.berserk = t35Burst.berserk and "use" or "none" end
	if type(t35Burst.trinket_upper) == "boolean" then t35Burst.trinket_upper = t35Burst.trinket_upper and "use" or "none" end
	if type(t35Burst.trinket_below) == "boolean" then t35Burst.trinket_below = t35Burst.trinket_below and "use" or "none" end
	if type(t35Burst.mighty_rage_potion) == "boolean" then t35Burst.mighty_rage_potion = t35Burst.mighty_rage_potion and "use" or "none" end
	if type(t35Burst.haste_potion) == "boolean" then t35Burst.haste_potion = t35Burst.haste_potion and "use" or "none" end
	if t35Burst.berserk == nil then t35Burst.berserk = "use" end
	if t35Burst.trinket_upper == nil then t35Burst.trinket_upper = "use" end
	if t35Burst.trinket_below == nil then t35Burst.trinket_below = "none" end
	if t35Burst.mighty_rage_potion == nil then t35Burst.mighty_rage_potion = "use" end
	if t35Burst.haste_potion == nil then t35Burst.haste_potion = "none" end
	if t35Burst.rake == nil then t35Burst.rake = true end
	if t35Burst.rip == nil then t35Burst.rip = true end
	
	-- 应用配置
	self:ApplyConfig()
	
	-- 注册菜单项 - 四大分组：猫德、熊德、治疗、共通
	self.OnMenuRequest = {
		type = "group",
		handler = self,
		args = {
			cat = {
				type = "group",
				name = "猫德",
				desc = "设置猫德战斗相关选项",
				order = 1,
				args = {
					["type"] = {
						type = "text",
						name = "战斗模式",
						desc = "选择战斗模式",
						order = 1,
						get = function() 
							if self.db.profile.combat["type"] == 1 then
								return "auto"
							elseif self.db.profile.combat["type"] == 2 then
								return "backstab"
							elseif self.db.profile.combat["type"] == 3 then
								return "bleed"
							elseif self.db.profile.combat["type"] == 4 then
								return "rend"
							else
								return "auto"
							end
						end,
						set = function(value)
							if value == "auto" then
								self.db.profile.combat["type"] = 1
							elseif value == "backstab" then
								self.db.profile.combat["type"] = 2
							elseif value == "bleed" then
								self.db.profile.combat["type"] = 3
							elseif value == "rend" then
								self.db.profile.combat["type"] = 4
							else
								self.db.profile.combat["type"] = 1
							end
							self:ApplyConfig()
						end,
						validate = {
							["auto"] = "自动选择",
							["backstab"] = "仅背刺流",
							["bleed"] = "仅双流血",
							["rend"] = "流血撕碎"
						}
					},
					low_health_backstab = {
						type = "toggle",
						name = "低血量转背刺流",
						desc = "自动选择模式下，目标当前血量低于设定值时停止使用流血技能并切换为背刺流",
						order = 1.1,
						get = function() return self.db.profile.combat.low_health_backstab end,
						set = function(value)
							self.db.profile.combat.low_health_backstab = value
							self:ApplyConfig()
						end
					},
					low_health_backstab_threshold = {
						type = "range",
						name = "切换背刺血量",
						desc = "自动选择模式下，目标当前血量低于该值时切换为背刺流",
						order = 1.2,
						min = 10000,
						max = 200000,
						step = 10000,
						get = function() return self.db.profile.combat.low_health_backstab_threshold end,
						set = function(value)
							self.db.profile.combat.low_health_backstab_threshold = value
							self:ApplyConfig()
						end
					},
					use_unitxp = {
						type = "toggle",
						name = "UnitXP判断背后",
						desc = "是否开启UnitXP，用于强化判断正反面",
						order = 2,
						get = function() return self.db.profile.combat.use_unitxp end,
						set = function(value) 
							self.db.profile.combat.use_unitxp = value
							self:ApplyConfig()
						end
					},
					tiger_fury = {
						type = "toggle",
						name = "保持猛虎之怒",
						desc = "是否自动保持猛虎之怒",
						order = 3,
						get = function() return self.db.profile.combat.tiger_fury end,
						set = function(value) 
							self.db.profile.combat.tiger_fury = value
							self:ApplyConfig()
						end
					},
					faerie_fire = {
						type = "toggle",
						name = "自动精灵之火",
						desc = "是否自动补精灵之火",
						order = 4,
						get = function() return self.db.profile.combat.faerie_fire end,
						set = function(value) 
							self.db.profile.combat.faerie_fire = value
							self:ApplyConfig()
						end
					},
					faerie_fire_pull = {
						type = "toggle",
						name = "精灵火开怪",
						desc = "是否使用精灵火开怪",
						order = 5,
						get = function() return self.db.profile.combat.faerie_fire_pull end,
						set = function(value) 
							self.db.profile.combat.faerie_fire_pull = value
							self:ApplyConfig()
						end
					},
					auto_pounce = {
						type = "toggle",
						name = "自动使用突袭",
						desc = "潜行状态下是否自动使用突袭",
						order = 6,
						get = function() return self.db.profile.combat.auto_pounce end,
						set = function(value) 
							self.db.profile.combat.auto_pounce = value
							self:ApplyConfig()
						end
					},
					idol_dance = {
						type = "toggle",
						name = "自动装备撕裂神像",
						desc = "是否自动装备撕裂神像",
						order = 7,
						get = function() return self.db.profile.combat.idol_dance end,
						set = function(value) 
							self.db.profile.combat.idol_dance = value
							self:ApplyConfig()
						end
					},
					auto_loot = {
						type = "toggle",
						name = "自动拾取（自用！别选）",
						desc = "是否启用自动拾取功能",
						order = 8,
						get = function() return self.db.profile.combat.auto_loot end,
						set = function(value) 
							self.db.profile.combat.auto_loot = value
							self:ApplyConfig()
						end
					},
					loot_interval = {
						type = "range",
						name = "拾取间隔",
						desc = "自动拾取间隔时间（秒）",
						order = 9,
						min = 0.1,
						max = 10,
						step = 0.1,
						get = function() return self.db.profile.combat.loot_interval end,
						set = function(value) 
							self.db.profile.combat.loot_interval = value
							self:ApplyConfig()
						end
					},
					rend_threshold = {
						type = "range",
						name = "撕扯使用阈值",
						desc = "撕扯使用阈值（目标血量高于此值时使用）",
						order = 10,
						min = 500,
						max = 3000,
						step = 100,
						get = function() return self.db.profile.combat.rend_threshold end,
						set = function(value) 
							self.db.profile.combat.rend_threshold = value
							self:ApplyConfig()
						end
					},

					avoid_player_target = {
						type = "toggle",
						name = "避免攻击玩家",
						desc = "如果目标是玩家则停止攻击并切换目标",
						order = 11,
						get = function() return self.db.profile.combat.avoid_player_target end,
						set = function(value) 
							self.db.profile.combat.avoid_player_target = value
							self:ApplyConfig()
						end
					},
					ot_bear_form = {
						type = "toggle",
						name = "OT时变熊",
						desc = "当OT时自动变熊形态并使用熊德攻击逻辑（不会嘲讽）",
						order = 12,
						get = function() return self.db.profile.combat.ot_bear_form end,
						set = function(value) 
							self.db.profile.combat.ot_bear_form = value
							self:ApplyConfig()
						end
					},
					cower_enabled = {
						type = "toggle",
						name = "快OT时畏缩",
						desc = "启用后当仇恨百分比达到阈值时自动施放畏缩（需TWT威胁插件）",
						order = 13,
						hidden = function() return type(TWTtargetThreat) ~= "function" end,
						get = function() return self.db.profile.combat.cower_enabled end,
						set = function(value)
							self.db.profile.combat.cower_enabled = value
							self:ApplyConfig()
						end
					},
					cower_threshold = {
						type = "range",
						name = "畏缩仇恨阈值",
						desc = "仇恨百分比达到该值时尝试施放畏缩",
						order = 14,
						min = 50,
						max = 110,
						step = 1,
						hidden = function() return type(TWTtargetThreat) ~= "function" end,
						get = function() return self.db.profile.combat.cower_threshold end,
						set = function(value)
							self.db.profile.combat.cower_threshold = value
							self:ApplyConfig()
						end
					},
					t35_burst = {
						type = "group",
						name = "5T3.5爆发设置",
						desc = "阿莎曼之怒出现时使用爆发技能和物品",
						order = 15,
						args = {
							berserk = {
								type = "text",
								name = "爆发时使用狂暴",
								desc = "阿莎曼之怒出现时狂暴的使用策略",
								order = 1,
								get = function() return self.db.profile.combat.t35_burst.berserk end,
								set = function(value)
									self.db.profile.combat.t35_burst.berserk = value
									self:ApplyConfig()
								end,
								validate = {
									["none"] = "不使用",
									["use"] = "使用",
									["boss"] = "仅boss"
								}
							},
							trinket_upper = {
								type = "text",
								name = "爆发时使用上部饰品",
								desc = "阿莎曼之怒出现时上部饰品的使用策略；无条件使用会跳过饰品可用性扫描",
								order = 2,
								get = function() return self.db.profile.combat.t35_burst.trinket_upper end,
								set = function(value)
									self.db.profile.combat.t35_burst.trinket_upper = value
									self:ApplyConfig()
								end,
								validate = {
									["none"] = "不使用",
									["use"] = "使用",
									["boss"] = "仅boss",
									["force"] = "无条件使用"
								}
							},
							trinket_below = {
								type = "text",
								name = "爆发时使用下部饰品",
								desc = "阿莎曼之怒出现时下部饰品的使用策略；无条件使用会跳过饰品可用性扫描",
								order = 3,
								get = function() return self.db.profile.combat.t35_burst.trinket_below end,
								set = function(value)
									self.db.profile.combat.t35_burst.trinket_below = value
									self:ApplyConfig()
								end,
								validate = {
									["none"] = "不使用",
									["use"] = "使用",
									["boss"] = "仅boss",
									["force"] = "无条件使用"
								}
							},
							mighty_rage_potion = {
								type = "text",
								name = "爆发时使用强效怒气药水",
								desc = "阿莎曼之怒出现时强效怒气药水的使用策略",
								order = 4,
								get = function() return self.db.profile.combat.t35_burst.mighty_rage_potion end,
								set = function(value)
									self.db.profile.combat.t35_burst.mighty_rage_potion = value
									self:ApplyConfig()
								end,
								validate = {
									["none"] = "不使用",
									["use"] = "使用",
									["boss"] = "仅boss"
								}
							},
							haste_potion = {
								type = "text",
								name = "爆发时使用加速药水",
								desc = "阿莎曼之怒出现时加速药水的使用策略",
								order = 5,
								get = function() return self.db.profile.combat.t35_burst.haste_potion end,
								set = function(value)
									self.db.profile.combat.t35_burst.haste_potion = value
									self:ApplyConfig()
								end,
								validate = {
									["none"] = "不使用",
									["use"] = "使用",
									["boss"] = "仅boss"
								}
							},
							rake = {
								type = "toggle",
								name = "爆发时补扫击",
								desc = "阿莎曼之怒出现且扫击爆发标记未完成时补扫击",
								order = 6,
								get = function() return self.db.profile.combat.t35_burst.rake end,
								set = function(value)
									self.db.profile.combat.t35_burst.rake = value
									self:ApplyConfig()
								end
							},
							rip = {
								type = "toggle",
								name = "爆发时补撕扯",
								desc = "阿莎曼之怒出现且撕扯爆发标记未完成时补5星撕扯",
								order = 7,
								get = function() return self.db.profile.combat.t35_burst.rip end,
								set = function(value)
									self.db.profile.combat.t35_burst.rip = value
									self:ApplyConfig()
								end
							}
						}
					}
				}
			},
			bird = {
				type = "group",
				name = "鸟德",
				desc = "设置鸟德战斗相关选项",
				order = 2,
				args = {
					ot_invulnerability = {
						type = "toggle",
						name = "OT吃有限无敌",
						desc = "当成为Boss攻击目标时自动使用有限无敌药水",
						order = 2,
						get = function() return self.db.profile.bird.combat.otInvulnerability end,
						set = function(value) 
							self.db.profile.bird.combat.otInvulnerability = value
							self:ApplyConfig()
						end
					},
					trash_only_moonfire_wrath = {
						type = "toggle",
						name = "小怪不打虫群",
						desc = "当目标为小怪时启用小怪模式（不补虫群）",
						order = 3,
						get = function() return self.db.profile.bird.combat.trashOnlyMoonfireWrath end,
						set = function(value) 
							self.db.profile.bird.combat.trashOnlyMoonfireWrath = value
							self:ApplyConfig()
						end
					},
					idol_dance = {
						type = "toggle",
						name = "自动切换神像",
						desc = "月火切月光，星火切潮汐，传播卡cd所以不切",
						order = 4,
						get = function() return self.db.profile.bird.combat.idol_dance end,
						set = function(value) 
							self.db.profile.bird.combat.idol_dance = value
							self:ApplyConfig()
						end
					},
					aoe_header = {
						type = "header",
						name = "AOE设置（指向鼠标施放飓风）",
						order = 5,
					},
					aoe_use_potion = {
						type = "toggle",
						name = "AOE尝试吃药",
						desc = "执行 /autobirdhurricane 或 /abhe 时尝试使用有限无敌药水",
						order = 6,
						get = function() return self.db.profile.bird.aoe.usePotion end,
						set = function(value)
							self.db.profile.bird.aoe.usePotion = value
							self:ApplyConfig()
						end
					},
					aoe_trinket_upper = {
						type = "toggle",
						name = "AOE使用上饰品",
						desc = "执行 /autobirdhurricane 或 /abhe 时尝试使用上部饰品",
						order = 7,
						get = function() return self.db.profile.bird.aoe.trinketUpper end,
						set = function(value)
							self.db.profile.bird.aoe.trinketUpper = value
							self:ApplyConfig()
						end
					},
					aoe_trinket_below = {
						type = "toggle",
						name = "AOE使用下饰品",
						desc = "执行 /autobirdhurricane 或 /abhe 时尝试使用下部饰品",
						order = 8,
						get = function() return self.db.profile.bird.aoe.trinketBelow end,
						set = function(value)
							self.db.profile.bird.aoe.trinketBelow = value
							self:ApplyConfig()
						end
					},
					mana_header = {
						type = "header",
						name = "法力管理",
						order = 9,
					},
					auto_activate = {
						type = "toggle",
						name = "自动使用激活",
						desc = "法力不足时自动使用激活技能",
						order = 10,
						get = function() return self.db.profile.bird.mana.autoActivate end,
						set = function(value) 
							self.db.profile.bird.mana.autoActivate = value
							self:ApplyConfig()
						end
					},
					activate_value = {
						type = "range",
						name = "激活触发法力",
						desc = "当法力低于此值时使用激活",
						order = 11,
						min = 300,
						max = 7000,
						step = 100,
						get = function() return self.db.profile.bird.mana.activateValue end,
						set = function(value) 
							self.db.profile.bird.mana.activateValue = value
							self:ApplyConfig()
						end
					},
					consumable = {
						type = "toggle",
						name = "自动使用消耗品",
						desc = "法力不足时自动使用草药茶或符文（根据血量选择）",
						order = 12,
						get = function() return self.db.profile.bird.mana.consumable end,
						set = function(value) 
							self.db.profile.bird.mana.consumable = value
							self:ApplyConfig()
						end
					},
					consumable_value = {
						type = "range",
						name = "消耗品触发法力",
						desc = "当法力低于此值时使用草药茶/符文（血量<50%用草药茶，>=50%用符文）",
						order = 13,
						min = 300,
						max = 7000,
						step = 100,
						get = function() return self.db.profile.bird.mana.consumableValue end,
						set = function(value) 
							self.db.profile.bird.mana.consumableValue = value
							self:ApplyConfig()
						end
					}
				}
			},
			bear = {
				type = "group",
				name = "熊德",
				desc = "设置熊德战斗相关选项",
				order = 3,
				args = {
					-- 槌击设置
					maul_header = {
						type = "header",
						name = "槌击设置",
						order = 1,
					},
					maul_start = {
						type = "range",
						name = "槌击起始怒气",
						desc = "当怒气达到该值时开始使用槌击",
						order = 2,
						min = 0,
						max = 100,
						step = 1,
						get = function() return self.db.profile.bear.timing.maul.start end,
						set = function(value) 
							self.db.profile.bear.timing.maul.start = value
							self:ApplyConfig()
						end
					},
					
					-- 野蛮撕咬设置
					savage_header = {
						type = "header",
						name = "野蛮撕咬设置",
						order = 3,
					},
					savage_start = {
						type = "range",
						name = "野蛮撕咬起始怒气",
						desc = "当怒气大于该值且无狂暴回复效果时施放野蛮撕咬",
						order = 4,
						min = 30,
						max = 100,
						step = 1,
						get = function() return self.db.profile.bear.timing.savageBite.start end,
						set = function(value) 
							self.db.profile.bear.timing.savageBite.start = value
							self:ApplyConfig()
						end
					},
					
					-- 挥击设置
					swipe_header = {
						type = "header",
						name = "挥击设置",
						order = 5,
					},
					swipe_use = {
						type = "toggle",
						name = "使用挥击",
						desc = "是否使用挥击技能",
						order = 6,
						get = function() return self.db.profile.bear.timing.swipe.use end,
						set = function(value) 
							self.db.profile.bear.timing.swipe.use = value
							self:ApplyConfig()
						end
					},
					swipe_start = {
						type = "range",
						name = "挥击起始怒气",
						desc = "当怒气低于该值时使用挥击",
						order = 7,
						min = 0,
						max = 100,
						step = 1,
						get = function() return self.db.profile.bear.timing.swipe.start end,
						set = function(value) 
							self.db.profile.bear.timing.swipe.start = value
							self:ApplyConfig()
						end
					},
					
					-- 狂暴回复设置
					frenzied_regen_header = {
						type = "header",
						name = "狂暴回复设置",
						order = 8,
					},
					frenzied_regen_start = {
						type = "range",
						name = "狂暴回复起始损失",
						desc = "当生命小于或等于该百分比时触发狂暴回复",
						order = 9,
						min = 0,
						max = 100,
						step = 1,
						get = function() return self.db.profile.bear.timing.frenziedRegeneration.start end,
						set = function(value) 
							self.db.profile.bear.timing.frenziedRegeneration.start = value
							self:ApplyConfig()
						end
					},
					frenzied_regen_swipe = {
						type = "toggle",
						name = "狂暴回复时挥击",
						desc = "狂暴回复时是否施放挥击",
						order = 10,
						get = function() return self.db.profile.bear.timing.frenziedRegeneration.swipe end,
						set = function(value) 
							self.db.profile.bear.timing.frenziedRegeneration.swipe = value
							self:ApplyConfig()
						end
					},
					frenzied_regen_savage = {
						type = "toggle",
						name = "狂暴回复时野蛮撕咬",
						desc = "狂暴回复时是否施放野蛮撕咬",
						order = 11,
						get = function() return self.db.profile.bear.timing.frenziedRegeneration.savageBite end,
						set = function(value) 
							self.db.profile.bear.timing.frenziedRegeneration.savageBite = value
							self:ApplyConfig()
						end
					},
					frenzied_regen_maul = {
						type = "toggle",
						name = "狂暴回复时槌击",
						desc = "狂暴回复时是否施放槌击",
						order = 12,
						get = function() return self.db.profile.bear.timing.frenziedRegeneration.maul end,
						set = function(value) 
							self.db.profile.bear.timing.frenziedRegeneration.maul = value
							self:ApplyConfig()
						end
					},
					
					-- 狂怒设置
					enrage_header = {
						type = "header",
						name = "狂怒设置",
						order = 13,
					},
					enrage_start = {
						type = "range",
						name = "狂怒起手怒气",
						desc = "当怒气低于该值时施放狂怒",
						order = 14,
						min = 0,
						max = 100,
						step = 1,
						get = function() return self.db.profile.bear.timing.enrage.start end,
						set = function(value) 
							self.db.profile.bear.timing.enrage.start = value
							self:ApplyConfig()
						end
					},
					enrage_frenzied = {
						type = "toggle",
						name = "狂暴回复时狂怒",
						desc = "当有狂暴回复效果时施放狂怒",
						order = 15,
						get = function() return self.db.profile.bear.timing.enrage.frenziedRegeneration end,
						set = function(value) 
							self.db.profile.bear.timing.enrage.frenziedRegeneration = value
							self:ApplyConfig()
						end
					},
					
					-- 狂暴设置
					frenzied_header = {
						type = "header",
						name = "狂暴设置",
						order = 16,
					},
					frenzied_start = {
						type = "range",
						name = "狂暴起手损失",
						desc = "当生命损失达到该百分比且未处于战斗中时施放狂暴",
						order = 17,
						min = 0,
						max = 100,
						step = 1,
						get = function() return self.db.profile.bear.timing.frenzied.start end,
						set = function(value) 
							self.db.profile.bear.timing.frenzied.start = value
							self:ApplyConfig()
						end
					},
					frenzied_frenzied_regen = {
						type = "toggle",
						name = "狂暴回复时狂暴",
						desc = "当有狂暴回复效果时施放狂暴",
						order = 18,
						get = function() return self.db.profile.bear.timing.frenzied.frenziedRegeneration end,
						set = function(value) 
							self.db.profile.bear.timing.frenzied.frenziedRegeneration = value
							self:ApplyConfig()
						end
					},
					
					-- 其他技能设置
					other_header = {
						type = "header",
						name = "其他技能设置",
						order = 19,
					},
					demoralizing_roar = {
						type = "toggle",
						name = "挫志咆哮",
						desc = "是否施放挫志咆哮以降低目标攻击强度",
						order = 20,
						get = function() return self.db.profile.bear.timing.demoralizingRoar end,
						set = function(value) 
							self.db.profile.bear.timing.demoralizingRoar = value
							self:ApplyConfig()
						end
					},
					faerie_fire_wild = {
						type = "text",
						name = "精灵之火（野性）",
						desc = "选择使用精灵之火（野性）的时机",
						order = 21,
						get = function() return self.db.profile.bear.timing.faerieFireWild end,
						set = function(value) 
							self.db.profile.bear.timing.faerieFireWild = value
							self:ApplyConfig()
						end,
						validate = {"ready", "none", "disable"}
					},
					growl = {
						type = "toggle",
						name = "嘲讽",
						desc = "当目标的目标不是你时是否施放嘲讽",
						order = 22,
						get = function() return self.db.profile.bear.timing.growl end,
						set = function(value) 
							self.db.profile.bear.timing.growl = value
							self:ApplyConfig()
						end
					},
					
					-- 通报设置
					report_header = {
						type = "header",
						name = "通报设置",
						order = 23,
					},
					report_low_roar = {
						type = "toggle",
						name = "通报低吼",
						desc = "施放低吼后是否喊话通报",
						order = 24,
						get = function() return self.db.profile.bear.report["低吼"] end,
						set = function(value)
							self.db.profile.bear.report["低吼"] = value
							self:ApplyConfig()
						end
					},
					report_challenge_roar = {
						type = "toggle",
						name = "通报挑战咆哮",
						desc = "施放挑战咆哮后是否通报",
						order = 25,
						get = function() return self.db.profile.bear.report["挑战咆哮"] end,
						set = function(value) 
							self.db.profile.bear.report["挑战咆哮"] = value
							self:ApplyConfig()
						end
					},
					report_frenzied_regen = {
						type = "toggle",
						name = "通报狂暴回复",
						desc = "施放狂暴回复后是否通报",
						order = 26,
						get = function() return self.db.profile.bear.report["狂暴回复"] end,
						set = function(value) 
							self.db.profile.bear.report["狂暴回复"] = value
							self:ApplyConfig()
						end
					},
					report_frenzied = {
						type = "toggle",
						name = "通报狂暴",
						desc = "施放狂暴后是否通报",
						order = 27,
						get = function() return self.db.profile.bear.report["狂暴"] end,
						set = function(value) 
							self.db.profile.bear.report["狂暴"] = value
							self:ApplyConfig()
						end
					},
					report_barkskin = {
						type = "toggle",
						name = "通报树皮术（野性）",
						desc = "施放树皮术（野性）后是否通报",
						order = 28,
						get = function() return self.db.profile.bear.report["树皮术（野性）"] end,
						set = function(value) 
							self.db.profile.bear.report["树皮术（野性）"] = value
							self:ApplyConfig()
						end
					}
				}
			},
			healing = {
				type = "group",
				name = "治疗",
				desc = "设置治疗相关选项",
				order = 4,
				args = {
					rejuv_rank = {
						type = "range",
						name = "愈合等级",
						desc = "设置愈合法术的等级（1-9级）",
						order = 1,
						min = 1,
						max = 9,
						step = 1,
						get = function() return self.db.profile.healing.rejuv_rank end,
						set = function(value) 
							self.db.profile.healing.rejuv_rank = value
							self:ApplyConfig()
						end
					}
				}
			},
			common = {
				type = "group",
				name = "共通",
				desc = "设置饰品、消耗品、调试等共通选项",
				order = 5,
				args = {
					trinket_header = {
						type = "header",
						name = "饰品设置",
						order = 1,
					},
					upper = {
						type = "toggle",
						name = "使用上部饰品",
						desc = "是否自动使用上部饰品",
						order = 2,
						get = function() return self.db.profile.trinket.upper end,
						set = function(value) 
							self.db.profile.trinket.upper = value
							self:ApplyConfig()
						end
					},
					below = {
						type = "toggle",
						name = "使用下部饰品",
						desc = "是否自动使用下部饰品",
						order = 3,
						get = function() return self.db.profile.trinket.below end,
						set = function(value) 
							self.db.profile.trinket.below = value
							self:ApplyConfig()
						end
					},
					consumable_header = {
						type = "header",
						name = "消耗品设置",
						order = 4,
					},
					health_stone = {
						type = "toggle",
						name = "使用治疗石",
						desc = "是否自动使用治疗石",
						order = 5,
						get = function() return self.db.profile.consumable.health_stone end,
						set = function(value)
							self.db.profile.consumable.health_stone = value
							self:ApplyConfig()
						end
					},
					health_stone_value = {
						type = "range",
						name = "治疗石使用血线",
						desc = "当生命值低于该值时使用治疗石",
						order = 6,
						min = 500,
						max = 10000,
						step = 100,
						get = function() return self.db.profile.consumable.health_stone_value end,
						set = function(value) 
							self.db.profile.consumable.health_stone_value = value
							self:ApplyConfig()
						end
					},
					herbal_tea = {
						type = "toggle",
						name = "使用草药茶",
						desc = "是否自动使用草药茶",
						order = 7,
						get = function() return self.db.profile.consumable.herbal_tea end,
						set = function(value)
							self.db.profile.consumable.herbal_tea = value
							self:ApplyConfig()
						end
					},
					herbal_tea_value = {
						type = "range",
						name = "草药茶使用血线",
						desc = "当生命值低于该值时使用草药茶",
						order = 8,
						min = 500,
						max = 10000,
						step = 100,
						get = function() return self.db.profile.consumable.herbal_tea_value end,
						set = function(value) 
							self.db.profile.consumable.herbal_tea_value = value
							self:ApplyConfig()
						end
					},
					sacrifice_oil = {
						type = "toggle",
						name = "使用献祭之油",
						desc = "是否自动使用献祭之油",
						order = 9,
						get = function() return self.db.profile.consumable.sacrifice_oil end,
						set = function(value)
							self.db.profile.consumable.sacrifice_oil = value
							self:ApplyConfig()
						end
					},
					ot_limited_invulnerability = {
						type = "toggle",
						name = "OT吃有限无敌",
						desc = "当成为怪物攻击目标（OT）时自动使用有限无敌药水",
						order = 10,
						get = function() return self.db.profile.consumable.ot_limited_invulnerability end,
						set = function(value)
							self.db.profile.consumable.ot_limited_invulnerability = value
							self:ApplyConfig()
						end
					},
					soul_speed_boss = {
						type = "toggle",
						name = "Boss战使用魂能之速",
						desc = "在Boss战中自动使用魂能之速",
						order = 11,
						get = function() return self.db.profile.consumable.soul_speed_boss end,
						set = function(value)
							self.db.profile.consumable.soul_speed_boss = value
							self:ApplyConfig()
						end
					},
					debug_header = {
						type = "header",
						name = "调试设置",
						order = 12,
					},
					nampower_status = {
						type = "text",
						name = "Nampower模组状态",
						desc = "显示Nampower模组是否成功导入",
						order = 13,
						get = function() 
							if AutoCat.Event and AutoCat.Event.nampowerEnabled then
								return "已导入 (" ..
									AutoCat.Event.nampowerMajor .. "." ..
									AutoCat.Event.nampowerMinor .. "." ..
									AutoCat.Event.nampowerPatch .. ")"
							else
								return "未导入"
							end
						end,
						set = function() end
					},
					unitxp_status = {
						type = "text",
						name = "UnitXP模组状态",
						desc = "显示UnitXP_SP3模组是否成功导入",
						order = 14,
						get = function()
					local UnitXP_SP3 = pcall(UnitXP, "nop", "nop")
					if UnitXP_SP3 then
						local compileTime = UnitXP("version", "coffTimeDateStamp")
						if compileTime then
							return "已导入 (" .. date("%Y-%m-%d", compileTime) .. ")"
						else
							return "已导入"
						end
					else
						return "未导入"
					end
				end,
						set = function() end
					}
				}
			}
		}
	}
	
	-- 初始化熊德模块（如果存在）
	if AutoCat.Bear then
		AutoCat.Bear:Initialize()
	end
	
	-- 初始化鸟德模块（如果存在）
	if AutoCat.Bird then
		AutoCat.Bird:Initialize()
	end
end

-- 应用配置仅到AutoCat.Options（保持原版结构）
function Cat:ApplyConfig()
    -- 更新AutoCat.Options对象
    -- 战斗设置
    AutoCat.Options["type"] = self.db.profile.combat["type"]
    AutoCat.Options.lowHealthBackstab = self.db.profile.combat.low_health_backstab and 1 or 0
    AutoCat.Options.lowHealthBackstabThreshold = self.db.profile.combat.low_health_backstab_threshold or 100000
    AutoCat.Options.useUnitXP = self.db.profile.combat.use_unitxp and 1 or 0
    AutoCat.Options.tigerFury = self.db.profile.combat.tiger_fury and 1 or 0
    AutoCat.Options.faerieFire = self.db.profile.combat.faerie_fire and 1 or 0
    AutoCat.Options.faerieFirePull = self.db.profile.combat.faerie_fire_pull and 1 or 0
    AutoCat.Options.pounce = self.db.profile.combat.auto_pounce and 1 or 0
    AutoCat.Options.idolDance = self.db.profile.combat.idol_dance and 1 or 0
    AutoCat.Options.loot = self.db.profile.combat.auto_loot and 1 or 0
    AutoCat.Options.lootInterval = self.db.profile.combat.loot_interval
    AutoCat.Options.rendValue = self.db.profile.combat.rend_threshold

    AutoCat.Options.avoidPlayerTarget = self.db.profile.combat.avoid_player_target and 1 or 0
    AutoCat.Options.otBearForm = self.db.profile.combat.ot_bear_form and 1 or 0
    AutoCat.Options.cowerEnabled = self.db.profile.combat.cower_enabled and 1 or 0
    AutoCat.Options.cowerThreshold = self.db.profile.combat.cower_threshold or 80
    local t35Burst = self.db.profile.combat.t35_burst or {}
    AutoCat.Options.t35BurstBerserk = t35Burst.berserk or "none"
    AutoCat.Options.t35BurstTrinketUpper = t35Burst.trinket_upper or "none"
    AutoCat.Options.t35BurstTrinketBelow = t35Burst.trinket_below or "none"
    AutoCat.Options.t35BurstMightyRagePotion = t35Burst.mighty_rage_potion or "none"
    AutoCat.Options.t35BurstHastePotion = t35Burst.haste_potion or "none"
    AutoCat.Options.t35BurstRake = t35Burst.rake and 1 or 0
    AutoCat.Options.t35BurstRip = t35Burst.rip and 1 or 0
    
    -- 饰品设置
    AutoCat.Options.trinketUpper = self.db.profile.trinket.upper and 1 or 0
    AutoCat.Options.trinketBelow = self.db.profile.trinket.below and 1 or 0
    
    -- 消耗品设置
    AutoCat.Options.healthStone = self.db.profile.consumable.health_stone and 1 or 0
    AutoCat.Options.healthStoneValue = self.db.profile.consumable.health_stone_value
    AutoCat.Options.herbalTea = self.db.profile.consumable.herbal_tea and 1 or 0
    AutoCat.Options.herbalTeaValue = self.db.profile.consumable.herbal_tea_value
    AutoCat.Options.sacrificeOil = self.db.profile.consumable.sacrifice_oil and 1 or 0
    AutoCat.Options.otLimitedInvulnerability = self.db.profile.consumable.ot_limited_invulnerability and 1 or 0
    AutoCat.Options.soulSpeedBoss = self.db.profile.consumable.soul_speed_boss and 1 or 0
    
    -- 治疗设置
    AutoCat.Options.rejuvRank = self.db.profile.healing.rejuv_rank
    
    -- 熊德设置 - 融合到AutoCat.Options
    AutoCat.Options.bear = {
        timing = {
            maul = self.db.profile.bear.timing.maul.start,
            savageBite = self.db.profile.bear.timing.savageBite.start,
            swipe = {
                use = self.db.profile.bear.timing.swipe.use,
                start = self.db.profile.bear.timing.swipe.start
            },
            frenziedRegeneration = {
                start = self.db.profile.bear.timing.frenziedRegeneration.start,
                swipe = self.db.profile.bear.timing.frenziedRegeneration.swipe,
                savageBite = self.db.profile.bear.timing.frenziedRegeneration.savageBite,
                maul = self.db.profile.bear.timing.frenziedRegeneration.maul
            },
            enrage = {
                start = self.db.profile.bear.timing.enrage.start,
                frenziedRegeneration = self.db.profile.bear.timing.enrage.frenziedRegeneration
            },
            frenzied = {
                start = self.db.profile.bear.timing.frenzied.start,
                frenziedRegeneration = self.db.profile.bear.timing.frenzied.frenziedRegeneration
            },
            demoralizingRoar = self.db.profile.bear.timing.demoralizingRoar,
            faerieFireWild = self.db.profile.bear.timing.faerieFireWild,
            growl = self.db.profile.bear.timing.growl
        },
        report = self.db.profile.bear.report
    }
    
    -- 鸟德设置 - 融合到AutoCat.Options
    AutoCat.Options.bird = {
        combat = {
            otInvulnerability = self.db.profile.bird.combat.otInvulnerability,
            trashOnlyMoonfireWrath = self.db.profile.bird.combat.trashOnlyMoonfireWrath,
            idolDance = self.db.profile.bird.combat.idol_dance and 1 or 0
        },
        aoe = {
            usePotion = self.db.profile.bird.aoe.usePotion,
            trinketUpper = self.db.profile.bird.aoe.trinketUpper,
            trinketBelow = self.db.profile.bird.aoe.trinketBelow
        },
        mana = {
            autoActivate = self.db.profile.bird.mana.autoActivate,
            activateValue = self.db.profile.bird.mana.activateValue,
            consumable = self.db.profile.bird.mana.consumable,
            consumableValue = self.db.profile.bird.mana.consumableValue
        }
    }
end

function Cat:OnEnable()
end

function Cat:OnDisable()
end
