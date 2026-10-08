import subprocess
import json

def get_procs():
    output = subprocess.check_output(['powershell', '-NoProfile', '-Command', 
        "Get-CimInstance Win32_Process | Select-Object ProcessId, CommandLine | ConvertTo-Json"
    ], text=True)
    procs = json.loads(output)
    tripo_procs = [p for p in procs if p.get('CommandLine') and 'tripo' in p['CommandLine'].lower()]
    print(f"Total matching tripo processes: {len(tripo_procs)}")
    for p in tripo_procs:
        print(f"PID: {p['ProcessId']} | CMD: {p['CommandLine'][:120]}...")

if __name__ == '__main__':
    get_procs()
