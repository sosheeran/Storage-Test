-- firewall/startup.lua
print("[STARTUP] Firewall booting...")
sleep(2)
shell.run("bg", "/fw/firewall")
print("[STARTUP] Firewall running")
