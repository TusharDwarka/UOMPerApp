import 'dart:io';
import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/module_resource.dart';
import '../services/isar_service.dart';

class ResourceProvider extends ChangeNotifier {
  final IsarService isarService;

  List<ModuleResource> _resources = [];
  List<ModuleResource> get resources => _resources;

  ResourceProvider(this.isarService) {
    loadResources();
  }

  // --- Getters ---

  List<ModuleResource> get unsortedResources =>
      _resources.where((r) => r.moduleName == 'Unsorted').toList();

  int get unsortedCount => unsortedResources.length;

  List<String> get moduleNames {
    final names = _resources
        .where((r) => r.moduleName != 'Unsorted')
        .map((r) => r.moduleName)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  List<ModuleResource> getResourcesForModule(String moduleName) {
    return _resources.where((r) => r.moduleName == moduleName).toList();
  }

  List<ModuleResource> getResourcesForModuleAndCategory(String moduleName, String category) {
    return _resources
        .where((r) => r.moduleName == moduleName && r.category == category)
        .toList();
  }

  // --- CRUD ---

  Future<void> loadResources() async {
    final isar = await isarService.db;
    _resources = await isar.moduleResources.where().sortByAddedAtDesc().findAll();
    notifyListeners();
  }

  /// Add a resource by copying the source file into the app's documents directory.
  /// [sourceFilePath] is the original file location (e.g. from share intent or file picker).
  Future<void> addResource({
    required String sourceFilePath,
    required String fileName,
    required String moduleName,
    required String category,
    String? sourceApp,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final resourceDir = Directory('${appDir.path}/resources/$moduleName/$category');
    if (!await resourceDir.exists()) {
      await resourceDir.create(recursive: true);
    }

    // Ensure unique filename
    String finalName = fileName;
    int counter = 1;
    while (await File('${resourceDir.path}/$finalName').exists()) {
      final ext = fileName.contains('.') ? '.${fileName.split('.').last}' : '';
      final base = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
      finalName = '${base}_($counter)$ext';
      counter++;
    }

    final destPath = '${resourceDir.path}/$finalName';
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
    await isar.writeTxn(() async {
      await isar.moduleResources.put(resource);
    });

    await loadResources();
  }

  /// Move a resource to a different module and/or category.
  Future<void> moveResource(int id, String newModule, String newCategory) async {
    final isar = await isarService.db;
    final resource = await isar.moduleResources.get(id);
    if (resource == null) return;

    // Move the physical file
    final appDir = await getApplicationDocumentsDirectory();
    final newDir = Directory('${appDir.path}/resources/$newModule/$newCategory');
    if (!await newDir.exists()) {
      await newDir.create(recursive: true);
    }

    final oldFile = File(resource.filePath);
    final newPath = '${newDir.path}/${resource.fileName}';
    if (await oldFile.exists()) {
      await oldFile.copy(newPath);
      await oldFile.delete();
    }

    resource.moduleName = newModule;
    resource.category = newCategory;
    resource.filePath = newPath;

    await isar.writeTxn(() async {
      await isar.moduleResources.put(resource);
    });

    await loadResources();
  }

  /// Delete a resource (both Isar record and physical file).
  Future<void> deleteResource(int id) async {
    final isar = await isarService.db;
    final resource = await isar.moduleResources.get(id);

    if (resource != null) {
      // Delete physical file
      final file = File(resource.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await isar.writeTxn(() async {
      await isar.moduleResources.delete(id);
    });

    await loadResources();
  }

  /// Rename a resource file.
  Future<void> renameResource(int id, String newName) async {
    final isar = await isarService.db;
    final resource = await isar.moduleResources.get(id);
    if (resource == null) return;

    final oldFile = File(resource.filePath);
    final dir = oldFile.parent.path;
    final newPath = '$dir/$newName';

    if (await oldFile.exists()) {
      await oldFile.rename(newPath);
    }

    resource.fileName = newName;
    resource.filePath = newPath;

    await isar.writeTxn(() async {
      await isar.moduleResources.put(resource);
    });

    await loadResources();
  }
}
