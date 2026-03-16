import asyncio
import logging
import sys
import os

# Add the current directory to sys.path to allow imports from distress_ai
sys.path.append(os.getcwd())

from distress_ai.monitor import monitor_loop, stop_monitor
from distress_ai.config import settings

logging.basicConfig(
    level=logging.INFO, 
    format="%(asctime)s | %(name)-24s | %(levelname)-7s | %(message)s",
    filename="verify_logs.txt",
    filemode="w"
)

async def test_monitor():
    print("=== Testing r/DisasterUpdate Monitor ===")
    # Set a short interval for testing
    settings.monitor_interval_seconds = 2
    
    # Start the monitor loop in a task
    # We wrap it in a try-except to catch startup errors
    try:
        monitor_task = asyncio.create_task(monitor_loop())
        # Let it run for 10 seconds
        await asyncio.sleep(10)
        print("=== Stopping Monitor ===")
        stop_monitor()
        await monitor_task
    except Exception as e:
        print(f"Monitor failed: {e}")
    
    print("=== Test Complete - Check verify_logs.txt ===")

if __name__ == "__main__":
    asyncio.run(test_monitor())
