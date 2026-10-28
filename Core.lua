-- AutoCat 内部核心
-- 提供配置、调试与生命周期所需的最小实现，替代 AceAddon/AceDB/AceDebug。

AutoCat = AutoCat or {}
Cat = Cat or {}

local function CopyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			CopyDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

local function GetLegacyProfile(database)
	if type(database) ~= "table" or type(database.profiles) ~= "table" then
		return nil
	end

	local characterName = UnitName("player")
	local realmName = GetRealmName()
	local profileKey
	if characterName and realmName then
		local characterId
		if type(PLAYER_OF_REALM) == "string" then
			characterId = string.format(PLAYER_OF_REALM, characterName, realmName)
		end
		if type(database.currentProfile) == "table" then
			if characterId then
				profileKey = database.currentProfile[characterId]
			end
			if not profileKey then
				profileKey = database.currentProfile[characterName .. " - " .. realmName]
			end
		end
		if not profileKey and type(database.profileKeys) == "table" then
			if characterId then
				profileKey = database.profileKeys[characterId]
			end
			if not profileKey then
				profileKey = database.profileKeys[characterName .. " - " .. realmName]
			end
		end
	end
	if profileKey and type(database.profiles[profileKey]) == "table" then
		return database.profiles[profileKey]
	end

	for _, profile in pairs(database.profiles) do
		if type(profile) == "table" then
			return profile
		end
	end
	return nil
end

function Cat:RegisterDB()
	AutoCatDB = AutoCatDB or {}
	local profile = AutoCatDB.settings
	if type(profile) ~= "table" then
		profile = GetLegacyProfile(AutoCatDB)
	end
	if type(profile) ~= "table" and type(AutoCatDB.profile) == "table" then
		profile = AutoCatDB.profile
	end
	if type(profile) ~= "table" then
		profile = {}
	end
	AutoCatDB.settings = profile
	self.db = { profile = profile }
end

function Cat:RegisterDefaults(kind, defaults)
	if kind ~= "profile" or type(defaults) ~= "table" then
		return
	end
	if not self.db then
		self:RegisterDB()
	end
	CopyDefaults(self.db.profile, defaults)
end

function Cat:IsDebugging()
	return self.debugging and true or false
end

function Cat:SetDebugging(enabled)
	self.debugging = enabled and true or false
end

function Cat:GetDebugLevel()
	return tonumber(self.debugLevel) or 2
end

function Cat:SetDebugLevel(level)
	level = tonumber(level)
	if level and level >= 1 and level <= 3 then
		self.debugLevel = level
	end
end

function Cat:Show()
	if AutoCatSettingsUI then
		AutoCatSettingsUI:Show()
	end
end

function Cat:Hide()
	if AutoCatSettingsUI then
		AutoCatSettingsUI:Hide()
	end
end
