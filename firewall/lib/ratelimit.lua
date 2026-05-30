-- firewall/lib/ratelimit.lua
-- Sliding window rate limiter per computer ID
-- 30 requests per 60 seconds

local M = {}
local windows     = {}
local MAX         = 30
local WINDOW_SECS = 60

function M.check(id)
  local now  = os.clock()
  local w    = windows[id]
  if not w then
    windows[id] = {count=1, start=now}
    return true
  end
  if now - w.start > WINDOW_SECS then
    windows[id] = {count=1, start=now}
    return true
  end
  if w.count >= MAX then return false end
  w.count = w.count + 1
  return true
end

function M.reset(id)
  windows[id] = nil
end

return M
