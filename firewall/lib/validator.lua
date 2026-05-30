-- firewall/lib/validator.lua
-- Validates packet structure - checks required fields exist

local M = {}

local REQUIRED = {
  -- Auth packets (straight to auth, no pre-validation)
  login           = {"username", "password"},
  logout          = {"token"},
  change_password = {"token", "target_username", "new_password"},
  user_create     = {"token", "username", "password", "role"},
  user_delete     = {"token", "target_username"},
  user_list       = {"token"},
  card_verify     = {"hash", "disk_id"},
  -- Service requests (session validated by firewall first)
  service_request = {"token", "service", "action"},
}

function M.validate(msg)
  if type(msg) ~= "table"           then return false, "Not a table"          end
  if type(msg.type) ~= "string"     then return false, "Missing type"         end
  if #msg.type > 64                 then return false, "Type too long"         end

  local req = REQUIRED[msg.type]
  if req then
    for _, field in ipairs(req) do
      if msg[field] == nil then
        return false, "Missing field: " .. field
      end
    end
  end

  return true, nil
end

return M
