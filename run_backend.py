import subprocess, time, sys, os

dir_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'backend')
log_file = open(os.path.join(dir_path, 'server.log'), 'a')
proc = subprocess.Popen(['node', 'server.js'], cwd=dir_path, stdout=log_file, stderr=subprocess.STDOUT)
print(f"Backend started PID: {proc.pid}")
