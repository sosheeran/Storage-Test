-- lib/printer.lua
-- Shared printer utility
-- All scripts use this to print output to left-side printer

local M = {}
local SIDE      = "left"
local PW        = 25   -- page width chars
local PH        = 21   -- page height lines
local printer   = nil
local page_lines = {}
local page_num   = 0
local total_pages= 0   -- unknown until done, set to 0

-- Connect to printer
function M.open(title)
  printer = peripheral.wrap(SIDE)
  if not printer then
    print("No printer on left side!")
    return false
  end
  local ink   = printer.getInkLevel()
  local paper = printer.getPaperLevel()
  print("Printer: ink=" .. ink .. " paper=" .. paper)
  if ink == 0   then print("ERROR: No ink!")   return false end
  if paper == 0 then print("ERROR: No paper!") return false end
  M.title    = title or "Output"
  page_lines = {}
  page_num   = 0
  return true
end

-- Flush current page to printer
local function flush()
  if #page_lines == 0 then return true end
  if not printer.newPage() then
    print("Out of paper!")
    return false
  end
  page_num = page_num + 1
  printer.setPageTitle(M.title .. " p." .. page_num)
  for i, line in ipairs(page_lines) do
    printer.setCursorPos(1, i)
    printer.write(line:sub(1, PW))
  end
  printer.endPage()
  page_lines = {}
  return true
end

-- Write a line - auto paginates
function M.writeLine(line)
  line = line or ""
  -- Print to terminal too
  print(line)
  table.insert(page_lines, line)
  if #page_lines >= PH then
    return flush()
  end
  return true
end

-- Write separator line
function M.separator()
  return M.writeLine(string.rep("-", PW))
end

-- Finish and flush last page
function M.close()
  local ok = flush()
  if ok then
    print("Printed " .. page_num .. " page(s)")
  end
  return ok
end

function M.getPageCount() return page_num end

return M
