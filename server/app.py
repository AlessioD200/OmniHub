from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_socketio import SocketIO, emit
import sqlite3
import os

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

app = Flask(__name__)
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*")

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'})

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
    socketio.emit('groceries:created', item, broadcast=True)
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
    socketio.emit('groceries:updated', item, broadcast=True)
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
    socketio.emit('groceries:deleted', {'id': gid}, broadcast=True)
    return jsonify({'id': gid})

@socketio.on('connect')
def on_connect():
    emit('server:connected', {'message': 'welcome'})

if __name__ == '__main__':
    init_db()
    # For a self-hosted Raspberry Pi deployment it's acceptable to allow the
    # Werkzeug development server; in production you should use eventlet/gevent
    # or a proper WSGI server. Pass allow_unsafe_werkzeug=True to opt-in.
    socketio.run(app, host='0.0.0.0', port=5000, debug=True, allow_unsafe_werkzeug=True)
