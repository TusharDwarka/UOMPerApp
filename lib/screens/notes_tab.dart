import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/note_provider.dart';
import '../models/note.dart';
import 'dart:math';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier("");
  final TextEditingController _searchController = TextEditingController();
  
  // Creative Colors (Pastel / Soft Material)
  final List<Color> _noteColors = [
    const Color(0xFFFFF8E1), // Amber 50
    const Color(0xFFE3F2FD), // Blue 50
    const Color(0xFFF3E5F5), // Purple 50
    const Color(0xFFE8F5E9), // Green 50
    const Color(0xFFFFEBEE), // Red 50
    const Color(0xFFE0F7FA), // Cyan 50
    const Color(0xFFFFF3E0), // Orange 50
    const Color(0xFFFCE4EC), // Pink 50
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NoteProvider>(context, listen: false).loadNotes();
    });
  }

  @override
  void dispose() {
    _searchQueryNotifier.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Note> _filterNotes(List<Note> notes, String query) {
    if (query.isEmpty) return notes;
    return notes.where((n) {
      return n.title.toLowerCase().contains(query.toLowerCase()) ||
             n.content.toLowerCase().contains(query.toLowerCase()) ||
             n.subject.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false, 
      appBar: AppBar(
        title: Text("Creative Notes", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Provider.of<NoteProvider>(context, listen: false).loadNotes(),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteEditor(),
        backgroundColor: isDark ? const Color(0xFF2962FF) : Colors.black,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("New Note", style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: RepaintBoundary(
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "Search notes, subjects...",
                  hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey),
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20)
                ),
                onChanged: (val) {
                  _searchQueryNotifier.value = val; 
                },
              ),
            ),
          ),
          
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _searchQueryNotifier,
              builder: (context, query, _) {
                return Consumer<NoteProvider>(
                  builder: (context, noteProvider, _) {
                    final filteredNotes = _filterNotes(noteProvider.notes, query);
                    
                    if (filteredNotes.isEmpty) {
                      return Center(
                        child: Text(
                          "Empty Canvas", 
                          style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[300], fontSize: 20, fontWeight: FontWeight.bold)
                        )
                      );
                    }
                    
                    return _buildMasonryGrid(filteredNotes);
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  // Simple Manual Masonry (2 columns)
  Widget _buildMasonryGrid(List<Note> notes) {
    final leftColumn = <Widget>[];
    final rightColumn = <Widget>[];

    for (var i = 0; i < notes.length; i++) {
      final card = RepaintBoundary(
        key: ValueKey('note_${notes[i].id}'),
        child: _buildNoteCard(notes[i])
      );
      if (i % 2 == 0) {
        leftColumn.add(card);
      } else {
        rightColumn.add(card);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      physics: const BouncingScrollPhysics(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: leftColumn)),
          const SizedBox(width: 16),
          Expanded(child: Column(children: rightColumn)),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    // Keep pastel colors as they are meant to be 'creative' notes
    // Text on these pastels should remain black
    final color = _noteColors[note.colorIndex % _noteColors.length];
    
    return GestureDetector(
      onTap: () => _showNoteEditor(note: note),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.subject.isNotEmpty && note.subject != "General")
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Text(
                  note.subject.toUpperCase(), 
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.black87),
                ),
              ),
              
            Text(
              note.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.2, color: Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              note.content,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.7), height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              DateFormat('MMM d').format(note.timestamp),
              style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteEditor({Note? note}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => NoteEditorSheet(
        note: note,
        colors: _noteColors,
      ),
    );
  }
}

class NoteEditorSheet extends StatefulWidget {
  final Note? note;
  final List<Color> colors;

  const NoteEditorSheet({super.key, this.note, required this.colors});

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _subjectController;
  late int _selectedColorIndex;
  late bool _isNew;

  @override
  void initState() {
    super.initState();
    _isNew = widget.note == null;
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _subjectController = TextEditingController(text: widget.note?.subject ?? 'General');
    
    if (widget.note != null) {
      _selectedColorIndex = widget.note!.colorIndex;
      if (_selectedColorIndex >= widget.colors.length) _selectedColorIndex = 0;
    } else {
      _selectedColorIndex = Random().nextInt(widget.colors.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
       padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20, left: 20, right: 20
      ), 
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85, 
        child: Column(
          children: [
            // Header Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black), onPressed: () => Navigator.pop(context)),
                if (!_isNew)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red), 
                    onPressed: () async {
                      await noteProvider.deleteNote(widget.note!.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  ),
                 IconButton(
                   icon: const Icon(Icons.check, color: Colors.blue, size: 28),
                   onPressed: () async {
                     if (_titleController.text.isNotEmpty) {
                       final newNote = Note(
                         title: _titleController.text,
                         content: _contentController.text,
                         subject: _subjectController.text,
                         colorIndex: _selectedColorIndex,
                         timestamp: DateTime.now()
                       );
                       // Ensure ID is preserved for updates
                       if (!_isNew) {
                         newNote.id = widget.note!.id;
                       }
                       
                       if (_isNew) {
                         await noteProvider.addNote(newNote);
                       } else {
                         await noteProvider.updateNote(newNote);
                       }
                       
                       if (context.mounted) Navigator.pop(context);
                     }
                   }
                 )
              ],
            ),
            
            const SizedBox(height: 10),
            
            // Color Picker Strip - Const where possible
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(widget.colors.length, (index) {
                  final isSelected = _selectedColorIndex == index;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                         _selectedColorIndex = index;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: widget.colors[index],
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: isDark ? Colors.white : Colors.black, width: 2) : Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!)
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),

            // Inputs
            RepaintBoundary(
              child: TextField(
                controller: _titleController,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration.collapsed(hintText: "Title", hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[400])),
              ),
            ),
            const SizedBox(height: 10),
            RepaintBoundary(
              child: TextField(
                controller: _subjectController,
                style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600),
                decoration: InputDecoration.collapsed(hintText: "Subject / Tag", hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[300])),
              ),
            ),
            const Divider(height: 30),
            Expanded(
              child: RepaintBoundary(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  style: TextStyle(fontSize: 18, height: 1.5, color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration.collapsed(hintText: "Start writing...", hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[400])),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
