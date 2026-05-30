-- debug_storage.lua
-- Scans all peripherals on the network and dumps
-- every item found in every obsidian chest to a file
--
-- Usage: debug_storage
-- Output: /storage/data/debug_dump.txt

local MODEM_SIDE = "back"
local OUT_FILE   = "/storage/data/debug_dump.txt"

-- Open modem
if not rednet.isOpen(MODEM_SIDE) then
  pcall(rednet.open, MODEM_SIDE)
end

print("=== STORAGE DEBUG SCAN ===")
print("")

-- Make sure output directory exists
if not fs.exists("/storage/data") then
  fs.makeDir("/storage/data")
end

-- Collect all obsidian chests
local names  = peripheral.getNames()
local chests = {}

for _, name in ipairs(names) do
  if name:find("iron_chest_obsidian") or
     name:find("ironchest_obsidian")  then
    local num = tonumber(name:match("_(%d+)$"))
    if num then
      table.insert(chests, {name=name, num=num})
    end
  end
end

if #chests == 0 then
  print("No obsidian chests found!")
  print("Check modem connections and cables.")
  return
end

table.sort(chests, function(a,b) return a.num < b.num end)
print("Found " .. #chests .. " chests")
print("Scanning...")
print("")

-- Open output file
local f = fs.open(OUT_FILE, "w")
f.writeLine("# MC-TWEAKED Debug Dump")
f.writeLine("# chest_name | slot | item_id | damage | display_name | count")
f.writeLine("")

local total_items  = 0
local total_stacks = 0
local chest_count  = 0
local empty_count  = 0

for _, c in ipairs(chests) do
  local chest = peripheral.wrap(c.name)
  if not chest then
    f.writeLine("# OFFLINE: " .. c.name)
    print("OFFLINE: " .. c.name)
  else
    local ok_list, items = pcall(chest.list)
    if not ok_list or not items then
      f.writeLine("# ERROR reading: " .. c.name)
      print("ERROR: " .. c.name)
    else
      local chest_stacks = 0
      for slot, stack in pairs(items) do
        local ok_meta, meta = pcall(chest.getItemMeta, slot)
        local display = stack.name
        local damage  = 0
        if ok_meta and meta then
          display = meta.displayName or meta.name
          damage  = meta.damage or 0
        end
        f.writeLine(
          c.name      .. " | " ..
          tostring(slot)    .. " | " ..
          stack.name        .. " | " ..
          tostring(damage)  .. " | " ..
          display           .. " | " ..
          tostring(stack.count)
        )
        chest_stacks  = chest_stacks + 1
        total_items   = total_items  + stack.count
        total_stacks  = total_stacks + 1
      end
      if chest_stacks > 0 then
        chest_count = chest_count + 1
      else
        empty_count = empty_count + 1
        f.writeLine(c.name .. " | (empty)")
      end
    end
  end
end

f.writeLine("")
f.writeLine("# SUMMARY")
f.writeLine("# Chests scanned: " .. #chests)
f.writeLine("# Chests with items: " .. chest_count)
f.writeLine("# Empty chests: " .. empty_count)
f.writeLine("# Total stacks: " .. total_stacks)
f.writeLine("# Total items: " .. total_items)
f.close()

print("=== DONE ===")
print("Chests scanned:    " .. #chests)
print("Chests with items: " .. chest_count)
print("Empty chests:      " .. empty_count)
print("Total stacks:      " .. total_stacks)
print("Total items:       " .. total_items)
print("")
print("Output: " .. OUT_FILE)
