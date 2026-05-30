-- discover.lua
-- Scans all obsidian chests on the back modem
-- Groups them into columns of 3 (bottom/mid/top)
-- Reads first item in each bottom chest to identify contents
-- Writes results to /storage/data/storage.cfg
--
-- Usage: discover
-- Run on the storage server computer

local storage = require("/scripts/lib/storage")

-- ============================================================
-- CONFIG
-- ============================================================
local CHEST_TYPE = "ironchest:iron_chest_obsidian"
local MODEM_SIDE = "back"

-- ============================================================
-- HELPERS
-- ============================================================
local function log(msg)
  print(msg)
end

local function warn(msg)
  term.setTextColor(colors.yellow)
  print("[WARN] " .. msg)
  term.setTextColor(colors.white)
end

local function err(msg)
  term.setTextColor(colors.red)
  print("[ERROR] " .. msg)
  term.setTextColor(colors.white)
end

local function ok(msg)
  term.setTextColor(colors.green)
  print("[OK] " .. msg)
  term.setTextColor(colors.white)
end

-- Get numeric suffix from peripheral name
-- e.g. "ironchest:iron_chest_obsidian_42" → 42
local function getNum(name)
  return tonumber(name:match("_(%d+)$"))
end

-- ============================================================
-- SCAN
-- ============================================================
local function scan()
  -- Open modem if needed
  if not rednet.isOpen(MODEM_SIDE) then
    pcall(rednet.open, MODEM_SIDE)
  end

  log("=== MC-TWEAKED DISCOVERY SCAN ===")
  log("")

  -- Collect all obsidian chests
  local all = peripheral.getNames()
  local chests = {}

  for _, name in ipairs(all) do
    if name:find("iron_chest_obsidian") or
       name:find("ironchest_obsidian") then
      local num = getNum(name)
      if num then
        table.insert(chests, {name=name, num=num})
      end
    end
  end

  if #chests == 0 then
    err("No obsidian chests found!")
    err("Make sure:")
    err("  1. Wired modems are attached to chests")
    err("  2. Modems are connected with networking cable")
    err("  3. This computer is on the same cable network")
    err("  4. The back modem on this computer is open")
    return false
  end

  log("Found " .. #chests .. " obsidian chests")

  -- Sort by number
  table.sort(chests, function(a, b) return a.num < b.num end)

  -- Warn if not divisible by 3
  if #chests % 3 ~= 0 then
    warn("Chest count (" .. #chests .. ") not divisible by 3")
    warn("Some columns may be incomplete")
  end

  log("")

  -- Load existing storage.cfg to preserve entries
  local store   = storage.load()
  local found   = 0
  local skipped = 0
  local empty   = 0
  local errors  = 0

  -- Process in groups of 3
  local i = 1
  while i <= #chests do
    local bottom = chests[i]
    local mid    = chests[i+1]
    local top    = chests[i+2]

    -- Check we have a complete group
    if not mid or not top then
      warn("Incomplete group at " .. bottom.name ..
           " (missing mid/top chests)")
      errors = errors + 1
      i = i + 1

    -- Check chests are consecutive
    elseif mid.num ~= bottom.num + 1 or
           top.num ~= bottom.num + 2 then
      warn("Non-consecutive group: " ..
           bottom.num .. ", " ..
           mid.num    .. ", " ..
           top.num)
      warn("Expected consecutive numbering")
      errors = errors + 1
      i = i + 1

    else
      -- Valid group - identify contents from bottom chest
      local chest = peripheral.wrap(bottom.name)
      local meta  = nil

      if not chest then
        warn("Cannot wrap: " .. bottom.name)
        errors = errors + 1
        i = i + 3
      else
        -- Find first item in chest
        local ok_list, items = pcall(chest.list)
        if ok_list and items then
          for slot, stack in pairs(items) do
            local ok_meta, m = pcall(chest.getItemMeta, slot)
            if ok_meta and m then
              meta = m
              break
            end
          end
        end

        if meta then
          -- Build item key
          local key     = storage.makeKey(meta.name, meta.damage or 0)
          local display = meta.displayName or meta.name
          local mod     = meta.name:match("^(.-):")  or "unknown"

          if store[key] then
            -- Already mapped
            skipped = skipped + 1
            log("SKIP: " .. display ..
                " (already mapped to " .. store[key].chest .. ")")
          else
            -- New entry
            store[key] = {
              chest   = bottom.name,
              mid     = mid.name,
              top     = top.name,
              display = display,
              mod     = mod,
            }
            found = found + 1
            ok("Found: [" .. mod .. "] " .. display)
            log("       bottom=" .. bottom.name ..
                " mid=" .. mid.name ..
                " top=" .. top.name)
          end
        else
          -- Empty chest
          empty = empty + 1
          log("EMPTY: " .. bottom.name ..
              " (mid=" .. mid.name ..
              " top=" .. top.name .. ")")
        end

        i = i + 3
      end
    end
  end

  -- Save results
  log("")
  log("=== RESULTS ===")
  log("New entries: " .. found)
  log("Skipped:     " .. skipped)
  log("Empty:       " .. empty)
  if errors > 0 then
    warn("Errors:      " .. errors)
  end

  if found > 0 or (found == 0 and skipped == 0) then
    local saved = storage.save(store)
    if saved then
      log("")
      ok("Saved " .. (found + skipped) ..
         " entries to storage.cfg")
    else
      err("Failed to save storage.cfg!")
      return false
    end
  else
    log("")
    log("No changes to save")
  end

  return true
end

-- ============================================================
-- RUN
-- ============================================================
local ok_result, err_msg = pcall(scan)
if not ok_result then
  term.setTextColor(colors.red)
  print("[CRASH] " .. tostring(err_msg))
  term.setTextColor(colors.white)
end
