#!/usr/bin/env python3
import sys
import json
import time

def log(msg):
    sys.stderr.write(msg + "\n")
    sys.stderr.flush()

log("Mock ACP Agent starting...")

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    log(f"Received: {line}")
    try:
        data = json.loads(line)
    except Exception as e:
        log(f"Error parsing JSON: {e}")
        continue
        
    method = data.get("method")
    msg_id = data.get("id")
    
    if method == "initialize":
        resp = {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "protocolVersion": 1,
                "capabilities": {}
            }
        }
        sys.stdout.write(json.dumps(resp) + "\n")
        sys.stdout.flush()
        
    elif method == "session/new":
        resp = {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "sessionId": "mock-session-123"
            }
        }
        sys.stdout.write(json.dumps(resp) + "\n")
        sys.stdout.flush()
        
    elif method == "session/prompt":
        sess_id = data.get("params", {}).get("sessionId")
        user_prompt = data.get("params", {}).get("content", [{}])[0].get("text", "")
        
        reply_text = f"Received your prompt: '{user_prompt}'. This is a mock AI Agent response running via ACP protocol locally!"
        
        words = reply_text.split(" ")
        for word in words:
            time.sleep(0.1)
            notification = {
                "jsonrpc": "2.0",
                "method": "session/update",
                "params": {
                    "sessionId": sess_id,
                    "update": {
                        "sessionUpdate": "agent_message_chunk",
                        "content": {
                            "type": "text",
                            "text": word + " "
                        }
                    }
                }
            }
            sys.stdout.write(json.dumps(notification) + "\n")
            sys.stdout.flush()
            
        time.sleep(0.1)
        resp = {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "stopReason": "end_turn"
            }
        }
        sys.stdout.write(json.dumps(resp) + "\n")
        sys.stdout.flush()
