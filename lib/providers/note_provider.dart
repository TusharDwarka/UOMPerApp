import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import '../models/note.dart';
import '../services/isar_service.dart';
import '../services/sync_service.dart';

class NoteProvider extends ChangeNotifier {
  final IsarService _isarService;
  final SyncService _syncService;
  StreamSubscription<Set<String>>? _syncSub;
  List<Note> _notes = [];

  NoteProvider(this._isarService, this._syncService) {
    _syncSub = _syncService.changes.listen((cols) {
      if (cols.contains(SyncService.notesCol)) loadNotes();
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  /// Pinned first, then most recently edited.
  List<Note> get notes => _notes;

  Future<void> loadNotes() async {
    final isar = await _isarService.db;
    final all = await isar.notes.where().sortByTimestampDesc().findAll();
    _notes = [...all.where((n) => n.isPinned == true), ...all.where((n) => n.isPinned != true)];
    notifyListeners();
  }

  Future<void> addNote(Note note) => updateNote(note);

  Future<void> updateNote(Note note) async {
    SyncService.stamp(note);
    final isar = await _isarService.db;
    await isar.writeTxn(() => isar.notes.put(note));
    _syncService.pushNote(note);
    await loadNotes();
  }

  Future<void> togglePin(Note note) async {
    note.isPinned = !(note.isPinned ?? false);
    await updateNote(note);
  }

  /// Deletes a note and returns it so the caller can offer "Undo".
  Future<Note?> deleteNote(int id) async {
    final isar = await _isarService.db;
    final note = await isar.notes.get(id);
    if (note == null) return null;
    await isar.writeTxn(() => isar.notes.delete(id));
    _syncService.pushDelete(SyncService.notesCol, note.syncId);
    await loadNotes();
    return note;
  }

  Future<void> restoreNote(Note note) async {
    note.id = Isar.autoIncrement;
    await updateNote(note);
  }
}
