local parsePattern = '"(.+)<(.+)><(.+)><(.+)>" ([^"]+) "([^"]+)"(.*)$'

local function stringContains(haystack, needle)
  return haystack and haystack:find(needle, 1, true)
end

local function canParse(msg)
  if stringContains(msg, '<') then return true end
  return false
end

local function parse(msg)
  if not canParse(msg) then
    return nil
  end
  local name, id, steamid, team, event, eventmsg = msg:match(parsePattern)
  return {name=name, id=id, steamid=steamid, team=team}, event, eventmsg
end

return {
  canParse = canParse,
  parse = parse
}
