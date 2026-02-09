import subprocess
import time

# Wait for Flutter to be ready
time.sleep(5)

# Send 'r' to trigger hot reload
proc = subprocess.Popen(['flutter', 'attach', '-d', '192.168.1.224:44933'], 
                        stdin=subprocess.PIPE, 
                        stdout=subprocess.PIPE, 
                        stderr=subprocess.PIPE)
proc.stdin.write(b'r\n')
proc.stdin.flush()
time.sleep(2)
proc.terminate()
