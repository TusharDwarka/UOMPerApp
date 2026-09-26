import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/module_resource.dart';
import '../services/isar_service.dart';
import '../services/sync_service.dart';

class ResourceProvider extends ChangeNotifier {
  final IsarService isarService;
  final SyncService? _syncService;

  static const defaultSections = ['Lectures', 'Tutorials', 'Past Papers', 'Assignments', 'General', 'Module Catalogue'];
  static const fallbackSection = 'General';

  List<ModuleResource> _resources = [];
  List<ModuleResource> get resources => _resources;

  /// Per-folder ordered section list. Folders without an entry use
  /// [defaultSections].
  Map<String, List<String>> _sections = {};

  /// Folders the user created that aren't timetable modules (e.g. "Internship").
  List<String> _customFolders = [];
  List<String> get customFolders => List.unmodifiable(_customFolders);

  /// Module folders (which come from the timetable) the user deleted/hid.
  List<String> _hiddenFolders = [];
  List<String> get hiddenFolders => List.unmodifiable(_hiddenFolders);
  bool isHidden(String folder) => _hiddenFolders.contains(folder);

  ResourceProvider(this.isarService, [this._syncService]) {
    loadResources();
    _loadStructure();
  }

  // --- Getters ---

  List<ModuleResource> get unsortedResources => _resources.where((r) => r.moduleName == 'Unsorted').toList();

  int get unsortedCount => unsortedResources.length;

  List<String> get moduleNames {
    final names = _resources.where((r) => r.moduleName != 'Unsorted').map((r) => r.moduleName).toSet().toList();
    names.sort();
    return names;
  }

  List<ModuleResource> getResourcesForModule(String moduleName) =>
      _resources.where((r) => r.moduleName == moduleName).toList();

  List<ModuleResource> getResourcesForModuleAndCategory(String moduleName, String category) =>
      _resources.where((r) => r.moduleName == moduleName && r.category == category).toList();

  /// Sections for a folder, including any section a file was filed under
  /// that is no longer in the list (so files never become invisible).
  List<String> sectionsFor(String folder) {
    final list = [...(_sections[folder] ?? defaultSections)];
    for (final r in _resources) {
      if (r.moduleName == folder && !list.contains(r.category)) list.add(r.category);
    }
    return list;
  }

  List<ModuleResource> search(String query) {
    final q = query.toLowerCase();
    return _resources.where((r) => r.fileName.toLowerCase().contains(q)).toList();
  }

  // --- Folder / section structure ---

  Future<void> _loadStructure() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('resource_sections');
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _sections = decoded.map((k, v) => MapEntry(k, List<String>.from(v as List)));
    }
    _customFolders = prefs.getStringList('custom_folders') ?? [];
    _hiddenFolders = prefs.getStringList('hidden_folders') ?? [];
    notifyListeners();
  }

  Future<void> _saveStructure() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('resource_sections', jsonEncode(_sections));
    await prefs.setStringList('custom_folders', _customFolders);
    await prefs.setStringList('hidden_folders', _hiddenFolders);
    _syncService?.pushSettings(settingsSnapshot());
    notifyListeners();
  }

  Map<String, dynamic> settingsSnapshot() => {
        'resourceSections': _sections,
        'customFolders': _customFolders,
        'hiddenFolders': _hiddenFolders,
      };

  Future<void> applyCloudSettings(Map<String, dynamic> s) async {
    final sections = s['resourceSections'];
    if (sections is Map) {
      _sections = sections.map((k, v) => MapEntry(k.toString(), List<String>.from(v as List)));
    }
    if (s['customFolders'] is List) _customFolders = List<String>.from(s['customFolders']);
    if (s['hiddenFolders'] is List) _hiddenFolders = List<String>.from(s['hiddenFolders']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('resource_sections', jsonEncode(_sections));
    await prefs.setStringList('custom_folders', _customFolders);
    await prefs.setStringList('hidden_folders', _hiddenFolders);
    notifyListeners();
  }

  /// Deletes a folder and every file in it. Timetable-module folders are
  /// hidden (they would otherwise reappear from the schedule).
  Future<int> deleteFolder(String folder) async {
    final files = getResourcesForModule(folder);
    for (final f in files) {
      await deleteResource(f.id);
    }
    _customFolders = _customFolders.where((f) => f != folder).toList();
    _sections.remove(folder);
    if (!_hiddenFolders.contains(folder)) _hiddenFolders = [..._hiddenFolders, folder];
    await _saveStructure();
    return files.length;
  }

  Future<void> unhideFolder(String folder) async {
    _hiddenFolders = _hiddenFolders.where((f) => f != folder).toList();
    await _saveStructure();
  }

  Future<bool> addSection(String folder, String name) async {
    final n = name.trim();
    final list = sectionsFor(folder);
    if (n.isEmpty || list.any((s) => s.toLowerCase() == n.toLowerCase())) return false;
    _sections[folder] = [...list, n];
    await _saveStructure();
    return true;
  }

  Future<bool> renameSection(String folder, String from, String to) async {
    final n = to.trim();
    final list = sectionsFor(folder);
    if (n.isEmpty || from == n || list.any((s) => s.toLowerCase() == n.toLowerCase())) return false;
    _sections[folder] = list.map((s) => s == from ? n : s).toList();
    await _recategorize(folder, from, n);
    await _saveStructure();
    return true;
  }

  /// Removes a section; its files move to "General".
  Future<void> deleteSection(String folder, String section) async {
    if (section == fallbackSection) return;
    final list = sectionsFor(folder)..remove(section);
    if (!list.contains(fallbackSection)) list.add(fallbackSection);
    _sections[folder] = list;
    await _recategorize(folder, section, fallbackSection);
    await _saveStructure();
  }

  Future<void> reorderSections(String folder, List<String> ordered) async {
    _sections[folder] = ordered;
    await _saveStructure();
  }

  Future<bool> addCustomFolder(String name) async {
    final n = name.trim();
    if (n.isEmpty || n == 'Unsorted' || _customFolders.contains(n)) return false;
    _hiddenFolders = _hiddenFolders.where((f) => f != n).toList();
    _customFolders = [..._customFolders, n];
    await _saveStructure();
    return true;
  }

  Future<void> removeCustomFolder(String name) async {
    _customFolders = _customFolders.where((f) => f != name).toList();
    _sections.remove(name);
    await _saveStructure();
  }

  Future<void> _recategorize(String folder, String from, String to) async {
    final isar = await isarService.db;
    final affected = _resources.where((r) => r.moduleName == folder && r.category == from).toList();
    if (affected.isEmpty) return;
    for (final r in affected) {
      r.category = to;
    }
    await isar.writeTxn(() => isar.moduleResources.putAll(affected));
    await loadResources();
  }

  // --- CRUD ---

  Future<void> loadResources() async {
    final isar = await isarService.db;
    _resources = await isar.moduleResources.where().sortByAddedAtDesc().findAll();
    notifyListeners();
  }

  /// Windows forbids \ / : * ? " < > | in folder names; module names like
  /// "Maths: Calculus" would otherwise fail to save.
  static String _safe(String name) => name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  Future<Directory> _dirFor(String moduleName, String category) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}${Platform.pathSeparator}resources${Platform.pathSeparator}'
        '${_safe(moduleName)}${Platform.pathSeparator}${_safe(category)}');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Add a resource by copying the source file into the app's documents directory.
  Future<void> addResource({
    required String sourceFilePath,
    required String fileName,
    required String moduleName,
    required String category,
    String? sourceApp,
  }) async {
    final resourceDir = await _dirFor(moduleName, category);

    String finalName = fileName;
    int counter = 1;
    while (await File('${resourceDir.path}${Platform.pathSeparator}$finalName').exists()) {
      final ext = fileName.contains('.') ? '.${fileName.split('.').last}' : '';
      final base = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
      finalName = '${base}_($counter)$ext';
      counter++;
    }

    final destPath = '${resourceDir.path}${Platform.pathSeparator}$finalName';
    final sourceFile = File(sourceFilePath);
    final fileSizeBytes = await sourceFile.length();
    await sourceFile.copy(destPath);

    final resource = ModuleResource(
      fileName: finalName,
      moduleName: moduleName,
      category: category,
      filePath: destPath,
      addedAt: DateTime.now(),
      sourceApp: sourceApp,
      fileSizeBytes: fileSizeBytes,
    );

    final isar = await isarService.db;
    await isar.writeTxn(() => isar.moduleResources.put(resource));
    await loadResources();
  }

  /// Move a resource to a different module and/or section.
  Future<void> moveResource(int id, String newModule, String newCategory) async {
    final isar = await isarService.db;
    final resource = await isar.moduleResources.get(id);
    if (resource == null) return;

    final newDir = await _dirFor(newModule, newCategory);
    final oldFile = File(resource.filePath);
    final newPath = '${newDir.path}${Platform.pathSeparator}${resource.fileName}';
    if (await oldFile.exists() && oldFile.path != newPath) {
      await oldFile.copy(newPath);
      await oldFile.delete();
      resource.filePath = newPath;
    }

    resource.moduleName = newModule;
    resource.category = newCategory;
    await isar.writeTxn(() => isar.moduleResources.put(resource));
    await loadResources();
  }

  /// Delete a resource (both Isar record and physical file).
  Future<void> deleteResource(int id) async {
    final isar = await isarService.db;
    final resource = await isar.moduleResources.get(id);
    if (resource != null) {
      final file = File(resource.filePath);
      if (await file.exists()) await file.delete();
    }
    await isar.writeTxn(() => isar.moduleResources.delete(id));
    await loadResources();
  }

  /// Rename a resource file.
  Future<void> renameResource(int id, String newName) async {
    final isar = await isarService.db;
    final resource = await isar.moduleResources.get(id);
    if (resource == null) return;

    final oldFile = File(resource.filePath);
    final newPath = '${oldFile.parent.path}${Platform.pathSeparator}$newName';
    if (await oldFile.exists()) await oldFile.rename(newPath);

    resource.fileName = newName;
    resource.filePath = newPath;
    await isar.writeTxn(() => isar.moduleResources.put(resource));
    await loadResources();
  }
}
