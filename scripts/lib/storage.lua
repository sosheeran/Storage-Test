-- scripts/lib/storage.lua
local M = {}
local CFG         = "/data/storage.cfg"
local CHEST_SLOTS = 108

function M.makeKey(name, damage)
  damage = damage or 0
  if damage == 0 then return name end
  return name .. ":" .. tostring(damage)
end

function M.load()
  local store = {}
  local f = fs.open(CFG, "r")
  if not f then return store end
  local line = f.readLine()
  while line do
    if not line:match("^#") and line:match("|") then
      local key, bottom, mid, top, display, mod = line:match(
        "^%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*$"
      )
      if key and key ~= "" and bottom and bottom ~= "" then
        store[key] = {
          chest   = bottom,
          mid     = (mid ~= "" and mid) or nil,
          top     = (top ~= "" and top) or nil,
          display = display or key,
          mod     = mod or "unknown",
        }
      end
    end
    line = f.readLine()
  end
  f.close()
  return store
end

function M.save(store)
  if not fs.exists("/data") then fs.makeDir("/data") end
  local f = fs.open(CFG, "w")
  if not f then return false end
  f.writeLine("# key | bottom | mid | top | display | mod")
  local keys = {}
  for k in pairs(store) do table.insert(keys, k) end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local d = store[key]
    f.writeLine(
      key            .. " | " ..
      d.chest        .. " | " ..
      (d.mid  or "") .. " | " ..
      (d.top  or "") .. " | " ..
      d.display      .. " | " ..
      d.mod
    )
  end
  f.close()
  return true
end

function M.getStock(data)
  local function count(name)
    if not name or name == "" then return 0, 0 end
    local c = peripheral.wrap(name)
    if not c then return 0, 0 end
    local n, s = 0, 0
    local ok, items = pcall(c.list)
    if ok and items then
      for _, stack in pairs(items) do
        n = n + stack.count
        s = s + 1
      end
    end
    return n, s
  end
  local bot_n, bot_s = count(data.chest)
  local total = bot_n
  if bot_s >= CHEST_SLOTS then
    local mid_n, mid_s = count(data.mid)
    total = total + mid_n
    if mid_s >= CHEST_SLOTS then
      total = total + count(data.top)
    end
  end
  local overflow = false
  if data.top and data.top ~= "" then
    local _, top_s = count(data.top)
    overflow = top_s >= math.floor(CHEST_SLOTS * 0.75)
  end
  local pct = math.floor(total / (CHEST_SLOTS * 3 * 64) * 100)
  return total, pct, overflow
end

return M
