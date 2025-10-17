from flask import Flask, request, jsonify
import logging
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import sqlite3
import os
import shutil
import time

DB_PATH = os.path.join(os.path.dirname(__file__), 'data.db')

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    c = conn.cursor()
    c.execute('''
    CREATE TABLE IF NOT EXISTS groceries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        quantity INTEGER DEFAULT 1,
        checked INTEGER DEFAULT 0
    )
    ''')
    conn.commit()
    conn.close()

def create_app():
    app = Flask(__name__)
    CORS(app)
    return app


# Create app and socketio at module import so gunicorn can import them.
app = create_app()
socketio = SocketIO(app, cors_allowed_origins="*")

# Basic logging configuration so startup messages and errors appear in the journal
logging.basicConfig(level=logging.INFO)


def _safe_db_count(path):
    try:
        if not os.path.exists(path):
            return 0
        conn = sqlite3.connect(path)
        cur = conn.cursor()
        cur.execute("SELECT count(*) FROM groceries;")
        n = cur.fetchone()[0]
        conn.close()
        return int(n or 0)
    except Exception:
        return 0


def _maybe_backup_db(path, backups_dir=None, keep=5):
    try:
        if not os.path.exists(path):
            return
        if os.path.getsize(path) == 0:
            return
        if backups_dir is None:
            backups_dir = os.path.join(os.path.dirname(__file__), 'backups')
        os.makedirs(backups_dir, exist_ok=True)
        ts = time.strftime('%Y%m%d_%H%M%S')
        dest = os.path.join(backups_dir, f'data.db.{ts}')
        shutil.copy2(path, dest)
        # prune old backups, keep most recent `keep`
        files = sorted([os.path.join(backups_dir, f) for f in os.listdir(backups_dir)], key=os.path.getmtime, reverse=True)
        for old in files[keep:]:
            try:
                os.remove(old)
            except Exception:
                pass
    except Exception:
        pass

# Log DB diagnostics at import so the running service writes this into the journal.
try:
    row_count = _safe_db_count(DB_PATH)
    logging.getLogger('app').info(f"HomeHub DB path={DB_PATH} exists={os.path.exists(DB_PATH)} rows={row_count}")
    # create a backup only if there is data present (helps preserve state)
    if row_count > 0:
        _maybe_backup_db(DB_PATH)
except Exception:
    pass

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})


@app.route('/', methods=['GET'])
def index():
    # If a static SPA has been built into server/static, serve it. Otherwise
    # return a small informative HTML page so '/' doesn't 404.
    static_index = os.path.join(os.path.dirname(__file__), 'static', 'index.html')
    if os.path.exists(static_index):
        with open(static_index, 'r', encoding='utf-8') as f:
            return f.read(), 200, {'Content-Type': 'text/html'}
    return (
        '<html><body><h1>HomeHub</h1><p>Backend is running. See /health and /groceries.</p></body></html>',
        200,
        {'Content-Type': 'text/html'},
    )

@app.route('/groceries', methods=['GET'])
def list_groceries():
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT * FROM groceries ORDER BY id DESC')
    rows = c.fetchall()
    conn.close()
    items = [dict(row) for row in rows]
    return jsonify(items)

@app.route('/groceries', methods=['POST'])
def add_grocery():
    data = request.get_json() or {}
    name = data.get('name')
    quantity = int(data.get('quantity') or 1)
    if not name:
        return jsonify({'error': 'name required'}), 400
    conn = get_db()
    c = conn.cursor()
    c.execute('INSERT INTO groceries (name, quantity) VALUES (?, ?)', (name, quantity))
    conn.commit()
    gid = c.lastrowid
    c.execute('SELECT * FROM groceries WHERE id=?', (gid,))
    row = c.fetchone()
    item = dict(row)
    conn.close()
    # emit in a version-compatible way: some server implementations
    # don't accept the 'broadcast' keyword. Try with broadcast and
    # fall back to a plain emit.
    try:
        socketio.emit('groceries:created', item, broadcast=True)
    except TypeError:
        socketio.emit('groceries:created', item)
    return jsonify(item), 201

@app.route('/groceries/<int:gid>', methods=['PUT'])
def update_grocery(gid):
    data = request.get_json() or {}
    fields = []
    params = []
    for key in ('name', 'quantity', 'checked'):
        if key in data:
            fields.append(f"{key}=?")
            params.append(data[key])
    if not fields:
        return jsonify({'error': 'no fields to update'}), 400
    params.append(gid)
    conn = get_db()
    c = conn.cursor()
    c.execute(f"UPDATE groceries SET {', '.join(fields)} WHERE id=?", params)
    conn.commit()
    c.execute('SELECT * FROM groceries WHERE id=?', (gid,))
    row = c.fetchone()
    conn.close()
    if not row:
        return jsonify({'error': 'not found'}), 404
    item = dict(row)
    try:
        socketio.emit('groceries:updated', item, broadcast=True)
    except TypeError:
        socketio.emit('groceries:updated', item)
    return jsonify(item)

@app.route('/groceries/<int:gid>', methods=['DELETE'])
def delete_grocery(gid):
    conn = get_db()
    c = conn.cursor()
    c.execute('SELECT * FROM groceries WHERE id=?', (gid,))
    row = c.fetchone()
    if not row:
        conn.close()
        return jsonify({'error': 'not found'}), 404
    c.execute('DELETE FROM groceries WHERE id=?', (gid,))
    conn.commit()
    conn.close()
    try:
        socketio.emit('groceries:deleted', {'id': gid}, broadcast=True)
    except TypeError:
        socketio.emit('groceries:deleted', {'id': gid})
    return jsonify({'id': gid})

@socketio.on('connect')
def on_connect():
    emit('server:connected', {'message': 'welcome'})

if __name__ == '__main__':
    init_db()
    # For local testing only: run Werkzeug dev server. Production deployments
    # should start this app via gunicorn + eventlet worker (see systemd unit).
    app.logger.info("Starting HomeHub server on 0.0.0.0:5000")
    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True)
