local net = require('coro-http-luv.coro-net')
local rcon = require('rcon')

local function connect(ip, password)
  local host, port = ip:match("([^:]+):?(%d*)")
  port = port and tonumber(port) or 27015

  local read, write_or_err, socket, _, _, close = net.connect({
    host=host, port=port, isTcp=true, decode=rcon.decoder
  })
  if not read then
    return nil, write_or_err
  end
  local write = write_or_err

  local auth_packet, auth_id = rcon.pack_auth(password)
  assert(write(auth_packet))

  -- generic response
  local msg = read()
  if not msg then
    return nil, "failed to authenticate with rcon (no response)"
  end
  assert(msg.id == auth_id, "unexpected auth message id in first packet: "..msg.id.." (expected "..auth_id..")")

  -- auth repsonse
  msg = assert(read())
  if not rcon.check_auth(msg) then
    return nil, "failed to authenticate with rcon (bad password)"
  end
  assert(msg.id == auth_id, "unexpected auth message id in second packet: "..msg.id.." (expected "..auth_id..")")

  local function exec(cmd)
    local cmd_packet, cmd_id = rcon.pack_cmd(cmd)
    assert(write(cmd_packet))
    local ack_packet, ack_id = rcon.pack(rcon.PACKET_TYPES.RESPONSE_VALUE)
    assert(write(ack_packet))

    local chunks = {}
    while true do
      msg = assert(read())
      if msg.id == ack_id then
        -- ack packet has a secondary packet with #body of 4
        msg = assert(read())
        assert(msg.id == ack_id)
        assert(#msg.body == 4)
        break
      end
      assert(msg.id == cmd_id)
      table.insert(chunks, msg.body)
    end
    return table.concat(chunks)
  end

  return {
    exec = exec,
    close = close,
    socket = socket,
  }
end

return {
  connect = connect,
}
