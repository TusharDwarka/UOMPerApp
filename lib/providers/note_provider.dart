import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import '../models/note.dart';
import '../services/isar_service.dart';

class NoteProvider extends ChangeNotifier {
  final IsarService _isarService;
  List<Note> _notes = [];
  
  NoteProvider(this._isarService);
  
  List<Note> get notes => _notes;
  
  Future<void> loadNotes() async {
    final isar = await _isarService.db;
    _notes = await isar.notes.where().sortByTimestampDesc().findAll();
    notifyListeners();
  }
  
  Future<void> addNote(Note note) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      await isar.notes.put(note);
    });
    await loadNotes(); // Reload and notify
  }
  
  Future<void> updateNote(Note note) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      await isar.notes.put(note);
    });
    await loadNotes(); // Reload and notify
  }
  
  Future<void> deleteNote(int id) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      await isar.notes.delete(id);
    });
    await loadNotes(); // Reload and notify
  }
}
