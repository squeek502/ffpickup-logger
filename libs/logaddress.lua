-- packet structure
-- from https://github.com/jackwilsdon/logaddress-protocol/blob/master/protocol.md
-- 0x00 (4 bytes): 0xFFFFFFFF
-- 0x04 (1 byte): 0x52 or 0x53 (has secret)
-- 0x05 (null-terminated string): secret, only if has secret
-- 0x05 or ?: log message, terminated by "\n\0" (0x0a00)

local TYPE_NO_SECRET = 0x52
local TYPE_SECRET = 0x53

local function parse(msg, secret)
  local header = msg:sub(1,4)
  if header ~= string.rep(string.char(0xFF), 4) then
    return nil, "invalid header"
  end

  local stype = msg:byte(5,5)
  local bodyStart = 6
  if stype == TYPE_SECRET then
    if type(secret) ~= "string" or #secret == 0 then
      return nil, "secret required but not given"
    end
    bodyStart = 6+#secret
    local psecret = msg:sub(6, bodyStart-1)
    if psecret ~= secret then
      return nil, "secret does not match"
    end
  elseif stype ~= TYPE_NO_SECRET then
    return nil, string.format("invalid type 0x%x", stype)
  end

  local line = msg:sub(bodyStart):gsub("\n?%z$", "")
  local date, time, message = line:match("L (%d+/%d+/%d+) %- (%d+:%d+:%d+): (.*)")
  if not message then
    message = line
  end

  return {
    line=line,
    date=date,
    time=time,
    message=message
  }
end

return {
  parse = parse,
}
