-- column_edit.lua
-- Visual column editor for storage system
-- Use when a modem gets replaced and a chest
-- gets a new peripheral number
-- Edits columns.cfg directly without rescanning
--
-- Usage: column_edit

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

local function err(msg)
  term.setTextColor(colors.red)
  print("[ERR] " .. msg)
  term.setTextColor(colors.white)
end

local function warn(msg)
  term.setTextColor(colors.yellow)
  print("[WARN] " .. msg)
  term.setTextColor(colors.white)
end

-- ============================================================
-- LOAD / SAVE COLUMNS
-- ============================================================
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
    return nil, "No columns found"
  end
  return columns, nil
end

local function saveColumns(columns)
  local f = fs.open("/data/columns.cfg", "w")
  f.writeLine("# Column assignments")
  f.writeLine("# Format: bottom | mid | top")
  f.writeLine("# Edited by column_edit.lua")
  f.writeLine("")
  for _, col in ipairs(columns) do
    f.writeLine(col.bottom .. " | " .. col.mid .. " | " .. col.top)
  end
  f.close()
end

-- Also update storage.cfg if the chest name changed
local function updateStorageCfg(old_name, new_name)
  if not fs.exists("/data/storage.cfg") then return 0 end
  local lines = {}
  local count = 0
  local f = fs.open("/data/storage.cfg", "r")
  local line = f.readLine()
  while line do
    if line:find(old_name, 1, true) then
      line = line:gsub(old_name:gsub("%-","%%-")
                                :gsub("_","%_")
                                :gsub(":","%%:"),
                       new_name)
      count = count + 1
    end
    table.insert(lines, line)
    line = f.readLine()
  end
  f.close()
  local g = fs.open("/data/storage.cfg", "w")
  for _, l in ipairs(lines) do g.writeLine(l) end
  g.close()
  return count
end

-- ============================================================
-- GET CHEST NUMBER for display
-- ============================================================
local function chestNum(name)
  return name:match("_(%d+)$") or "?"
end

local function isOnline(name)
  return peripheral.wrap(name) ~= nil
end

-- ============================================================
-- ASCII CHEST VISUALIZATION
-- Draws one chest box with number in center
-- ============================================================
local function drawChest(name, label, online)
  local num    = chestNum(name)
  local status = online and "" or " OFFLINE"
  local W_BOX  = 21

  -- Center the number in the box
  local num_str    = tostring(num)
  local label_str  = label .. status
  local pad_num    = math.floor((W_BOX - 2 - #num_str) / 2)
  local pad_label  = math.floor((W_BOX - 2 - #label_str) / 2)

  local color = online and colors.white or colors.red
  term.setTextColor(color)

  print("|" .. string.rep("-", W_BOX - 2) .. "|")
  print("|" .. string.rep(" ", W_BOX - 2) .. "|")
  print("|" ..
        string.rep("-", math.floor((W_BOX-2-3)/2)) ..
        "[O]" ..
        string.rep("-", math.ceil((W_BOX-2-3)/2)) ..
        "|")
  print("|" .. string.rep(" ", W_BOX - 2) .. "|")

  -- Number line
  local left  = string.rep(" ", pad_num)
  local right = string.rep(" ", W_BOX - 2 - pad_num - #num_str)
  print("|" .. left .. num_str .. right .. "|")

  print("|" .. string.rep(" ", W_BOX - 2) .. "|")
  print("|" .. string.rep("-", W_BOX - 2) .. "|")

  -- Label below box
  local lleft = string.rep(" ", pad_label)
  print(" " .. lleft .. label_str)

  term.setTextColor(colors.white)
end

-- ============================================================
-- DRAW FULL COLUMN
-- ============================================================
local function drawColumn(col_idx, col)
  print("")
  term.setTextColor(colors.yellow)
  print("  COLUMN " .. col_idx)
  term.setTextColor(colors.white)
  print("")
  drawChest(col.top,    "TOP",    isOnline(col.top))
  print("           |")
  print("           |")
  drawChest(col.mid,    "MID",    isOnline(col.mid))
  print("           |")
  print("           |")
  drawChest(col.bottom, "BOTTOM", isOnline(col.bottom))
  print("")
end

-- ============================================================
-- DRAW ALL COLUMNS (summary, no full art)
-- ============================================================
local function drawAllColumns(columns)
  print("")
  print(string.format("  %-6s %-8s %-8s %-8s %-8s",
    "COL", "BOTTOM", "MID", "TOP", "STATUS"))
  print("  " .. string.rep("-", 45))
  for i, col in ipairs(columns) do
    local bot_ok = isOnline(col.bottom)
    local mid_ok = isOnline(col.mid)
    local top_ok = isOnline(col.top)
    local status = "OK"
    local color  = colors.white
    if not bot_ok or not mid_ok or not top_ok then
      status = "OFFLINE"
      color  = colors.red
    end
    term.setTextColor(color)
    print(string.format("  %-6d %-8s %-8s %-8s %-8s",
      i,
      chestNum(col.bottom),
      chestNum(col.mid),
      chestNum(col.top),
      status))
    term.setTextColor(colors.white)
  end
  print("")
end

-- ============================================================
-- GET ALL AVAILABLE OBSIDIAN CHESTS ON NETWORK
-- ============================================================
local function getAvailableChests(columns)
  local all = {}
  for _, name in ipairs(peripheral.getNames()) do
    if name:find("ironchest_obsidian") then
      local num = tonumber(name:match("_(%d+)$"))
      if num then table.insert(all, {name=name, num=num}) end
    end
  end
  table.sort(all, function(a,b) return a.num < b.num end)

  -- Mark which are already assigned
  local assigned = {}
  for _, col in ipairs(columns) do
    assigned[col.bottom] = true
    assigned[col.mid]    = true
    assigned[col.top]    = true
  end

  return all, assigned
end

-- ============================================================
-- PRINT COLUMN TO PRINTER
-- ============================================================
local function printColumn(col_idx, col)
  local has_printer = printer.open("Col " .. col_idx)
  if not has_printer then return end

  local W_BOX = 21

  local function box(name, label)
    local num     = chestNum(name)
    local online  = isOnline(name)
    local tag     = online and "" or " OFFLINE"
    local pad     = math.floor((W_BOX - 2 - #num) / 2)

    printer.writeLine("|" .. string.rep("-", W_BOX-2) .. "|")
    printer.writeLine("|" .. string.rep(" ", W_BOX-2) .. "|")
    printer.writeLine("|" ..
      string.rep("-", math.floor((W_BOX-2-3)/2)) ..
      "[O]" ..
      string.rep("-", math.ceil((W_BOX-2-3)/2)) ..
      "|")
    printer.writeLine("|" .. string.rep(" ", W_BOX-2) .. "|")
    local left  = string.rep(" ", pad)
    local right = string.rep(" ", W_BOX-2-pad-#num)
    printer.writeLine("|" .. left .. num .. right .. "|")
    printer.writeLine("|" .. string.rep(" ", W_BOX-2) .. "|")
    printer.writeLine("|" .. string.rep("-", W_BOX-2) .. "|")
    printer.writeLine("  " .. label .. tag)
  end

  printer.writeLine("COLUMN " .. col_idx)
  printer.writeLine(string.rep("-", 25))
  printer.writeLine("")
  box(col.top,    "TOP")
  printer.writeLine("          |")
  printer.writeLine("          |")
  box(col.mid,    "MID")
  printer.writeLine("          |")
  printer.writeLine("          |")
  box(col.bottom, "BOTTOM")

  printer.close()
end

-- ============================================================
-- MAIN
-- ============================================================
header("COLUMN EDITOR")
print("")

local columns, err_msg = loadColumns()
if not columns then
  err(err_msg)
  return
end

print("Loaded " .. #columns .. " columns")

while true do
  -- Show summary
  drawAllColumns(columns)

  print("Options:")
  print("  [1-" .. #columns .. "] Edit a column")
  print("  [p] Print a column")
  print("  [q] Quit")
  print("")
  io.write("Choice: ")
  local input = io.read()

  if input:lower() == "q" then
    print("Done.")
    break

  elseif input:lower() == "p" then
    io.write("Print column number: ")
    local num = tonumber(io.read())
    if num and columns[num] then
      printColumn(num, columns[num])
    else
      err("Invalid column number")
    end

  else
    local col_idx = tonumber(input)
    if not col_idx or not columns[col_idx] then
      err("Invalid choice")
    else
      local col = columns[col_idx]

      -- Draw the column
      drawColumn(col_idx, col)

      -- Show available chests
      local available, assigned = getAvailableChests(columns)
      print("Available chests on network:")
      print(string.format("  %-8s %-40s %s",
        "NUM", "NAME", "STATUS"))
      print("  " .. string.rep("-", 55))
      for _, c in ipairs(available) do
        local a_tag = assigned[c.name] and " (assigned)" or ""
        local o_tag = isOnline(c.name) and "online" or "OFFLINE"
        local color = assigned[c.name] and colors.lightGray
                      or colors.white
        if not isOnline(c.name) then color = colors.red end
        term.setTextColor(color)
        print(string.format("  %-8d %-40s %s%s",
          c.num, c.name:sub(1,39), o_tag, a_tag))
        term.setTextColor(colors.white)
      end
      print("")

      -- Choose position to edit
      print("Which position to change?")
      print("  [1] Bottom  (currently " ..
            chestNum(col.bottom) .. ")")
      print("  [2] Mid     (currently " ..
            chestNum(col.mid) .. ")")
      print("  [3] Top     (currently " ..
            chestNum(col.top) .. ")")
      print("  [0] Cancel")
      print("")
      io.write("Position: ")
      local pos = tonumber(io.read())

      if not pos or pos == 0 then
        warn("Cancelled")

      elseif pos < 1 or pos > 3 then
        err("Invalid position")

      else
        local pos_name = ({[1]="bottom",[2]="mid",[3]="top"})[pos]
        local old_name = col[pos_name]

        io.write("New chest number: ")
        local new_num = tonumber(io.read())
        if not new_num then
          err("Invalid number")
        else
          -- Find the chest with that number
          local new_name = nil
          for _, c in ipairs(available) do
            if c.num == new_num then
              new_name = c.name
              break
            end
          end

          if not new_name then
            err("Chest " .. new_num .. " not found on network")
          elseif new_name == old_name then
            warn("Same chest - no change")
          else
            -- Confirm
            print("")
            print("Change column " .. col_idx ..
                  " " .. pos_name:upper() .. ":")
            print("  FROM: " .. old_name)
            print("  TO:   " .. new_name)
            print("")
            io.write("Confirm? (yes/no): ")
            local confirm = io.read():lower()

            if confirm == "yes" or confirm == "y" then
              -- Update columns
              columns[col_idx][pos_name] = new_name

              -- Update storage.cfg
              local updated = updateStorageCfg(old_name, new_name)

              -- Save
              saveColumns(columns)
              ok("Column updated")
              if updated > 0 then
                ok("storage.cfg updated (" ..
                   updated .. " entries)")
              end

              -- Redraw updated column
              drawColumn(col_idx, columns[col_idx])
            else
              warn("Cancelled")
            end
          end
        end
      end
    end
  end
end
