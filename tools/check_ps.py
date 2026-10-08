import subprocess
import json

script = """
Get-CimInstance Win32_Process | Where-Object ProcessName -eq "powershell.exe" | Select-Object ProcessId, CommandLine | ConvertTo-Json
"""

res = subprocess.run(["powershell", "-NoProfile", "-Command", script], capture_output=True, text=True)
print(res.stdout)
