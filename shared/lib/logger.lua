-- shared/lib/logger.lua
-- Sends log entries to log-server (ID 0)
-- Fire and forget - no ack expected
-- Every server and client uses this

local M = {}

local LOG_SERVER = 0
local MODEM_SIDE = "bottom"  -- wired network modem

local function send(category, level, source, message)
  if not rednet.isOpen(MODEM_SIDE) then
    pcall(rednet.open, MODEM_SIDE)
  end
  -- Fire and forget - no waiting for response
  -- Avoids polluting rednet.receive() on callers
  pcall(rednet.send, LOG_SERVER, textutils.serialize({
    type     = "log",
    category = category,
    level    = level,
    source   = source,
    message  = tostring(message),
    ts       = os.time(),
  }))
end

function M.info(source, msg)     send("audit",    "INFO", source, msg) end
function M.warn(source, msg)     send("audit",    "WARN", source, msg) end
function M.error(source, msg)    send("errors",   "ERROR", source, msg) end
function M.security(source, msg) send("security", "SEC",  source, msg) end
function M.audit(source, msg)    send("audit",    "AUDIT", source, msg) end
function M.network(source, msg)  send("network",  "NET",  source, msg) end

return M
