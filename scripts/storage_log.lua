-- storage_log.lua
-- Shows current stock levels for all items in storage.cfg
--
-- Usage:
--   storage_log              show all
--   storage_log iron         filter by name/mod/key
--   storage_log --low        show only low stock
--   storage_log --high       show only high/overflow

local storage = require("/scripts/lib/storage")

local args      = {...}
local filter    = nil
local low_only  = false
local high_only = false

for _, a in ipairs(args) do
  if a == "--low"  then low_only  = true
  elseif a == "--high" then high_only = true
  else filter = a:lower() end
end

local LOW  = 10
local HIGH = 85
local W    = term.getSize()

local function bar(pct, w)
  w   = w or 15
  pct = math.max(0, math.min(100, pct))
  local f = math.floor(pct/100*w)
  return string.rep("#",f) .. string.rep("-",w-f)
end

local store = storage.load()
if not next(store) then
  print("storage.cfg is empty - run: discover")
  return
end

local results = {}
for key, data in pairs(store) do
  if not filter or
     data.display:lower():find(filter,1,true) or
     key:lower():find(filter,1,true) or
     data.mod:lower():find(filter,1,true) then

    local total, pct, overflow = storage.getStock(data)
    local show = true
    if low_only  and pct > LOW  and not overflow then show = false end
    if high_only and pct < HIGH and not overflow then show = false end
    if show then
      table.insert(results, {
        display=data.display, mod=data.mod,
        total=total, pct=pct, overflow=overflow
      })
    end
  end
end

table.sort(results, function(a,b)
  if a.mod ~= b.mod then return a.mod < b.mod end
  return a.display < b.display
end)

print(string.rep("=", W))
print("  STORAGE LOG" .. (filter and (" [" .. filter .. "]") or ""))
print(string.rep("=", W))

local low_n, high_n, overflow_n = 0, 0, 0
for _, r in ipairs(results) do
  local color = colors.white
  local tag   = "      "
  if r.overflow        then color=colors.red;    tag="OFLOW "; overflow_n=overflow_n+1
  elseif r.pct>=HIGH   then color=colors.orange; tag="HIGH  "; high_n=high_n+1
  elseif r.pct<=LOW    then color=colors.yellow; tag="LOW   "; low_n=low_n+1
  end
  term.setTextColor(color)
  print(string.format("%-26s %-8s [%s] %6d  %s%d%%",
    r.display:sub(1,25), r.mod:sub(1,7),
    bar(r.pct,15), r.total, tag, r.pct))
  term.setTextColor(colors.white)
end

print(string.rep("-", W))
print(string.format("Items: %d  |  Low: %d  High: %d  Overflow: %d",
  #results, low_n, high_n, overflow_n))
