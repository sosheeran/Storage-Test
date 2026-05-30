-- discover.lua
-- Scans all obsidian chests on the network
-- Groups into columns of 3 (bottom/mid/top)
-- Reads first item in each bottom chest
-- Writes to /data/storage.cfg
-- Prints results to printer on left side
--
-- Usage: discover

local storage = require("/scripts/lib/storage")
local printer = require("/scripts/lib/printer")
local MODEM   = "back"

if not rednet.isOpen(MODEM) then
  pcall(rednet.open, MODEM)
end

-- Open printer
local has_printer = printer.open("Discover")

print("=== DISCOVER ===")
print("")

local function out(line)
  if has_printer then
    printer.writeLine(line)
  else
    print(line)
  end
end

-- Collect all obsidian chests
local chests = {}
for _, name in ipairs(peripheral.getNames()) do
  if name:find("iron_chest_obsidian") or
     name:find("ironchest_obsidian")  then
    local num = tonumber(name:match("_(%d+)$"))
    if num then table.insert(chests, {name=name, num=num}) end
  end
end

if #chests == 0 then
  out("No obsidian chests found.")
  out("Check modem + cable connections.")
  if has_printer then printer.close() end
  return
end

table.sort(chests, function(a,b) return a.num < b.num end)
out("Found " .. #chests .. " chests")
if #chests % 3 ~= 0 then
  out("WARN: not divisible by 3")
end
out("")

local store   = storage.load()
local found, skipped, empty, errors = 0, 0, 0, 0

local i = 1
while i <= #chests do
  local bot = chests[i]
  local mid = chests[i+1]
  local top = chests[i+2]

  if not mid or not top then
    out("SKIP: incomplete at " .. bot.name)
    errors = errors + 1
    i = i + 1

  elseif mid.num ~= bot.num+1 or top.num ~= bot.num+2 then
    out("SKIP: non-consecutive " ..
        bot.num..","..mid.num..","..top.num)
    errors = errors + 1
    i = i + 1

  else
    local chest = peripheral.wrap(bot.name)
    if not chest then
      out("OFFLINE: " .. bot.name)
      errors = errors + 1
      i = i + 3
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
        -- FIX: include damage value in key
        -- This ensures vis crystals (same name, different damage)
        -- each get their own unique entry
        local damage  = meta.damage or 0
        local key     = storage.makeKey(meta.name, damage)
        local display = meta.displayName or meta.name
        local mod     = meta.name:match("^(.-):")  or "unknown"

        if store[key] then
          out("SKIP: " .. display .. " (mapped)")
          skipped = skipped + 1
        else
          store[key] = {
            chest   = bot.name,
            mid     = mid.name,
            top     = top.name,
            display = display,
            mod     = mod,
          }
          out("FOUND: " .. display)
          found = found + 1
        end
      else
        out("EMPTY: " .. bot.name)
        empty = empty + 1
      end

      i = i + 3
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
