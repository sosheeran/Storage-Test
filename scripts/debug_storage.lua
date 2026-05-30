-- debug_storage.lua
-- Scans every obsidian chest on the network
-- Dumps all items to /data/debug_dump.txt
--
-- Usage: debug_storage

local MODEM    = "back"
local OUT_FILE = "/data/debug_dump.txt"

if not rednet.isOpen(MODEM) then
  pcall(rednet.open, MODEM)
end

if not fs.exists("/data") then fs.makeDir("/data") end

print("=== DEBUG STORAGE SCAN ===")
print("")

-- Find all obsidian chests
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
print("Found " .. #chests .. " chests - scanning...")

local f = fs.open(OUT_FILE, "w")
f.writeLine("# debug_dump.txt")
f.writeLine("# chest | slot | item_id | damage | display | count")
f.writeLine("")

local total_stacks = 0
local total_items  = 0
local chest_count  = 0
local empty_count  = 0

for _, c in ipairs(chests) do
  local chest = peripheral.wrap(c.name)
  if not chest then
    f.writeLine("# OFFLINE: " .. c.name)
  else
    local ok_list, items = pcall(chest.list)
    if not ok_list or not items then
      f.writeLine("# ERROR: " .. c.name)
    else
      local had_items = false
      for slot, stack in pairs(items) do
        local ok_meta, meta = pcall(chest.getItemMeta, slot)
        local display = stack.name
        local damage  = 0
        if ok_meta and meta then
          display = meta.displayName or meta.name
          damage  = meta.damage or 0
        end
        f.writeLine(
          c.name            .. " | " ..
          tostring(slot)    .. " | " ..
          stack.name        .. " | " ..
          tostring(damage)  .. " | " ..
          display           .. " | " ..
          tostring(stack.count)
        )
        total_stacks = total_stacks + 1
        total_items  = total_items  + stack.count
        had_items    = true
      end
      if had_items then
        chest_count = chest_count + 1
      else
        empty_count = empty_count + 1
        f.writeLine(c.name .. " | (empty)")
      end
    end
  end
end

f.writeLine("")
f.writeLine("# Chests scanned:    " .. #chests)
f.writeLine("# Chests with items: " .. chest_count)
f.writeLine("# Empty chests:      " .. empty_count)
f.writeLine("# Total stacks:      " .. total_stacks)
f.writeLine("# Total items:       " .. total_items)
f.close()

print("")
print("Chests scanned:    " .. #chests)
print("Chests with items: " .. chest_count)
print("Empty chests:      " .. empty_count)
print("Total stacks:      " .. total_stacks)
print("Total items:       " .. total_items)
print("")
print("Saved to " .. OUT_FILE)
