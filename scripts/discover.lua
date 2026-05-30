-- discover.lua
-- Scans all obsidian chests on the network
-- Groups into columns of 3 (bottom/mid/top)
-- Reads first item in each bottom chest
-- Writes to /data/storage.cfg
--
-- Usage: discover

local storage = require("/scripts/lib/storage")
local MODEM   = "back"

if not rednet.isOpen(MODEM) then
  pcall(rednet.open, MODEM)
end

print("=== DISCOVER ===")
print("")

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
  print("No obsidian chests found.")
  print("Check modem and cable connections.")
  return
end

table.sort(chests, function(a,b) return a.num < b.num end)
print("Found " .. #chests .. " chests")
if #chests % 3 ~= 0 then
  print("WARNING: not divisible by 3 - some columns may be incomplete")
end
print("")

local store   = storage.load()
local found, skipped, empty, errors = 0, 0, 0, 0

local i = 1
while i <= #chests do
  local bot = chests[i]
  local mid = chests[i+1]
  local top = chests[i+2]

  -- Incomplete group
  if not mid or not top then
    print("SKIP: incomplete group at " .. bot.name)
    errors = errors + 1
    i = i + 1

  -- Non-consecutive
  elseif mid.num ~= bot.num+1 or top.num ~= bot.num+2 then
    print("SKIP: non-consecutive " ..
          bot.num..", "..mid.num..", "..top.num)
    errors = errors + 1
    i = i + 1

  else
    local chest = peripheral.wrap(bot.name)
    if not chest then
      print("OFFLINE: " .. bot.name)
      errors = errors + 1
      i = i + 3
    else
      -- Find first item
      local meta = nil
      local ok_list, items = pcall(chest.list)
      if ok_list and items then
        for slot, _ in pairs(items) do
          local ok_meta, m = pcall(chest.getItemMeta, slot)
          if ok_meta and m then meta = m; break end
        end
      end

      if meta then
        local key     = storage.makeKey(meta.name, meta.damage or 0)
        local display = meta.displayName or meta.name
        local mod     = meta.name:match("^(.-):")  or "unknown"

        if store[key] then
          print("SKIP: " .. display .. " (already mapped)")
          skipped = skipped + 1
        else
          store[key] = {
            chest   = bot.name,
            mid     = mid.name,
            top     = top.name,
            display = display,
            mod     = mod,
          }
          print("FOUND: " .. display ..
                " [" .. bot.name ..
                " / " .. mid.name ..
                " / " .. top.name .. "]")
          found = found + 1
        end
      else
        print("EMPTY: " .. bot.name)
        empty = empty + 1
      end

      i = i + 3
    end
  end
end

print("")
print("=== RESULTS ===")
print("New:     " .. found)
print("Skipped: " .. skipped)
print("Empty:   " .. empty)
if errors > 0 then print("Errors:  " .. errors) end

if found > 0 then
  if storage.save(store) then
    print("")
    print("Saved to /data/storage.cfg")
  else
    print("ERROR: could not save storage.cfg")
  end
else
  print("Nothing new to save")
end
