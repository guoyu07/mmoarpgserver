local login = require "loginserverd"
local crypt = require "crypt"
local skynet = require "skynetex"
require "skynet.manager"
local cluster = require "cluster"

local name, host, port, instance = ...

local server = {
	host = host,
	port = port,
	multilogin = false,	-- disallow multilogin
	name = name,
	instance = tonumber(instance) or 8,
}

local server_list = {}
local user_online = {}
local user_login = {}

function server.auth_handler(token)
	-- the token is base64(user)@base64(server):base64(password)
	local user, server, password = token:match("([^@]+)@([^:]+):(.+)")
	user = crypt.base64decode(user)
	server = crypt.base64decode(server)
	password = crypt.base64decode(password)
	assert(password == "password")
	return server, user
end

function server.login_handler(server, uid, secret, addr)
	print(string.format("%s@%s is login, secret is %s", uid, server, crypt.hexencode(secret)))
	local gameserver = assert(server_list[server], "Unknown server")
	-- only one can login, because disallow multilogin
	local last = user_online[uid]
	if last then
		cluster.call(last.address.harborname, last.address.addr, "kick", uid, last.subid)
	end
	if user_online[uid] then
		error(string.format("user %s is already online", uid))
	end

	local subid = tostring(cluster.call(gameserver.harborname, gameserver.addr, "login", uid, secret, addr))
	user_online[uid] = { address = gameserver, subid = subid , server = server}
	return subid
end

local CMD = {}

function CMD.register_gate(server, address, harborname)
	server_list[server] = { addr = address, harborname = harborname }
end

function CMD.logout(uid, subid)
	local u = user_online[uid]
	if u then
		print(string.format("%s@%s is logout", uid, u.server))
		user_online[uid] = nil
	end
end

function server.command_handler(command, source, ...)
	local f = assert(CMD[command])
	return f(source, ...)
end

login(server)
