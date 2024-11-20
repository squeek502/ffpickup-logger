package.path = "./deps/?.lua;./deps/?/init.lua;" .. package.path
package.path = "./libs/?.lua;./libs/?/init.lua;" .. package.path

local uv = require('luv')
local rcon = require('coro-rcon')
local udp = require('coro-udp')
local http = require('coro-http-luv')
local logaddress = require('logaddress')
local logline = require('logline')

-- debug settings
local _VERBOSE = false

local server_ip = arg[2]
local rcon_password = arg[3]
local listen_ip = arg[4] -- if not specified, then public ip from rcon connection is used
if listen_ip == "auto" then listen_ip = nil end
local key = arg[5] or "" -- secret to stop random requests breaking things
local server_name = arg[6] or "unknown"
local script_name = arg[7] or "parse"

local listenhost = "0.0.0.0"
local listenport = arg[1]

local current = {}
local last = {}

local function reportLogEnd(log, map)
  if not log or not map then return end
  coroutine.wrap(function()
    local url = 'http://ffpickup.com/'..script_name..'.php?log='..log..'&map='..map..'&server='..server_name..'&key='..key
    local res, data = http.request('GET', url)
    if not res then
      print(res, data)
    end
    print(data)
  end)()
end

local function tryRconOneShot(cmd)
  local rconConnection, err = rcon.connect(server_ip, rcon_password)
  if not rconConnection then
    return nil, err
  end
  local res = {rconConnection.exec(cmd)}
  rconConnection.close()
  return unpack(res)
end

coroutine.wrap(function()
  local rconConnection = assert(rcon.connect(server_ip, rcon_password))

  -- janky way to get our public IP
  local pong = rconConnection.exec("ping")
  local public_ip = pong:match("rcon from \"([%d.]+):%d+\"")
  print(public_ip)

  if not listen_ip then
    listen_ip = public_ip
  end
  local res = rconConnection.exec("logaddress_add "..listen_ip..":"..listenport)
  print(res)

  local socket = udp.new()
  assert(udp.bind(socket, listenhost, listenport))

  rconConnection.close()

  while true do
    local data, addr_or_err = udp.recv(socket)
    if not data and addr_or_err then
      print("UDP error: ", addr_or_err)
      return
    end
    if data ~= true then
      local parsed = logaddress.parse(data)
      if _VERBOSE then
        print(addr_or_err.ip..": "..parsed.message)
      end

      local msg = parsed.message
      if logline.canParse(msg) then
        local _, event, eventmsg = logline.parse(parsed.message)
        if event == "say" and eventmsg:match("^!ping") then
          coroutine.wrap(function()
            local status = last.map ~= nil and "ok" or "need a map reset!"
            tryRconOneShot("say pong: " .. status)
          end)()
        end
      elseif msg == "Log file closed" then
        print('log file closed', tostring(current.map), tostring(last.map))
        -- logs that have a map are assumed to be 'mapchange' logs
        -- (which just list out the map and some cvar settings), so
        -- logs without a map are the 'real' round logs.
        -- we use the last log's map, though, since the map doesn't
        -- show up anywhere in the 'real' round logs (which is pretty dumb)
        if current.map == nil and last.map ~= nil then
          reportLogEnd(current.log, last.map)
        end
        last.map = current.map
        last.log = current.log
        current = {}
      elseif msg:match("^Log file started") then
        current.log = msg:match('file "logs[\\/]([^"]+)"')
      elseif msg:match("^Loading map") then
        current.map = msg:match('Loading map "([^"]+)"')
      end
    end
  end
end)()

uv.run()
