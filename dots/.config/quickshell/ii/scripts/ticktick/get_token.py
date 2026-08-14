#!/usr/bin/env python3
import sys
import urllib.parse
import webbrowser
import http.server
import urllib.request
import json
import base64

def main():
    if len(sys.argv) < 3:
        print("ERROR: Missing Client ID and Client Secret", file=sys.stderr)
        sys.exit(1)

    client_id = sys.argv[1]
    client_secret = sys.argv[2]
    redirect_uri = "http://localhost:18321"
    scope = "tasks:read tasks:write"

    # Step 1: Open browser for authorization
    auth_url = f"https://ticktick.com/oauth/authorize?scope={urllib.parse.quote(scope, safe='')}&client_id={urllib.parse.quote(client_id, safe='')}&response_type=code&redirect_uri={urllib.parse.quote(redirect_uri, safe='')}&state=quickshell"

    webbrowser.open(auth_url)

    # Step 2: Listen for the authorization code
    class CallbackHandler(http.server.BaseHTTPRequestHandler):
        auth_code = None

        def do_GET(self):
            query = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(query)
            CallbackHandler.auth_code = params.get('code', [''])[0]
            
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<html><body style="background:#1a1a1a;color:#fff;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0"><div style="text-align:center;padding:20px;border-radius:10px;background:#2a2a2a;box-shadow:0 4px 6px rgba(0,0,0,0.3)"><h1>Authorized!</h1><p>You can close this tab and return to Quickshell Settings.</p></div></body></html>')
            
        def log_message(self, format, *args):
            pass

    server = http.server.HTTPServer(('localhost', 18321), CallbackHandler)
    server.handle_request()

    code = CallbackHandler.auth_code
    if not code:
        print("ERROR: Authorization code not received", file=sys.stderr)
        sys.exit(1)

    # Step 3: Exchange code for token
    try:
        token_url = "https://ticktick.com/oauth/token"
        data = urllib.parse.urlencode({
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirect_uri
        }).encode("utf-8")

        auth_str = f"{client_id}:{client_secret}"
        auth_b64 = base64.b64encode(auth_str.encode("utf-8")).decode("utf-8")

        req = urllib.request.Request(
            token_url,
            data=data,
            headers={
                "Authorization": f"Basic {auth_b64}",
                "Content-Type": "application/x-www-form-urlencoded"
            }
        )

        with urllib.request.urlopen(req) as response:
            res_data = json.loads(response.read().decode("utf-8"))
            access_token = res_data.get("access_token")
            if access_token:
                print(access_token)
                sys.exit(0)
            else:
                print(f"ERROR: Token not found in response: {res_data}", file=sys.stderr)
                sys.exit(1)
    except Exception as e:
        print(f"ERROR: Failed to exchange token: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
