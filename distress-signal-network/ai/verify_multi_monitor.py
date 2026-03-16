import asyncio
import logging
import sys
import os

# Add the current directory to sys.path
sys.path.append(os.getcwd())

from distress_ai.monitor import monitor_loop, stop_monitor
from distress_ai.config import settings

logging.basicConfig(
    level=logging.INFO, 
    format="%(asctime)s | %(name)-24s | %(levelname)-7s | %(message)s",
    filename="verify_multi_logs.txt",
    filemode="w"
)

async def test_monitor():
    print("=== Testing Multi-Subreddit Reddit Monitor ===")
    settings.monitor_interval_seconds = 2
    
    try:
        monitor_task = asyncio.create_task(monitor_loop())
        # Let it run for 15 seconds to fetch from multiple subs
        await asyncio.sleep(15)
        print("=== Stopping Monitor ===")
        stop_monitor()
        await monitor_task
    except Exception as e:
        print(f"Monitor failed: {e}")
    
    print("=== Test Complete - Check verify_multi_logs.txt ===")

if __name__ == "__main__":
    asyncio.run(test_monitor())
