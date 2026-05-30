-- install.lua
-- MC-TWEAKED Installer
-- wget https://raw.githubusercontent.com/sosheeran/Storage-Test/main/install.lua install && install

local REPO = "https://raw.githubusercontent.com/sosheeran/Storage-Test/main/"
local ID   = os.getComputerID()

local SHARED = {
  {"shared/lib/sha256.lua",  "/lib/sha256.lua"},
  {"shared/lib/logger.lua",  "/lib/logger.lua"},
  {"shared/lib/storage.lua", "/lib/storage.lua"},
}

local CONFIGS = {

  [2] = {
    name = "firewall",
    dirs = {"/lib", "/fw", "/fw/lib", "/fw/data"},
    files = {
      {"firewall/firewall.lua",       "/fw/firewall.lua"},
      {"firewall/startup.lua",        "/fw/startup.lua"},
      {"firewall/lib/services.lua",   "/fw/lib/services.lua"},
      {"firewall/lib/validator.lua",  "/fw/lib/validator.lua"},
      {"firewall/lib/ratelimit.lua",  "/fw/lib/ratelimit.lua"},
      {"firewall/lib/router.lua",     "/fw/lib/router.lua"},
    },
    data = {
      {"firewall/data/services.cfg",  "/fw/data/services.cfg"},
      {"firewall/data/blocklist.cfg", "/fw/data/blocklist.cfg"},
    },
    startup = 'shell.run("bg", "/fw/startup")',
  },

  [4] = {
    name = "storage",
    dirs = {"/lib", "/storage", "/storage/data",
            "/scripts", "/scripts/lib"},
    files = {
      {"scripts/discover.lua",        "/discover.lua"},
      {"scripts/storage_log.lua",     "/storage_log.lua"},
      {"scripts/debug_storage.lua",   "/debug_storage.lua"},
      {"scripts/lib/storage.lua",     "/scripts/lib/storage.lua"},
    },
    data = {},
    startup = nil,  -- no auto startup yet, scripts run manually
  },

}

-- Client: ID 12+
local CLIENT_CONFIG = {
  name = "client",
  dirs = {"/lib", "/client", "/client/lib"},
  files = {},
  data  = {},
  startup = nil,
}

local function wget(src, dest)
  if fs.exists(dest) then fs.delete(dest) end
  pcall(function() shell.run("wget " .. REPO .. src .. " " .. dest) end)
  if fs.exists(dest) then print("  + " .. dest); return true end
  print("  ! FAILED: " .. dest); return false
end

local function mkdirs(dirs)
  for _, d in ipairs(dirs) do
    if not fs.exists(d) then
      fs.makeDir(d)
      print("  mkdir " .. d)
    end
  end
end

local cfg = CONFIGS[ID]
if not cfg and ID >= 12 then cfg = CLIENT_CONFIG end

if not cfg then
  print("No config for computer ID " .. ID)
  print("Supported: 2 (firewall)  4 (storage)  12+ (client)")
  return
end

print("=== MC-TWEAKED: " .. cfg.name .. " (ID " .. ID .. ") ===")
print("")

mkdirs(cfg.dirs)

local ok_count, fail_count = 0, 0

print("Installing shared libs...")
for _, f in ipairs(SHARED) do
  if wget(f[1], f[2]) then ok_count=ok_count+1 else fail_count=fail_count+1 end
end

print("Installing " .. cfg.name .. " files...")
for _, f in ipairs(cfg.files) do
  if wget(f[1], f[2]) then ok_count=ok_count+1 else fail_count=fail_count+1 end
end

if cfg.data and #cfg.data > 0 then
  print("Installing data files...")
  for _, f in ipairs(cfg.data) do
    if fs.exists(f[2]) then
      print("  = " .. f[2] .. " (kept)")
      ok_count = ok_count + 1
    else
      if wget(f[1], f[2]) then ok_count=ok_count+1 else fail_count=fail_count+1 end
    end
  end
end

if cfg.startup then
  local f = fs.open("/startup.lua", "w")
  f.writeLine(cfg.startup)
  f.close()
  print("  + /startup.lua")
end

print("")
print("================================")
print("Installed: " .. ok_count)
if fail_count > 0 then
  print("Failed:    " .. fail_count)
  print("Check connection and retry")
else
  print("All OK")
end
print("")
if cfg.startup then
  print("Run: reboot")
else
  print("Available commands:")
  if ID == 4 then
    print("  discover       scan chests → storage.cfg")
    print("  storage_log    show stock levels")
    print("  debug_storage  troubleshoot peripherals")
  end
end
