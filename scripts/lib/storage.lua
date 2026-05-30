-- scripts/lib/storage.lua
-- Storage library for standalone scripts
-- Handles storage.cfg read/write and chest stock queries

local M = {}

local CFG         = "/storage/data/storage.cfg"
local CHEST_SLOTS = 108  -- obsidian chest slot count

-- Build canonical item key from name and damage value
function M.makeKey(name, damage)
  damage = damage or 0
  if damage == 0 then return name end
  return name .. ":" .. tostring(damage)
end

-- Load storage.cfg
-- Format: key | bottom | mid | top | display | mod
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

-- Save storage.cfg
function M.save(store)
  -- Make sure directory exists
  if not fs.exists("/storage/data") then
    fs.makeDir("/storage/data")
  end
  local f = fs.open(CFG, "w")
  if not f then
    print("ERROR: Cannot write to " .. CFG)
    return false
  end
  f.writeLine("# key | bottom_chest | mid_chest | top_chest | display | mod")
  -- Sort keys for consistent output
  local keys = {}
  for k in pairs(store) do table.insert(keys, k) end
  table.sort(keys)
  for _, key in ipairs(keys) do
    local data = store[key]
    f.writeLine(
      key               .. " | " ..
      data.chest        .. " | " ..
      (data.mid  or "") .. " | " ..
      (data.top  or "") .. " | " ..
      data.display      .. " | " ..
      data.mod
    )
  end
  f.close()
  return true
end

-- Count items in a single chest
-- Returns: count, slots_used
local function countChest(name)
  if not name or name == "" then return 0, 0 end
  local c = peripheral.wrap(name)
  if not c then return 0, 0 end
  local count, slots = 0, 0
  local ok, items = pcall(c.list)
  if not ok or not items then return 0, 0 end
  for _, stack in pairs(items) do
    count = count + stack.count
    slots = slots + 1
  end
  return count, slots
end

-- Get stock for an item column
-- Returns: total_count, pct_full(0-100), overflow_warning
function M.getStock(data)
  local bot_count, bot_slots = countChest(data.chest)
  local bot_full = (bot_slots >= CHEST_SLOTS)
  local total    = bot_count

  if bot_full then
    local mid_count, mid_slots = countChest(data.mid)
    total = total + mid_count
    if mid_slots >= CHEST_SLOTS then
      local top_count = countChest(data.top)
      total = total + top_count
    end
  end

  -- Overflow: top chest at 75%+ capacity
  local overflow = false
  if data.top and data.top ~= "" then
    local _, top_slots = countChest(data.top)
    overflow = (top_slots >= math.floor(CHEST_SLOTS * 0.75))
  end

  local max = CHEST_SLOTS * 3 * 64
  local pct = math.floor((total / max) * 100)
  return total, pct, overflow
end

return M
