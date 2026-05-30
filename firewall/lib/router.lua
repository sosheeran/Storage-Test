-- firewall/lib/router.lua
-- Routes packets to correct internal servers
-- Translates service_request into backend-specific format
-- Injects validated_role from session (never trust client-supplied role)

local services = require("/fw/lib/services")
local M        = {}

-- These go straight to auth - auth validates its own sessions internally
local AUTH_DIRECT = {
  login=true, logout=true,
  change_password=true,
  user_create=true, user_delete=true, user_list=true,
  card_verify=true, card_issue=true,
}

-- Translate service_request into the format the backend server expects
local function translate(msg)
  local service = msg.service
  local action  = msg.action
  local data    = msg.data or {}
  -- CRITICAL: role comes from validated session, never from client
  local role    = msg.validated_role or "guest"

  if service == "storage" then
    if action == "query" then
      return {
        type      = "storage_query",
        query     = data.query,
        item_key  = data.item_key,
        amount    = data.amount or 1,
        id        = msg.id,
        sender_id = msg.sender_id,
      }
    elseif action == "pull" then
      return {
        type      = "storage_pull",
        order     = data.order,
        job_id    = data.job_id,
        role      = role,       -- validated, not client-supplied
        id        = msg.id,
        sender_id = msg.sender_id,
      }
    end
  end

  -- Passthrough for unknown service/action
  return msg
end

-- Route packet - returns target_id, translated_msg, error
function M.route(msg)
  local t = msg.type

  -- Auth-direct: straight to auth server, no pre-validation
  if AUTH_DIRECT[t] then
    local id = services.getID("auth")
    if not id then return nil, msg, "Auth server not configured" end
    return id, msg, nil
  end

  -- Service request: validate session first (done in firewall.lua),
  -- then translate and route
  if t == "service_request" then
    local id = services.getID(msg.service)
    if not id then
      return nil, msg, "Unknown service: " .. tostring(msg.service)
    end
    return id, translate(msg), nil
  end

  return nil, msg, "No route for type: " .. tostring(t)
end

return M
