import time
import requests
import os
from dotenv import load_dotenv

load_dotenv()
url = os.getenv("AI_SERVICE_URL", "http://localhost:8000")
# Append /health if present, depending on health endpoint
health_url = url.rstrip("/") + "/health"

print(f"Starting keep_warm.py to prevent Render cold starts...")
print(f"Target URL: {health_url}")
print("Run this script locally during the demo starting at 8:50 AM.")

while True:
    try:
        current_time = time.strftime('%Y-%m-%d %H:%M:%S')
        resp = requests.get(health_url, timeout=10)
        print(f"[{current_time}] Ping {health_url} -> Status {resp.status_code}")
    except Exception as e:
        print(f"[{current_time}] Ping failed: {e}")
    
    # Ping every 5 minutes (300 seconds) to keep Render free tier awake
    time.sleep(300)
