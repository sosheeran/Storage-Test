-- debug_storage.lua
-- Scans every obsidian chest on the network
-- Prints all found items to printer on the left side
--
-- Usage: debug_storage

local MODEM        = "back"
local PRINTER_SIDE = "left"

if not rednet.isOpen(MODEM) then
  pcall(rednet.open, MODEM)
end

-- Check printer
local printer = peripheral.wrap(PRINTER_SIDE)
if not printer then
  print("No printer found on left side!")
  print("Place a CC printer to the left of this computer.")
  return
end

-- Check ink and paper
local ink   = printer.getInkLevel()
local paper = printer.getPaperLevel()
print("Printer found")
print("Ink:   " .. ink)
print("Paper: " .. paper)

if ink == 0 then
  print("ERROR: No ink in printer!")
  return
end
if paper == 0 then
  print("ERROR: No paper in printer!")
  return
end

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

-- Collect unique items (one entry per item type)
-- We only care about bottom chests for identification
local items_found = {}
local seen_keys   = {}

local i = 1
while i <= #chests do
  local bot = chests[i]
  local mid = chests[i+1]
  local top = chests[i+2]

  if mid and top and
     mid.num == bot.num+1 and
     top.num == bot.num+2 then

    local chest = peripheral.wrap(bot.name)
    if chest then
      local ok_list, items = pcall(chest.list)
      if ok_list and items then
        for slot, stack in pairs(items) do
          local ok_meta, meta = pcall(chest.getItemMeta, slot)
          local key     = stack.name
          local display = stack.name
          local damage  = 0
          if ok_meta and meta then
            damage  = meta.damage or 0
            display = meta.displayName or meta.name
            if damage > 0 then key = key .. ":" .. damage end
          end

          if not seen_keys[key] then
            seen_keys[key] = true
            table.insert(items_found, {
              key     = key,
              display = display,
              mod     = stack.name:match("^(.-):")  or "minecraft",
              chest   = bot.name,
            })
          end
          break -- only need first item per chest
        end
      end
    end
    i = i + 3
  else
    i = i + 1
  end
end

-- Sort by mod then display name
table.sort(items_found, function(a,b)
  if a.mod ~= b.mod then return a.mod < b.mod end
  return a.display < b.display
end)

print("Found " .. #items_found .. " unique items")
print("Printing...")

-- Print pages
-- CC printer page is 25 chars wide, 21 lines tall
local PAGE_WIDTH = 25
local PAGE_LINES = 21
local TITLE      = "STORAGE CONTENTS"

local function printPage(lines, page_num, total_pages)
  if not printer.newPage() then
    print("Out of paper!")
    return false
  end

  printer.setPageTitle("Storage p." .. page_num .. "/" .. total_pages)

  -- Header
  printer.setCursorPos(1, 1)
  printer.write(TITLE)
  printer.setCursorPos(1, 2)
  printer.write(string.rep("-", PAGE_WIDTH))

  -- Content lines
  for line_num, line in ipairs(lines) do
    printer.setCursorPos(1, line_num + 2)
    printer.write(line:sub(1, PAGE_WIDTH))
  end

  printer.endPage()
  return true
end

-- Build all lines
local all_lines = {}
local current_mod = nil

for _, item in ipairs(items_found) do
  -- Mod header when mod changes
  if item.mod ~= current_mod then
    if current_mod then
      table.insert(all_lines, "")
    end
    table.insert(all_lines, "[" .. item.mod:upper():sub(1,23) .. "]")
    current_mod = item.mod
  end
  -- Item line - truncate display name to fit
  table.insert(all_lines, "  " .. item.display:sub(1, PAGE_WIDTH - 2))
end

-- Footer line
table.insert(all_lines, "")
table.insert(all_lines, string.rep("-", PAGE_WIDTH))
table.insert(all_lines, "Total: " .. #items_found .. " items")

-- Split into pages (leaving 2 lines for header per page)
local LINES_PER_PAGE = PAGE_LINES - 2
local pages = {}
local current_page = {}

for _, line in ipairs(all_lines) do
  if #current_page >= LINES_PER_PAGE then
    table.insert(pages, current_page)
    current_page = {}
  end
  table.insert(current_page, line)
end
if #current_page > 0 then
  table.insert(pages, current_page)
end

if #pages == 0 then
  print("Nothing to print!")
  return
end

-- Check we have enough paper
if paper < #pages then
  print("WARNING: Need " .. #pages .. " pages but only " ..
        paper .. " paper available")
  print("Will print what it can")
end

-- Print all pages
local printed = 0
for p, page_lines in ipairs(pages) do
  if printPage(page_lines, p, #pages) then
    printed = printed + 1
    print("Printed page " .. p .. "/" .. #pages)
  else
    print("Stopped at page " .. p .. " - out of paper or ink")
    break
  end
end

print("")
print("Done - " .. printed .. " page(s) printed")
print(#items_found .. " unique items listed")
