-- debug_storage.lua
-- Dumps raw peripheral information for troubleshooting
-- Shows all peripherals visible on network, chest contents,
-- and storage.cfg mapping status
--
-- Usage:
--   debug_storage              (full dump)
--   debug_storage peripherals  (list all peripherals only)
--   debug_storage chests       (list chests and contents)
--   debug_storage cfg          (show storage.cfg contents)
--   debug_storage check <key>  (check specific item)

local storage = require("/scripts/lib/storage")

local args = {...}
local mode = args[1] or "full"

local W = term.getSize()

local function header(title)
  term.setTextColor(colors.yellow)
  print(string.rep("=", W))
  print("  " .. title)
  print(string.rep("=", W))
  term.setTextColor(colors.white)
end

local function section(title)
  term.setTextColor(colors.lightBlue)
  print("")
  print("--- " .. title .. " ---")
  term.setTextColor(colors.white)
end

-- ============================================================
-- MODE: peripherals
-- List all peripherals visible on network
-- ============================================================
local function showPeripherals()
  header("ALL PERIPHERALS")
  local names = peripheral.getNames()
  table.sort(names)

  local counts = {}
  for _, name in ipairs(names) do
    local ptype = peripheral.getType(name)
    counts[ptype] = (counts[ptype] or 0) + 1
    print(string.format("  %-45s %s", name, ptype))
  end

  print("")
  print("SUMMARY:")
  local types = {}
  for t in pairs(counts) do table.insert(types, t) end
  table.sort(types)
  for _, t in ipairs(types) do
    print(string.format("  %-30s x%d", t, counts[t]))
  end
  print("")
  print("Total: " .. #names .. " peripherals")
end

-- ============================================================
-- MODE: chests
-- List all obsidian chests and their first item
-- ============================================================
local function showChests()
  header("OBSIDIAN CHESTS")
  local names = peripheral.getNames()
  local chests = {}

  for _, name in ipairs(names) do
    if name:find("iron_chest_obsidian") or
       name:find("ironchest_obsidian") then
      local num = tonumber(name:match("_(%d+)$"))
      if num then table.insert(chests, {name=name, num=num}) end
    end
  end

  if #chests == 0 then
    term.setTextColor(colors.red)
    print("No obsidian chests found on network!")
    term.setTextColor(colors.white)
    return
  end

  table.sort(chests, function(a,b) return a.num < b.num end)
  print("Found " .. #chests .. " chests (" ..
        math.floor(#chests/3) .. " complete columns)")
  print("")
  print(string.format("  %-45s %-6s %s",
    "CHEST NAME", "SLOTS", "FIRST ITEM"))
  print("  " .. string.rep("-", 75))

  for _, c in ipairs(chests) do
    local chest = peripheral.wrap(c.name)
    if not chest then
      term.setTextColor(colors.red)
      print(string.format("  %-45s OFFLINE", c.name))
      term.setTextColor(colors.white)
    else
      local ok_list, items = pcall(chest.list)
      local slots = 0
      local first_item = "(empty)"
      local first_count = 0

      if ok_list and items then
        for slot, stack in pairs(items) do
          slots = slots + 1
          if slots == 1 then
            -- Get display name
            local ok_meta, meta = pcall(chest.getItemMeta, slot)
            if ok_meta and meta then
              first_item  = meta.displayName or meta.name
              first_count = stack.count
            else
              first_item  = stack.name
              first_count = stack.count
            end
          end
        end
      end

      local color = colors.white
      if slots == 0 then color = colors.lightGray
      elseif slots >= 108 then color = colors.orange end

      term.setTextColor(color)
      print(string.format("  %-45s %3d/108  %s%s",
        c.name,
        slots,
        first_item,
        first_count > 0 and (" x" .. first_count) or ""))
      term.setTextColor(colors.white)
    end
  end
end

-- ============================================================
-- MODE: cfg
-- Show contents of storage.cfg
-- ============================================================
local function showCfg()
  header("STORAGE.CFG CONTENTS")
  local store = storage.load()

  if not next(store) then
    term.setTextColor(colors.yellow)
    print("storage.cfg is empty or not found")
    print("Run: discover")
    term.setTextColor(colors.white)
    return
  end

  local keys = {}
  for k in pairs(store) do table.insert(keys, k) end
  table.sort(keys)

  print(string.format("  %-35s %-12s %-12s %-12s",
    "KEY", "BOTTOM", "MID", "TOP"))
  print("  " .. string.rep("-", 75))

  for _, key in ipairs(keys) do
    local data = store[key]
    -- Check if chests are accessible
    local bot_ok = peripheral.wrap(data.chest) ~= nil
    local mid_ok = not data.mid or peripheral.wrap(data.mid) ~= nil
    local top_ok = not data.top or peripheral.wrap(data.top) ~= nil

    local color = colors.white
    if not bot_ok then color = colors.red
    elseif not mid_ok or not top_ok then color = colors.yellow end

    term.setTextColor(color)
    print(string.format("  %-35s %-12s %-12s %-12s",
      key:sub(1, 34),
      data.chest:match("_(%d+)$") or data.chest,
      data.mid and (data.mid:match("_(%d+)$") or data.mid) or "-",
      data.top and (data.top:match("_(%d+)$") or data.top) or "-"))
    term.setTextColor(colors.white)
  end

  print("")
  print("Total entries: " .. #keys)
  print("")
  print("Legend:")
  term.setTextColor(colors.red)
  print("  RED    = bottom chest offline")
  term.setTextColor(colors.yellow)
  print("  YELLOW = mid/top chest offline")
  term.setTextColor(colors.white)
  print("  WHITE  = all chests online")
end

-- ============================================================
-- MODE: check <key>
-- Check a specific item in detail
-- ============================================================
local function checkItem(key)
  if not key then
    print("Usage: debug_storage check <item_key>")
    print("Example: debug_storage check minecraft:iron_block")
    return
  end

  header("ITEM CHECK: " .. key)
  local store = storage.load()
  local data  = store[key]

  if not data then
    term.setTextColor(colors.red)
    print("Item not found in storage.cfg: " .. key)
    term.setTextColor(colors.white)
    print("")
    print("Try: debug_storage cfg")
    return
  end

  print("Display: " .. data.display)
  print("Mod:     " .. data.mod)
  print("")

  -- Check each chest
  local chests = {
    {label="Bottom", name=data.chest},
    {label="Mid",    name=data.mid},
    {label="Top",    name=data.top},
  }

  local total = 0
  for _, c in ipairs(chests) do
    if not c.name then
      print(c.label .. ": not configured")
    else
      local chest = peripheral.wrap(c.name)
      if not chest then
        term.setTextColor(colors.red)
        print(c.label .. ": OFFLINE (" .. c.name .. ")")
        term.setTextColor(colors.white)
      else
        local ok_list, items = pcall(chest.list)
        local count, slots = 0, 0
        if ok_list and items then
          for _, stack in pairs(items) do
            count = count + stack.count
            slots = slots + 1
          end
        end
        total = total + count
        local color = colors.white
        if slots >= 108 then color = colors.orange end
        if slots == 0   then color = colors.lightGray end
        term.setTextColor(color)
        print(string.format("%s: %s  %d items  %d/108 slots used",
          c.label, c.name, count, slots))
        term.setTextColor(colors.white)
      end
    end
  end

  print("")
  local total_pct = math.floor(total / (108 * 3 * 64) * 100)
  print("TOTAL: " .. total .. " items (" .. total_pct .. "% full)")
end

-- ============================================================
-- MODE: full
-- ============================================================
local function showFull()
  showPeripherals()
  print("")
  showChests()
  print("")
  showCfg()
end

-- ============================================================
-- DISPATCH
-- ============================================================
if mode == "peripherals" then
  showPeripherals()
elseif mode == "chests" then
  showChests()
elseif mode == "cfg" then
  showCfg()
elseif mode == "check" then
  checkItem(args[2])
elseif mode == "full" then
  showFull()
else
  print("Unknown mode: " .. mode)
  print("Usage: debug_storage [peripherals|chests|cfg|check <key>|full]")
end
