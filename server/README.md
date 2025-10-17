# HomeHub - Server (Flask)

Minimal Flask server for the HomeHub MVP. Provides a simple CRUD API for a shared groceries list and emits realtime events via Socket.IO.

Quickstart

1. Create a virtual environment and install dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

2. Run the server:

```bash
python app.py
```

The server will listen on port 5000. Endpoints:

- GET /health
- GET /groceries
- POST /groceries {name, quantity}
- PUT /groceries/:id
- DELETE /groceries/:id

Socket.IO events emitted:
- groceries:created
- groceries:updated
- groceries:deleted
