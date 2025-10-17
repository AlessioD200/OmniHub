import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeHub',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List items = [];

  @override
  void initState() {
    super.initState();
    fetchItems();
    // TODO: initialize Socket.IO client and subscribe to realtime events
  }

  Future<void> fetchItems() async {
    final res = await http.get(Uri.parse('http://10.0.2.2:5000/groceries'));
    if (res.statusCode == 200) {
      setState(() {
        items = jsonDecode(res.body);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HomeHub - Groceries')),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final it = items[index];
          return ListTile(
            title: Text(it['name'] ?? ''),
            subtitle: Text('qty: ${it['quantity'] ?? 1}'),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await _askForName();
          if (name != null && name.isNotEmpty) {
            await http.post(Uri.parse('http://10.0.2.2:5000/groceries'),
                headers: {'Content-Type': 'application/json'}, body: jsonEncode({'name': name}));
            fetchItems();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<String?> _askForName() async {
    String? value;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New item'),
          content: TextField(
            autofocus: true,
            onChanged: (v) => value = v,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Add')),
          ],
        );
      },
    );
    return value;
  }
}
