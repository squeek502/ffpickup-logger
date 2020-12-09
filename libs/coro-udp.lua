local uv = require('luv')

local udp = {}

function udp.new(...)
  return uv.new_udp(...)
end

function udp.bind(socket, ip, port, opt)
  local ok, err = uv.udp_bind(socket, ip, port, opt)
  if not ok then
    return nil, err
  end
  return socket
end

function udp.recv(socket)
  local thread = coroutine.running()
  local ok, err = uv.udp_recv_start(socket, function(err, data, addr, flags)
    if err then
      return assert(coroutine.resume(thread, nil, err))
    end
    return assert(coroutine.resume(thread, data or true, addr, flags))
  end)
  if not ok and err:match("^EALREADY") == nil then
    return nil, err
  end
  return coroutine.yield()
end

function udp.recv_stop(socket)
  uv.udp_recv_stop(socket)
end

return udp
