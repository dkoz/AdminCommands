local Json = require("libs/Json")
local bans = {}

local ModDirectory = debug.getinfo(1, "S").source:match([[^@?(.*[\/])[^\/]-$]]):match("^(.+[/\\])[^/\\]+[/\\]$")
local BansFile = ModDirectory .. "config/bans.json"
local BANS = {}

local function loadBans()
	local f = io.open(BansFile, "r")
	if f then
		local s = f:read("*a") or ""
		f:close()
		local ok, data = pcall(Json.decode, s)
		if ok and type(data) == "table" then
			BANS = data
		end
	end
end

local function saveBans()
	local f = io.open(BansFile, "w")
	if f then
		f:write(Json.encode(BANS))
		f:close()
	end
end

loadBans()

function bans.isUidBanned(uid)
	return uid and BANS[uid] ~= nil
end

function bans.banUid(uid, name, reason)
	if not uid or uid == "" then return false end
	BANS[uid] = { name = name or uid, uid = uid, reason = reason or "" }
	saveBans()
	return true
end

function bans.unbanUid(uid)
	if not uid or uid == "" then return false end
	if not BANS[uid] then return false end
	BANS[uid] = nil
	saveBans()
	return true
end

function bans.getBans()
	return BANS
end

return bans
