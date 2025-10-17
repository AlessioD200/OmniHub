Build and serve the web UI

This repo uses Parcel for the simple React web client. To build and copy the built assets so the backend serves the UI:

1. Install node deps:

   npm install

2. Build and copy to backend static folder:

   ./build_and_copy.sh

3. Restart the backend (systemd) so it serves the new files:

   sudo systemctl restart homehub.service

The script will copy the Parcel `dist/` output into `server/static/` so the Flask backend serves the built UI.
# HomeHub Web

Minimal React frontend using Parcel. Connects to the server at http://localhost:5000 and listens for Socket.IO events.

Quickstart

```bash
cd web
npm install
npm start
```
