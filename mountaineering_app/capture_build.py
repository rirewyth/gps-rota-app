import subprocess
import os

def run_build():
    cmd = ["C:\\flutter\\bin\\flutter.bat", "build", "apk", "--release", "-v"]
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace')
    
    with open("full_build_log.txt", "w", encoding="utf-8") as f:
        for line in process.stdout:
            print(line, end="")
            f.write(line)
            f.flush()
    
    process.wait()
    print(f"Build finished with exit code {process.returncode}")

if __name__ == "__main__":
    run_build()
