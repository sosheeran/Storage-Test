-- firewall/lib/services.lua
-- Maps service names to computer IDs
-- Reads from /fw/data/services.cfg

local M = {}
local CFG = "/fw/data/services.cfg"

function M.load()
  local s = {}
  local f = fs.open(CFG, "r")
  if not f then return s end
  local line = f.readLine()
  while line do
    if not line:match("^#") and line:match("|") then
      local id, name, desc, trusted = line:match(
        "^%s*(%d+)%s*|%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*$"
      )
      if id and name and name ~= "" then
        s[name] = {
          id      = tonumber(id),
          desc    = desc    or "",
          trusted = (trusted == "true"),
        }
      end
    end
    line = f.readLine()
  end
  f.close()
  return s
end

function M.getID(name)
  local s = M.load()
  return s[name] and s[name].id or nil
end

function M.isTrusted(computer_id)
  local s = M.load()
  for _, data in pairs(s) do
    if data.id == computer_id and data.trusted then
      return true
    end
  end
  return false
end

return M
