-- shared/lib/storage.lua
-- Handles storage.cfg read/write and chest stock queries
-- Used by storage-server and discover script

local M = {}

local CFG         = "/storage/data/storage.cfg"
local CHEST_SLOTS = 108  -- obsidian chest slots
local CHEST_MAX   = CHEST_SLOTS * 64  -- 6912 items max per chest

-- Build canonical item key from name and damage
function M.makeKey(name, damage)
  damage = damage or 0
  if damage == 0 then return name end
  return name .. ":" .. tostring(damage)
end

-- Load storage.cfg
-- Format: key | bottom_chest | mid_chest | top_chest | display | mod
function M.load()
  local store = {}
  local f = fs.open(CFG, "r")
  if not f then return store end
  local line = f.readLine()
  while line do
    if not line:match("^#") and line:match("|") then
      local key, chest, mid, top, display, mod = line:match(
        "^%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*$"
      )
      if key and key ~= "" and chest and chest ~= "" then
        store[key] = {
          chest   = chest,
          mid     = (mid   ~= "" and mid)   or nil,
          top     = (top   ~= "" and top)   or nil,
          display = display or key,
          mod     = mod     or "unknown",
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
  local f = fs.open(CFG, "w")
  if not f then return false end
  f.writeLine("# key | bottom_chest | mid_chest | top_chest | display | mod")
  for key, data in pairs(store) do
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

-- Count items in a chest peripheral
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

-- Get stock for an item
-- Returns: total_count, pct_full(0-100), overflow_warning
function M.getStock(data)
  local bot_count, bot_slots = countChest(data.chest)
  local bot_full  = (bot_slots >= CHEST_SLOTS)
  local total     = bot_count

  -- Only check upper chests if bottom is full
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

  -- Percentage across all 3 chests
  local max   = CHEST_MAX * 3
  local pct   = math.floor((total / max) * 100)

  return total, pct, overflow
end

-- Search store for items matching query
-- Returns list of {key, data} sorted by relevance
function M.search(store, query)
  if not query or query == "" then return {} end
  query = query:lower()

  local exact   = {}
  local partial = {}

  for key, data in pairs(store) do
    local display_l = data.display:lower()
    local key_l     = key:lower()
    local mod_l     = data.mod:lower()

    if display_l == query or key_l == query then
      table.insert(exact, {key=key, data=data})
    elseif display_l:find(query, 1, true)
        or key_l:find(query, 1, true)
        or mod_l:find(query, 1, true) then
      table.insert(partial, {key=key, data=data})
    end
  end

  local results = {}
  for _, v in ipairs(exact)   do table.insert(results, v) end
  for _, v in ipairs(partial) do table.insert(results, v) end
  return results
end

return M
