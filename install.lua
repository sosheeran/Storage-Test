-- install.lua
-- Storage-Test Installer
-- wget https://raw.githubusercontent.com/sosheeran/Storage-Test/main/install.lua install && install

local REPO = "https://raw.githubusercontent.com/sosheeran/Storage-Test/main/"

local FILES = {
  {"scripts/discover.lua",       "/discover.lua"},
  {"scripts/debug_storage.lua",  "/debug_storage.lua"},
  {"scripts/storage_log.lua",    "/storage_log.lua"},
  {"scripts/lib/storage.lua",    "/scripts/lib/storage.lua"},
  {"scripts/lib/printer.lua",    "/scripts/lib/printer.lua"},
}

local DIRS = {"/data", "/scripts", "/scripts/lib"}

local function wget(src, dest)
  if fs.exists(dest) then fs.delete(dest) end
  pcall(function() shell.run("wget " .. REPO .. src .. " " .. dest) end)
  if fs.exists(dest) then print("  + " .. dest); return true end
  print("  ! FAILED: " .. dest); return false
end

print("=== STORAGE-TEST INSTALLER ===")
print("")

for _, d in ipairs(DIRS) do
  if not fs.exists(d) then fs.makeDir(d); print("  mkdir " .. d) end
end

local ok_count, fail_count = 0, 0
for _, f in ipairs(FILES) do
  if wget(f[1], f[2]) then ok_count=ok_count+1 else fail_count=fail_count+1 end
end

print("")
print("Installed: " .. ok_count)
if fail_count > 0 then
  print("Failed:    " .. fail_count)
else
  print("All OK")
end
print("")
print("Commands:")
print("  discover        scan chests → /data/storage.cfg")
print("  debug_storage   dump all items → /data/debug_dump.txt")
print("  storage_log     show stock levels")
