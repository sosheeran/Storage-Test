-- health.lua
-- Storage-Test health/audit tool
--
-- Run:
--   health
--
-- Checks:
--   - config files exist
--   - special chests are online
--   - storage columns have 3 chests
--   - mapped chests are online
--   - duplicate assignments
--   - accidental use of special chests in storage
--   - mixed-item columns
--   - rough fullness per column

local CONFIG_PATH  = "/data/config.cfg"
local COLUMNS_PATH = "/data/columns.cfg"

local function color(c)
  if term.isColor and term.isColor() then
    term.setTextColor(c)
  end
end

local function reset()
  color(colors.white)
end

local function ok(msg)
  color(colors.green)
  print("[OK] " .. msg)
  reset()
end

local function warn(msg)
  color(colors.yellow)
  print("[WARN] " .. msg)
  reset()
end

local function err(msg)
  color(colors.red)
  print("[ERR] " .. msg)
  reset()
end

local function info(msg)
  color(colors.lightGray)
  print("[INFO] " .. msg)
  reset()
end

local function trim(s)
  if not s then return "" end
  return s:match("^%s*(.-)%s*$")
end

local function chestNum(name)
  if not name then return "?" end
  return tostring(name):match("_(%d+)$") or "?"
end

local function isOnline(name)
  return type(name) == "string" and peripheral.wrap(name) ~= nil
end

local function isInventory(name)
  local p = peripheral.wrap(name)
  return p and type(p.list) == "function"
end

local function loadConfig()
  local cfg = {}

  if not fs.exists(CONFIG_PATH) then
    return nil, "Missing " .. CONFIG_PATH
  end

  local f = fs.open(CONFIG_PATH, "r")
  if not f then
    return nil, "Could not open " .. CONFIG_PATH
  end

  local line = f.readLine()
  while line do
    local k, v = line:match("^%s*(.-)%s*=%s*(.-)%s*$")
    if k and v and k ~= "" then
      cfg[trim(k)] = trim(v)
    end
    line = f.readLine()
  end

  f.close()
  return cfg
end

local function loadColumns()
  if not fs.exists(COLUMNS_PATH) then
    return nil, "Missing " .. COLUMNS_PATH
  end

  local columns = {}
  local f = fs.open(COLUMNS_PATH, "r")
  if not f then
    return nil, "Could not open " .. COLUMNS_PATH
  end

  local line = f.readLine()
  while line do
    local clean = trim(line)

    if clean ~= "" and not clean:match("^#") and clean:find("|", 1, true) then
      local bottom, mid, top =
        clean:match("^%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*$")

      bottom = trim(bottom)
      mid = trim(mid)
      top = trim(top)

      table.insert(columns, {
        bottom = bottom,
        mid = mid,
        top = top,
      })
    end

    line = f.readLine()
  end

  f.close()

  if #columns == 0 then
    return nil, "No columns found in " .. COLUMNS_PATH
  end

  return columns
end

local function getInventoryStats(name)
  local inv = peripheral.wrap(name)
  if not inv or not inv.list then
    return {
      online = false,
      usedSlots = 0,
      totalSlots = 0,
      itemCounts = {},
      totalItems = 0,
    }
  end

  local totalSlots = 0
  if inv.size then
    local okSize, size = pcall(inv.size)
    if okSize and size then
      totalSlots = size
    end
  end

  local itemCounts = {}
  local usedSlots = 0
  local totalItems = 0

  local okList, items = pcall(inv.list)
  if okList and items then
    for slot, stack in pairs(items) do
      if stack then
        usedSlots = usedSlots + 1
        totalItems = totalItems + (stack.count or 0)

        local name = stack.name or "unknown"
        itemCounts[name] = (itemCounts[name] or 0) + (stack.count or 0)
      end
    end
  end

  return {
    online = true,
    usedSlots = usedSlots,
    totalSlots = totalSlots,
    itemCounts = itemCounts,
    totalItems = totalItems,
  }
end

local function countKeys(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

local function firstKey(t)
  for k in pairs(t) do return k end
  return nil
end

local function mergeCounts(target, source)
  for k, v in pairs(source) do
    target[k] = (target[k] or 0) + v
  end
end

local function printColumnReport(i, col)
  local names = {
    bottom = col.bottom,
    mid = col.mid,
    top = col.top,
  }

  local totalSlots = 0
  local usedSlots = 0
  local totalItems = 0
  local mergedItems = {}
  local offline = false

  for level, name in pairs(names) do
    local stats = getInventoryStats(name)

    if not stats.online then
      offline = true
    end

    totalSlots = totalSlots + stats.totalSlots
    usedSlots = usedSlots + stats.usedSlots
    totalItems = totalItems + stats.totalItems
    mergeCounts(mergedItems, stats.itemCounts)
  end

  local itemTypes = countKeys(mergedItems)
  local mainItem = firstKey(mergedItems) or "(empty)"

  local fullness = 0
  if totalSlots > 0 then
    fullness = math.floor((usedSlots / totalSlots) * 100)
  end

  local status = "OK"
  local statusColor = colors.green

  if offline then
    status = "OFFLINE"
    statusColor = colors.red
  elseif itemTypes > 1 then
    status = "MIXED"
    statusColor = colors.yellow
  elseif fullness >= 90 then
    status = "FULL"
    statusColor = colors.yellow
  elseif itemTypes == 0 then
    status = "EMPTY"
    statusColor = colors.lightGray
  end

  color(statusColor)
  print(string.format(
    "%-5d %-8s %-8s %-8s %-8s %-7s %s",
    i,
    chestNum(col.bottom),
    chestNum(col.mid),
    chestNum(col.top),
    tostring(fullness) .. "%",
    status,
    mainItem
  ))
  reset()

  return {
    offline = offline,
    mixed = itemTypes > 1,
    full = fullness >= 90,
    empty = itemTypes == 0,
  }
end

local function main()
  term.clear()
  term.setCursorPos(1, 1)

  color(colors.yellow)
  print("=== STORAGE HEALTH CHECK ===")
  reset()
  print("")

  local cfg, cfgErr = loadConfig()
  if not cfg then
    err(cfgErr)
    return
  end

  local columns, colErr = loadColumns()
  if not columns then
    err(colErr)
    return
  end

  ok("Loaded config.cfg")
  ok("Loaded columns.cfg")
  info("Columns: " .. tostring(#columns))
  print("")

  -- Build assignment map.
  local assigned = {}
  local duplicateCount = 0

  local function addAssignment(name, label)
    if not name or name == "" then
      err(label .. " is blank")
      return
    end

    if assigned[name] then
      err("Duplicate assignment: " .. name)
      err("  Used by: " .. assigned[name])
      err("  Used by: " .. label)
      duplicateCount = duplicateCount + 1
    else
      assigned[name] = label
    end
  end

  -- Special chests.
  color(colors.cyan)
  print("Special chests:")
  reset()

  for k, v in pairs(cfg) do
    addAssignment(v, "special " .. tostring(k))

    if isOnline(v) then
      ok(tostring(k) .. " online: chest " .. chestNum(v))
    else
      err(tostring(k) .. " OFFLINE: " .. tostring(v))
    end
  end

  print("")

  -- Columns.
  for i, col in ipairs(columns) do
    addAssignment(col.bottom, "column " .. i .. " bottom")
    addAssignment(col.mid,    "column " .. i .. " mid")
    addAssignment(col.top,    "column " .. i .. " top")
  end

  color(colors.cyan)
  print("Column summary:")
  reset()

  print(string.format(
    "%-5s %-8s %-8s %-8s %-8s %-7s %s",
    "COL",
    "BOTTOM",
    "MID",
    "TOP",
    "USED",
    "STATUS",
    "ITEM"
  ))

  print(string.rep("-", 72))

  local offlineCols = 0
  local mixedCols = 0
  local fullCols = 0
  local emptyCols = 0

  for i, col in ipairs(columns) do
    local result = printColumnReport(i, col)

    if result.offline then offlineCols = offlineCols + 1 end
    if result.mixed then mixedCols = mixedCols + 1 end
    if result.full then fullCols = fullCols + 1 end
    if result.empty then emptyCols = emptyCols + 1 end
  end

  print("")
  color(colors.yellow)
  print("Summary:")
  reset()

  print(" Offline columns:   " .. tostring(offlineCols))
  print(" Mixed columns:     " .. tostring(mixedCols))
  print(" Nearly full cols:  " .. tostring(fullCols))
  print(" Empty columns:     " .. tostring(emptyCols))
  print(" Duplicates:        " .. tostring(duplicateCount))
  print("")

  if offlineCols == 0 and mixedCols == 0 and duplicateCount == 0 then
    ok("Storage map looks sane.")
  else
    warn("Storage map needs attention.")
    warn("Use column_edit to repair changed or duplicate chests.")
  end
end

main()