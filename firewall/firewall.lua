-- firewall/firewall.lua
-- MC-TWEAKED Gateway / Firewall
-- Computer ID: 2
--
-- Physical:
--   back   = wireless ender modem  (clients connect here)
--   bottom = wired modem           (internal network)
--
-- Flow:
--   Client → wireless → firewall → wired → internal server
--
-- Auth packets (login/logout/change_password/user_*):
--   → forward directly to auth, no pre-validation
--   → auth handles its own session validation
--
-- Service requests (storage queries/pulls):
--   → validate session with auth first
--   → inject validated_role into packet
--   → translate and forward to correct server
--
-- Internal servers talk to each other directly on the wired network
-- They do NOT route through the firewall

local router    = require("/fw/lib/router")
local validator = require("/fw/lib/validator")
local ratelimit = require("/fw/lib/ratelimit")
local services  = require("/fw/lib/services")
local logger    = require("/lib/logger")

local WIRELESS = "back"
local WIRED    = "bottom"
local AUTH_ID  = 1
local TIMEOUT  = 8

rednet.open(WIRELESS)
rednet.open(WIRED)

print("[FW] Computer ID: " .. os.getComputerID())
print("[FW] Wireless (clients): " .. WIRELESS)
print("[FW] Wired (servers):    " .. WIRED)
print("[FW] Ready")
logger.audit("firewall", "Firewall started - ID " .. os.getComputerID())

-- ============================================================
-- BLOCKLIST
-- ============================================================
local function isBlocked(id)
  local f = fs.open("/fw/data/blocklist.cfg", "r")
  if not f then return false end
  local line = f.readLine()
  while line do
    if tonumber(line:match("^%s*(.-)%s*$")) == id then
      f.close(); return true
    end
    line = f.readLine()
  end
  f.close()
  return false
end

-- ============================================================
-- FORWARD
-- Sends packet to internal server and waits for matching response
-- Uses reply_id to filter out noise packets from other servers
-- (e.g. log_ack from log-server arriving while waiting for auth)
-- ============================================================
local function forward(target_id, msg)
  -- Generate unique reply correlation ID
  local reply_id = tostring(os.clock()) ..
                   tostring(math.random(1, 999999))
  msg._reply_id  = reply_id

  rednet.send(target_id, textutils.serialize(msg))

  local deadline = os.clock() + TIMEOUT
  while os.clock() < deadline do
    local remaining = deadline - os.clock()
    if remaining <= 0 then break end

    local sender, raw = rednet.receive(math.min(remaining, 1))

    if sender == target_id and type(raw) == "string" then
      local ok, resp = pcall(textutils.unserialize, raw)
      if ok and type(resp) == "table" then
        if resp._reply_id == reply_id then
          resp._reply_id = nil  -- strip before relaying to client
          return resp, nil
        end
        -- Wrong reply_id = noise packet from another transaction
        -- Discard and keep waiting
      end
    end
  end

  return nil, "Timeout waiting for server ID " .. target_id
end

-- ============================================================
-- SESSION VALIDATION
-- Only used for service_requests
-- Calls auth server to validate token
-- Returns: valid, username, role, error_msg
-- ============================================================
local function validateSession(token, sender_id)
  local req = {
    type       = "validate",
    token      = token,
    computerID = sender_id,
    id         = tostring(os.clock()) .. "v",
  }

  local resp, err = forward(AUTH_ID, req)

  if not resp then
    return false, nil, nil, "Auth unreachable: " .. (err or "timeout")
  end
  if resp.type == "error" then
    return false, nil, nil, resp.reason or "Auth error"
  end
  if resp.type ~= "validate_response" then
    return false, nil, nil, "Unexpected response from auth"
  end
  if not resp.valid then
    return false, nil, nil, resp.reason or "Invalid session"
  end

  return true, resp.username, resp.role, nil
end

-- ============================================================
-- PACKET HANDLER
-- Full processing pipeline for one incoming client packet
-- ============================================================
local function handlePacket(sender_id, raw)
  -- Block check
  if isBlocked(sender_id) then
    print("[FW] BLOCKED: " .. sender_id)
    logger.security("firewall", "Blocked: " .. sender_id)
    return
  end

  -- Rate limit
  if not ratelimit.check(sender_id) then
    print("[FW] RATE LIMIT: " .. sender_id)
    logger.security("firewall", "Rate limited: " .. sender_id)
    rednet.send(sender_id, textutils.serialize({
      type="error", reason="Rate limit exceeded"}))
    return
  end

  -- Parse
  if type(raw) ~= "string" then return end
  local ok, msg = pcall(textutils.unserialize, raw)
  if not ok or type(msg) ~= "table" then
    print("[FW] MALFORMED from " .. sender_id)
    return
  end

  -- Validate structure
  local valid, reason = validator.validate(msg)
  if not valid then
    print("[FW] INVALID from " .. sender_id .. ": " .. reason)
    rednet.send(sender_id, textutils.serialize({
      type="error", reason="Invalid: " .. reason, id=msg.id}))
    return
  end

  -- Tag sender (servers can trust this field)
  msg.sender_id = sender_id

  -- Session validation ONLY for service_requests
  -- Auth-direct packets skip this entirely
  if msg.type == "service_request" then
    local sess_ok, uname, role, sess_err =
      validateSession(msg.token, sender_id)

    if not sess_ok then
      print("[FW] SESSION FAIL from " .. sender_id ..
            ": " .. tostring(sess_err))
      logger.security("firewall",
        "Session fail from " .. sender_id ..
        ": " .. tostring(sess_err))
      rednet.send(sender_id, textutils.serialize({
        type   = "error",
        reason = "Session invalid: " .. tostring(sess_err),
        id     = msg.id,
      }))
      return
    end

    -- Inject validated role - downstream servers MUST use this
    msg.validated_role     = role
    msg.validated_username = uname
    print("[FW] OK " .. msg.service .. "/" .. msg.action ..
          " from " .. uname .. "(" .. role .. ")")
    logger.network("firewall",
      "Service: " .. msg.service .. "/" .. msg.action ..
      " user=" .. uname .. " role=" .. role)
  else
    print("[FW] AUTH: " .. msg.type .. " from " .. sender_id)
    logger.network("firewall",
      "Auth: " .. msg.type .. " from " .. sender_id)
  end

  -- Route
  local target_id, translated, route_err = router.route(msg)
  if not target_id then
    print("[FW] NO ROUTE: " .. tostring(route_err))
    rednet.send(sender_id, textutils.serialize({
      type="error", reason=route_err or "No route", id=msg.id}))
    return
  end

  -- Forward and relay
  local response, fwd_err = forward(target_id, translated)
  if not response then
    print("[FW] FWD FAIL to " .. target_id .. ": " .. tostring(fwd_err))
    rednet.send(sender_id, textutils.serialize({
      type="error", reason=tostring(fwd_err), id=msg.id}))
    return
  end

  rednet.send(sender_id, textutils.serialize(response))
end

-- ============================================================
-- MAIN LOOP
-- Only processes packets from non-trusted (client) IDs
-- Internal servers talk directly to each other
-- ============================================================
while true do
  local sender_id, raw = rednet.receive(1)
  if sender_id and raw then
    if services.isTrusted(sender_id) then
      -- Should not happen - internal servers don't go through firewall
      print("[FW] WARN: trusted ID " .. sender_id ..
            " sent to wireless - ignoring")
    else
      local ok, err = pcall(handlePacket, sender_id, raw)
      if not ok then
        print("[FW] ERROR: " .. tostring(err))
        logger.error("firewall", "Handler crash: " .. tostring(err))
      end
    end
  end
end
