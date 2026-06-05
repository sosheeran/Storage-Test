-- discover.lua
-- Scans storage columns defined in /data/columns.cfg
-- Identifies contents of each bottom chest
-- Handles NBT-differentiated items (vis crystals etc)
-- Writes to /data/storage.cfg
-- Prints results to printer on left side
--
-- Run setup.lua first to configure columns
-- Usage: discover

local storage = require("/scripts/lib/storage")
local printer = require("/scripts/lib/printer")
local MODEM   = "back"

if not rednet.isOpen(MODEM) then pcall(rednet.open, MODEM) end

local has_printer = printer.open("Discover")

local function out(line)
  if has_printer then printer.writeLine(line or "")
  else print(line or "") end
end

local function loadConfig()
  local cfg = {}
  if not fs.exists("/data/config.cfg") then
    return nil, "config.cfg not found - run setup first"
  end
  local f = fs.open("/data/config.cfg", "r")
  local line = f.readLine()
  while line do
    local k, v = line:match("^%s*(.-)%s*=%s*(.-)%s*$")
    if k and v and k ~= "" then cfg[k] = v end
    line = f.readLine()
  end
  f.close()
  if not cfg.bash   then return nil, "bash not configured"   end
  if not cfg.buffer then return nil, "buffer not configured" end
  return cfg, nil
end

local function loadColumns()
  local columns = {}
  if not fs.exists("/data/columns.cfg") then
    return nil, "columns.cfg not found - run setup first"
  end
  local f = fs.open("/data/columns.cfg", "r")
  local line = f.readLine()
  while line do
    if not line:match("^#") and line:match("|") then
      local bot, mid, top = line:match(
        "^%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*$")
      if bot and mid and top and
         bot ~= "" and mid ~= "" and top ~= "" then
        table.insert(columns, {bottom=bot, mid=mid, top=top})
      end
    end
    line = f.readLine()
  end
  f.close()
  if #columns == 0 then
    return nil, "No columns defined - run setup first"
  end
  return columns, nil
end

local function validate(cfg, columns)
  local issues = {}
  if not peripheral.wrap(cfg.bash) then
    table.insert(issues, "BASH offline: " .. cfg.bash)
  end
  if not peripheral.wrap(cfg.buffer) then
    table.insert(issues, "BUFFER offline: " .. cfg.buffer)
  end
  if cfg.bash == cfg.buffer then
    table.insert(issues, "Bash and buffer are same chest!")
  end
  for i, col in ipairs(columns) do
    for pos, chest in pairs({
      bottom=col.bottom, mid=col.mid, top=col.top}) do
      if chest == cfg.bash then
        table.insert(issues,
          "Bash is in column " .. i .. " " .. pos .. "!")
      end
      if chest == cfg.buffer then
        table.insert(issues,
          "Buffer is in column " .. i .. " " .. pos .. "!")
      end
      if not peripheral.wrap(chest) then
        table.insert(issues,
          "Col " .. i .. " " .. pos .. " offline: " .. chest)
      end
    end
  end
  return issues
end

-- Main
out("=== DISCOVER ===")
out("")

local cfg, cfg_err = loadConfig()
if not cfg then
  out("ERROR: " .. cfg_err)
  if has_printer then printer.close() end
  return
end

local columns, col_err = loadColumns()
if not columns then
  out("ERROR: " .. col_err)
  if has_printer then printer.close() end
  return
end

out("Bash:    " .. cfg.bash)
out("Buffer:  " .. cfg.buffer)
out("Columns: " .. #columns)
out("")

local issues = validate(cfg, columns)
if #issues > 0 then
  out("WARNINGS:")
  for _, issue in ipairs(issues) do
    out("  ! " .. issue)
  end
  local fatal = false
  for _, issue in ipairs(issues) do
    if issue:find("same chest") or issue:find("is in column") then
      fatal = true
    end
  end
  if fatal then
    out("Fatal errors - run setup to fix")
    if has_printer then printer.close() end
    return
  end
  out("")
end

local store = storage.load()
local found, skipped, empty, errors = 0, 0, 0, 0

for col_idx, col in ipairs(columns) do
  local chest = peripheral.wrap(col.bottom)
  if not chest then
    out("OFFLINE: col " .. col_idx)
    errors = errors + 1
  else
    local meta = nil
    local ok_list, items = pcall(chest.list)
    if ok_list and items then
      for slot, _ in pairs(items) do
        local ok_meta, m = pcall(chest.getItemMeta, slot)
        if ok_meta and m then meta = m; break end
      end
    end

    if meta then
      local damage   = meta.damage or 0
      local display  = meta.displayName or meta.name
      local mod      = meta.name:match("^(.-):")  or "unknown"
      local base_key = storage.makeKey(meta.name, damage)
      local key      = base_key

      if store[key] and store[key].chest ~= col.bottom then
        key = base_key .. ":" ..
              display:lower():gsub("[%s/%-]", "_")
      end

      if store[key] then
        out("SKIP: " .. display .. " (mapped)")
        skipped = skipped + 1
      else
        store[key] = {
          chest   = col.bottom,
          mid     = col.mid,
          top     = col.top,
          display = display,
          mod     = mod,
        }
        out("FOUND: " .. display)
        found = found + 1
      end
    else
      out("EMPTY: col " .. col_idx)
      empty = empty + 1
    end
  end
end

out("")
out(string.rep("-", 25))
out("New:     " .. found)
out("Skipped: " .. skipped)
out("Empty:   " .. empty)
if errors > 0 then out("Errors:  " .. errors) end

if found > 0 then
  if storage.save(store) then
    out("")
    out("Saved to storage.cfg")
  else
    out("ERROR: could not save!")
  end
else
  out("Nothing new to save")
end

if has_printer then printer.close() end
