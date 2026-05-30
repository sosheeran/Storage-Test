-- storage_log.lua
-- Displays current stock levels for all items in storage.cfg
-- Shows count, percentage, and overflow warnings
--
-- Usage:
--   storage_log          (show all items)
--   storage_log iron     (filter by name/mod/key)
--   storage_log --low    (show only low stock items)
--   storage_log --high   (show only high/overflow items)

local storage = require("/scripts/lib/storage")

-- ============================================================
-- ARGS
-- ============================================================
local args    = {...}
local filter  = nil
local low_only  = false
local high_only = false

for _, arg in ipairs(args) do
  if arg == "--low"  then low_only  = true
  elseif arg == "--high" then high_only = true
  else filter = arg:lower()
  end
end

-- ============================================================
-- THRESHOLDS
-- ============================================================
local LOW_PCT  = 10
local HIGH_PCT = 85

-- ============================================================
-- DISPLAY
-- ============================================================
local W = term.getSize()

local function statusColor(pct, overflow)
  if overflow        then return colors.red     end
  if pct >= HIGH_PCT then return colors.orange  end
  if pct <= LOW_PCT  then return colors.yellow  end
  return colors.white
end

local function statusTag(pct, overflow)
  if overflow        then return "[OVERFLOW]" end
  if pct >= HIGH_PCT then return "[HIGH]    " end
  if pct <= LOW_PCT  then return "[LOW]     " end
  return "[OK]      "
end

local function stockBar(pct, width)
  width = width or 15
  pct   = math.max(0, math.min(100, pct))
  local filled = math.floor(pct / 100 * width)
  return string.rep("#", filled) ..
         string.rep("-", width - filled)
end

-- ============================================================
-- MAIN
-- ============================================================
local store = storage.load()

if not next(store) then
  term.setTextColor(colors.red)
  print("storage.cfg is empty or not found")
  print("Run: discover")
  term.setTextColor(colors.white)
  return
end

-- Build and sort results
local results = {}
for key, data in pairs(store) do
  -- Apply filter
  if not filter or
     data.display:lower():find(filter, 1, true) or
     key:lower():find(filter, 1, true) or
     data.mod:lower():find(filter, 1, true) then

    local total, pct, overflow = storage.getStock(data)

    -- Apply low/high filter
    local show = true
    if low_only  and pct > LOW_PCT and not overflow  then show = false end
    if high_only and pct < HIGH_PCT and not overflow then show = false end

    if show then
      table.insert(results, {
        key      = key,
        display  = data.display,
        mod      = data.mod,
        total    = total,
        pct      = pct,
        overflow = overflow,
      })
    end
  end
end

-- Sort by mod then display name
table.sort(results, function(a, b)
  if a.mod ~= b.mod then return a.mod < b.mod end
  return a.display < b.display
end)

-- Print header
print(string.rep("=", W))
local title = "STORAGE LOG"
if filter   then title = title .. " [" .. filter .. "]" end
if low_only  then title = title .. " [LOW]"  end
if high_only then title = title .. " [HIGH]" end
local pad = math.floor((W - #title) / 2)
print(string.rep(" ", pad) .. title)
print(string.rep("=", W))
print(string.format("%-28s %-8s %s %s",
  "ITEM", "MOD", "BAR             ", "COUNT / STATUS"))
print(string.rep("-", W))

local shown = 0
for _, r in ipairs(results) do
  local color = statusColor(r.pct, r.overflow)
  local tag   = statusTag(r.pct, r.overflow)
  local bar   = stockBar(r.pct, 15)

  term.setTextColor(color)
  print(string.format("%-28s %-8s [%s] %6d %s %d%%",
    r.display:sub(1, 27),
    r.mod:sub(1, 7),
    bar,
    r.total,
    tag,
    r.pct))
  term.setTextColor(colors.white)
  shown = shown + 1
end

print(string.rep("-", W))
print(string.format("Showing %d of %d items", shown, #results))

-- Summary counts
local low_count  = 0
local high_count = 0
local overflow_count = 0
for _, r in ipairs(results) do
  if r.overflow        then overflow_count = overflow_count + 1
  elseif r.pct >= HIGH_PCT then high_count = high_count + 1
  elseif r.pct <= LOW_PCT  then low_count  = low_count  + 1
  end
end

if overflow_count > 0 then
  term.setTextColor(colors.red)
  print("OVERFLOW: " .. overflow_count .. " items")
  term.setTextColor(colors.white)
end
if high_count > 0 then
  term.setTextColor(colors.orange)
  print("HIGH:     " .. high_count .. " items")
  term.setTextColor(colors.white)
end
if low_count > 0 then
  term.setTextColor(colors.yellow)
  print("LOW:      " .. low_count .. " items")
  term.setTextColor(colors.white)
end
