import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import '../models/note.dart';
import '../services/isar_service.dart';
import '../services/sync_service.dart';

class NoteProvider extends ChangeNotifier {
  final IsarService _isarService;
  final SyncService _syncService;
  List<Note> _notes = [];
  
  NoteProvider(this._isarService, this._syncService);
  
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
    
    await _syncService.pushToCloud();
    await loadNotes();
  }
  
  Future<void> updateNote(Note note) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      await isar.notes.put(note);
    });

    await _syncService.pushToCloud();
    await loadNotes();
  }
  
  Future<void> deleteNote(int id) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      await isar.notes.delete(id);
    });
    
    await _syncService.pushToCloud();
    await loadNotes();
  }
}
