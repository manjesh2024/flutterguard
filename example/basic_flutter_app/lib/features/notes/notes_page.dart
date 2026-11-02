import 'package:flutter/material.dart';

import 'note.dart';

/// Minimal notes screen used by the basic example.
class NotesPage extends StatefulWidget {
  /// Creates the notes screen.
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _notes = const <Note>[Note('Launch'), Note('Review')];
  var _extra = 0;

  @override
  Widget build(BuildContext context) {
    final notes = [..._notes, for (var i = 0; i < _extra; i++) Note('Extra')];
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: ListView.builder(
        itemCount: notes.length,
        itemBuilder: (context, index) {
          return ListTile(title: Text(notes[index].title));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _extra += 1),
        tooltip: 'Add',
        child: const Icon(Icons.add),
      ),
    );
  }
}
