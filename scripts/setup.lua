-- setup.lua
-- One-time interactive setup for storage system
-- Assigns bash chest, buffer chest, and groups
-- remaining chests into columns of 3
-- Saves to /data/config.cfg and /data/columns.cfg
--
-- Run this whenever:
--   - First time setting up
--   - Modem gets replaced (peripheral renumbered)
--   - New columns added
--   - Bash/buffer chest changes
--
-- Usage: setup

local printer = require("/scripts/lib/printer")
local MODEM   = "back"

if not rednet.isOpen(MODEM) then pcall(rednet.open, MODEM) end

local W = term.getSize()

local function header(title)
  term.setTextColor(colors.yellow)
  print(string.rep("=", W))
  print("  " .. title)
  print(string.rep("=", W))
  term.setTextColor(colors.white)
end

local function ok(msg)
  term.setTextColor(colors.green)
  print("[OK] " .. msg)
  term.setTextColor(colors.white)
end

local function warn(msg)
  term.setTextColor(colors.yellow)
  print("[WARN] " .. msg)
  term.setTextColor(colors.white)
end

local function err(msg)
  term.setTextColor(colors.red)
  print("[ERROR] " .. msg)
  term.setTextColor(colors.white)
end

-- ============================================================
-- SCAN ALL OBSIDIAN CHESTS
-- ============================================================
local function scanChests()
  local chests = {}
  for _, name in ipairs(peripheral.getNames()) do
    if name:find("ironchest_obsidian") then
      local num = tonumber(name:match("_(%d+)$"))
      if num then
        -- Get first item for identification
        local c = peripheral.wrap(name)
        local first_item = "(empty)"
        if c then
          local ok_l, items = pcall(c.list)
          if ok_l and items then
            for slot, stack in pairs(items) do
              local ok_m, meta = pcall(c.getItemMeta, slot)
              if ok_m and meta then
                first_item = meta.displayName or meta.name
              end
              break
            end
          end
        end
        table.insert(chests, {
          name       = name,
          num        = num,
          first_item = first_item,
        })
      end
    end
  end
  table.sort(chests, function(a,b) return a.num < b.num end)
  return chests
end

-- ============================================================
-- DISPLAY CHEST LIST
-- ============================================================
local function displayChests(chests, excluded)
  excluded = excluded or {}
  print("")
  print(string.format("  %-6s %-40s %s", "NUM", "PERIPHERAL NAME", "CONTENTS"))
  print("  " .. string.rep("-", 70))
  for _, c in ipairs(chests) do
    local tag = ""
    if excluded[c.name] == "bash"   then tag = " [BASH]"
    elseif excluded[c.name] == "buffer" then tag = " [BUFFER]"
    end
    local color = excluded[c.name] and colors.yellow or colors.white
    term.setTextColor(color)
    print(string.format("  %-6d %-40s %s%s",
      c.num,
      c.name:sub(1,39),
      c.first_item:sub(1,20),
      tag))
    term.setTextColor(colors.white)
  end
  print("")
end

-- ============================================================
-- PICK A CHEST INTERACTIVELY
-- ============================================================
local function pickChest(chests, prompt, excluded)
  excluded = excluded or {}
  while true do
    io.write(prompt .. " (enter number): ")
    local input = io.read()
    local num   = tonumber(input)
    if not num then
      err("Enter a chest number")
    else
      for _, c in ipairs(chests) do
        if c.num == num then
          if excluded[c.name] then
            err("Already assigned as " .. excluded[c.name])
          else
            return c
          end
        end
      end
      err("Chest " .. num .. " not found")
    end
  end
end

-- ============================================================
-- GROUP REMAINING CHESTS INTO COLUMNS
-- Excludes bash and buffer chests
-- Validates divisibility by 3
-- Handles gaps in numbering
-- ============================================================
local function groupColumns(chests, bash_name, buffer_name)
  -- Filter out bash and buffer
  local storage = {}
  for _, c in ipairs(chests) do
    if c.name ~= bash_name and c.name ~= buffer_name then
      table.insert(storage, c)
    end
  end

  -- Check divisibility
  if #storage % 3 ~= 0 then
    warn("Storage chest count (" .. #storage .. ") not divisible by 3")
    warn("You have " .. (#storage % 3) .. " orphaned chest(s)")
    warn("Add or remove chests until count is divisible by 3")
    return nil
  end

  if #storage < 3 then
    err("Need at least 3 storage chests")
    return nil
  end

  -- Group into columns of 3 in numerical order
  -- Does NOT assume consecutive - just takes groups of 3
  -- sorted by peripheral number
  local columns = {}
  local i = 1
  while i <= #storage do
    table.insert(columns, {
      bottom = storage[i].name,
      mid    = storage[i+1].name,
      top    = storage[i+2].name,
    })
    i = i + 3
  end

  return columns
end

-- ============================================================
-- SAVE CONFIG
-- ============================================================
local function saveConfig(bash, buffer, columns)
  if not fs.exists("/data") then fs.makeDir("/data") end

  -- Save config.cfg (bash + buffer)
  local f = fs.open("/data/config.cfg", "w")
  f.writeLine("# Storage system configuration")
  f.writeLine("bash   = " .. bash)
  f.writeLine("buffer = " .. buffer)
  f.close()

  -- Save columns.cfg
  local g = fs.open("/data/columns.cfg", "w")
  g.writeLine("# Column assignments")
  g.writeLine("# Format: bottom | mid | top")
  g.writeLine("# Generated by setup.lua - do not edit manually")
  g.writeLine("")
  for i, col in ipairs(columns) do
    g.writeLine(col.bottom .. " | " .. col.mid .. " | " .. col.top)
  end
  g.close()

  return true
end

-- ============================================================
-- VALIDATE EXISTING CONFIG
-- Check all chests are still online
-- ============================================================
local function validateExisting()
  if not fs.exists("/data/config.cfg") or
     not fs.exists("/data/columns.cfg") then
    return false, "No config found"
  end

  -- Load config.cfg
  local bash, buffer = nil, nil
  local f = fs.open("/data/config.cfg", "r")
  local line = f.readLine()
  while line do
    local k, v = line:match("^%s*(.-)%s*=%s*(.-)%s*$")
    if k == "bash"   then bash   = v end
    if k == "buffer" then buffer = v end
    line = f.readLine()
  end
  f.close()

  -- Load columns.cfg
  local columns = {}
  local g = fs.open("/data/columns.cfg", "r")
  line = g.readLine()
  while line do
    if not line:match("^#") and line:match("|") then
      local bot, mid, top = line:match(
        "^%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*$")
      if bot and mid and top then
        table.insert(columns, {bottom=bot, mid=mid, top=top})
      end
    end
    line = g.readLine()
  end
  g.close()

  -- Validate all chests online
  local issues = {}
  local function check(name, label)
    if not peripheral.wrap(name) then
      table.insert(issues, label .. ": OFFLINE (" .. name .. ")")
    end
  end

  if bash   then check(bash,   "Bash chest")   end
  if buffer then check(buffer, "Buffer chest") end
  for i, col in ipairs(columns) do
    check(col.bottom, "Col " .. i .. " bottom")
    check(col.mid,    "Col " .. i .. " mid")
    check(col.top,    "Col " .. i .. " top")
  end

  return #issues == 0, issues, bash, buffer, columns
end

-- ============================================================
-- PRINT SUMMARY TO PRINTER
-- ============================================================
local function printSummary(bash, buffer, columns)
  local has_printer = printer.open("Setup Summary")
  if not has_printer then return end

  printer.writeLine("STORAGE SETUP SUMMARY")
  printer.writeLine(string.rep("-", 25))
  printer.writeLine("")
  printer.writeLine("Bash:   " .. (bash   or "none"))
  printer.writeLine("Buffer: " .. (buffer or "none"))
  printer.writeLine("")
  printer.writeLine("Columns: " .. #columns)
  printer.writeLine("")
  for i, col in ipairs(columns) do
    local bot_num = col.bottom:match("_(%d+)$") or "?"
    local mid_num = col.mid:match("_(%d+)$")    or "?"
    local top_num = col.top:match("_(%d+)$")    or "?"
    printer.writeLine(string.format(
      "Col%2d: %s/%s/%s",
      i, bot_num, mid_num, top_num))
  end
  printer.writeLine("")
  printer.writeLine(string.rep("-", 25))
  printer.writeLine("Total storage chests:")
  printer.writeLine(tostring(#columns * 3))
  printer.close()
end

-- ============================================================
-- MAIN
-- ============================================================
header("STORAGE SETUP")
print("")

-- Check for existing valid config first
local valid, issues, e_bash, e_buffer, e_cols = validateExisting()

if valid then
  ok("Existing config is valid")
  print("  Bash:    " .. e_bash)
  print("  Buffer:  " .. e_buffer)
  print("  Columns: " .. #e_cols)
  print("")
  io.write("Reconfigure? (yes/no): ")
  local ans = io.read():lower()
  if ans ~= "yes" and ans ~= "y" then
    print("Setup complete - no changes made")
    return
  end
elseif type(issues) == "table" and #issues > 0 then
  warn("Config has issues:")
  for _, issue in ipairs(issues) do
    err(" " .. issue)
  end
  print("")
  print("Run setup to reconfigure")
  print("")
elseif type(issues) == "string" then
  warn(issues)
  print("")
end

-- Scan chests
print("Scanning chests...")
local chests = scanChests()

if #chests == 0 then
  err("No obsidian chests found on back modem!")
  err("Check modem and cable connections")
  return
end

print("Found " .. #chests .. " obsidian chests")
print("")

-- Display all chests
displayChests(chests, {})

-- Pick bash chest
header("STEP 1: ASSIGN BASH CHEST")
print("The bash chest receives:")
print("  - Decompression remainders")
print("  - Alloy overflow")
print("  - Crafting remainders")
print("")
displayChests(chests, {})
local bash_chest = pickChest(chests, "Bash chest")
ok("Bash: " .. bash_chest.name)

-- Pick buffer chest
print("")
header("STEP 2: ASSIGN BUFFER CHEST")
print("The buffer chest is where requested")
print("items are delivered for pickup")
print("")
local excluded = {[bash_chest.name] = "bash"}
displayChests(chests, excluded)
local buffer_chest = pickChest(chests, "Buffer chest", excluded)
ok("Buffer: " .. buffer_chest.name)

-- Group remaining into columns
print("")
header("STEP 3: COLUMN GROUPING")
excluded[buffer_chest.name] = "buffer"

local storage_chests = {}
for _, c in ipairs(chests) do
  if c.name ~= bash_chest.name and
     c.name ~= buffer_chest.name then
    table.insert(storage_chests, c)
  end
end

print("Storage chests: " .. #storage_chests)
print("")

if #storage_chests % 3 ~= 0 then
  warn("Storage chests (" .. #storage_chests ..
       ") not divisible by 3!")
  warn("Orphaned: " .. (#storage_chests % 3) .. " chest(s)")
  warn("Columns will be grouped from the bottom up.")
  warn("Remaining orphaned chests will be ignored.")
  print("")
  io.write("Continue anyway? (yes/no): ")
  local ans = io.read():lower()
  if ans ~= "yes" and ans ~= "y" then
    print("Setup cancelled.")
    return
  end
end

-- Group into columns of 3
local columns = {}
local i = 1
while i + 2 <= #storage_chests do
  local col = {
    bottom = storage_chests[i].name,
    mid    = storage_chests[i+1].name,
    top    = storage_chests[i+2].name,
  }
  table.insert(columns, col)
  i = i + 3
end

print("Columns: " .. #columns)
print("")

-- Show column assignments
print(string.format("  %-5s %-12s %-12s %-12s",
  "COL", "BOTTOM", "MID", "TOP"))
print("  " .. string.rep("-", 45))
for idx, col in ipairs(columns) do
  local bot = col.bottom:match("_(%d+)$") or "?"
  local mid = col.mid:match("_(%d+)$")    or "?"
  local top = col.top:match("_(%d+)$")    or "?"
  print(string.format("  %-5d %-12s %-12s %-12s",
    idx, bot, mid, top))
end

-- Confirm
print("")
io.write("Save this configuration? (yes/no): ")
local confirm = io.read():lower()
if confirm ~= "yes" and confirm ~= "y" then
  print("Setup cancelled.")
  return
end

-- Save
saveConfig(bash_chest.name, buffer_chest.name, columns)
print("")
ok("Saved /data/config.cfg")
ok("Saved /data/columns.cfg")
print("")
print("Columns: " .. #columns)
print("Storage chests: " .. (#columns * 3))
print("")

-- Print summary
printSummary(bash_chest.name, buffer_chest.name, columns)

print("Run: discover")
