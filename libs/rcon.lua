local rcon = {
  id = 0,
  PACKET_TYPES = {
    AUTH = 3,
    AUTH_RESPONSE = 2,
    EXECCOMMAND = 2,
    RESPONSE_VALUE = 0,
  },
  PACKET_FULL_SIZE_INCREMENT = 4, -- size width (i32) is not included in 'size' part of packets
  PACKET_MIN_BYTES_AFTER_SIZE = 10, -- i32, i32, \0, \0
  ID_MAX = math.pow(2, 31) - 1,
}
rcon.PACKET_MIN_SIZE = rcon.PACKET_MIN_BYTES_AFTER_SIZE + rcon.PACKET_FULL_SIZE_INCREMENT

-- packer and unpacker adapted from https://github.com/iryont/lua-struct

local packer = {
  i32 = function(stream, val)
    local bytes = {}
    for _ = 1, 4 do
      table.insert(bytes, string.char(val % (2 ^ 8)))
      val = math.floor(val / (2 ^ 8))
    end
    table.insert(stream, table.concat(bytes))
  end,
  str = function(stream, val)
    table.insert(stream, val)
    table.insert(stream, string.char(0))
  end,
  chain = function(fns, ...)
    local stream = {}
    local vals = {...}
    for i, fn in ipairs(fns) do
      fn(stream, vals[i])
    end
    return table.concat(stream)
  end,
}
packer.rcon = function(...)
  return packer.chain({packer.i32, packer.i32, packer.i32, packer.str, packer.str}, ...)
end

local unpacker = {
  i32 = function(stream, i)
    if i == nil then i = 1 end
    local width = 4

    local val = 0
    for j = 1, width do
      local byte = string.byte(stream:sub(i, i))
      val = val + byte * (2 ^ ((j - 1) * 8))
      i = i + 1
    end

    -- signedness
    if val >= 2 ^ (width * 8 - 1) then
      val = val - 2 ^ (width * 8)
    end

    return math.floor(val), i
  end,
  str = function(stream, i)
    if i == nil then i = 1 end
    local bytes = {}

    for j = i, stream:len() do
      if stream:sub(j, j) == string.char(0) then
        break
      end
      table.insert(bytes, stream:sub(j, j))
    end

    return table.concat(bytes), i + #bytes + 1
  end,
  strlen = function(stream, i, len)
    if len == 0 then return "", i end
    return stream:sub(i, i+(len-1)), i+len
  end,
  chain = function(fns, stream)
    local vals = {}
    local i, val
    for _, fn in ipairs(fns) do
      val, i = fn(stream, i)
      table.insert(vals, val)
    end
    return unpack(vals)
  end,
}
unpacker.rcon = function(stream)
  local size, id, packetType, body, empty, i
  size, i = unpacker.i32(stream)
  id, i = unpacker.i32(stream, i)
  packetType, i = unpacker.i32(stream, i)
  local expectedBodySize = size - rcon.PACKET_MIN_BYTES_AFTER_SIZE
  body, i = unpacker.strlen(stream, i, expectedBodySize)
  empty = unpacker.str(stream, i)
  return size, id, packetType, body, empty
end

function rcon.pack(packetType, body)
  body = body or ""
  local size = #body + rcon.PACKET_MIN_BYTES_AFTER_SIZE
  local id = rcon.id
  local packed = packer.rcon(size, id, packetType, body, "")
  rcon.id = (rcon.id + 1) % (rcon.ID_MAX + 1)
  return packed, id
end

function rcon.pack_cmd(cmd)
  return rcon.pack(rcon.PACKET_TYPES.EXECCOMMAND, cmd)
end

function rcon.pack_auth(password)
  return rcon.pack(rcon.PACKET_TYPES.AUTH, password)
end

function rcon.unpack(packet)
  local size, id, packetType, body, empty = unpacker.rcon(packet)
  local expectedBodySize = size - rcon.PACKET_MIN_BYTES_AFTER_SIZE
  if #body ~= expectedBodySize then return nil, "expected body of size "..expectedBodySize..", got "..#body end
  if empty ~= "" then return nil, "expected empty string after body, got '"..tostring(empty).."'" end
  return {
    id = id,
    type = packetType,
    body = body,
    size = size + rcon.PACKET_FULL_SIZE_INCREMENT,
  }
end

function rcon.check_auth(packet)
  assert(packet.type == rcon.PACKET_TYPES.AUTH_RESPONSE)
  return packet.id ~= -1
end

-- Decoder for use with coro-wrapper.lua
function rcon.decoder(data, index)
  if not data or index > #data then return end
  local packet = rcon.unpack(data:sub(index))
  if packet then
    local nextIndex = nil
    if index+packet.size < #data then
      nextIndex = index+packet.size
    end
    return packet, nextIndex
  end
end

return rcon
