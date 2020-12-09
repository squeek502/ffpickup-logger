local utils = {}

function utils.stringStartsWith(str, startsWith)
  return str and startsWith and str:sub(1, #startsWith) == startsWith
end

return utils
