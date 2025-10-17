import React, {useEffect, useState} from 'react';
import { createRoot } from 'react-dom/client';
import { io } from 'socket.io-client';

const API = 'http://localhost:5000';

function App(){
  const [items, setItems] = useState([]);
  useEffect(()=>{
    fetch(API+'/groceries')
      .then(r=>r.json())
      .then(setItems)
      .catch(console.error);
    const socket = io(API);
    socket.on('groceries:created', item => setItems(prev => [item, ...prev]));
    socket.on('groceries:updated', item => setItems(prev => prev.map(i=>i.id===item.id?item:i)));
    socket.on('groceries:deleted', obj => setItems(prev => prev.filter(i=>i.id!==obj.id)));
    return ()=> socket.disconnect();
  },[]);

  const add = async ()=>{
    const name = prompt('Item name');
    if(!name) return;
    await fetch(API+'/groceries', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({name})});
  };

  return (
    <div style={{fontFamily: 'Arial, sans-serif', padding: 20}}>
      <h1>HomeHub - Groceries</h1>
      <button onClick={add}>Add item</button>
      <ul>
        {items.map(it=> (
          <li key={it.id}>{it.name} {it.quantity>1?`(x${it.quantity})`:''}</li>
        ))}
      </ul>
    </div>
  );
}

createRoot(document.getElementById('root')).render(<App/>);
