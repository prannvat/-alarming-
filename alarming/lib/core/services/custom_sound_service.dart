import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Model for a custom alarm sound
class CustomSound {
  final String id;
  final String name;
  final String filePath;
  final DateTime addedAt;

  CustomSound({
    required this.id,
    required this.name,
    required this.filePath,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'filePath': filePath,
    'addedAt': addedAt.toIso8601String(),
  };

  factory CustomSound.fromJson(Map<String, dynamic> json) => CustomSound(
    id: json['id'] as String,
    name: json['name'] as String,
    filePath: json['filePath'] as String,
    addedAt: DateTime.parse(json['addedAt'] as String),
  );
}

/// Predefined alarm sounds that come with the app
class PredefinedSound {
  final String id;
  final String name;
  final String assetPath;
  final String emoji;

  const PredefinedSound({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.emoji,
  });
}

class CustomSoundService {
  static final CustomSoundService _instance = CustomSoundService._internal();
  factory CustomSoundService() => _instance;
  CustomSoundService._internal();

  static const String _boxName = 'custom_sounds';
  Box? _box;

  /// Predefined sounds that come with the app
  static const List<PredefinedSound> predefinedSounds = [
    PredefinedSound(
      id: 'default',
      name: 'Default',
      assetPath: 'assets/sounds/alarm.mp3',
      emoji: '🔔',
    ),
    // We can add more predefined sounds here later
  ];

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  /// Get the directory where custom sounds are stored
  Future<Directory> _getSoundsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final soundsDir = Directory('${appDir.path}/custom_sounds');
    if (!await soundsDir.exists()) {
      await soundsDir.create(recursive: true);
    }
    return soundsDir;
  }

  /// Pick an audio file from the device
  Future<CustomSound?> pickAndSaveSound() async {
    try {
      print('📂 Opening file picker...');
      
      // Use FileType.any with custom extensions to open Files app on iOS
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg', 'aiff', 'wma'],
        allowMultiple: false,
        withData: true, // Important for iOS - get the file bytes directly
      );

      if (result == null || result.files.isEmpty) {
        print('❌ No file selected');
        return null;
      }

      final pickedFile = result.files.first;
      print('📄 Picked file: ${pickedFile.name}, size: ${pickedFile.size}');
      
      // Generate unique ID
      final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      
      // Get the sounds directory
      final soundsDir = await _getSoundsDirectory();
      
      // Determine file extension
      final extension = pickedFile.extension ?? 'mp3';
      final fileName = '$id.$extension';
      final destPath = '${soundsDir.path}/$fileName';
      
      // On iOS, we need to use the bytes directly since the path may be temporary
      if (pickedFile.bytes != null) {
        print('💾 Saving from bytes...');
        final destFile = File(destPath);
        await destFile.writeAsBytes(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        print('💾 Copying from path: ${pickedFile.path}');
        final sourceFile = File(pickedFile.path!);
        if (await sourceFile.exists()) {
          await sourceFile.copy(destPath);
        } else {
          print('❌ Source file does not exist');
          return null;
        }
      } else {
        print('❌ No file data available');
        return null;
      }

      // Verify the file was saved
      final savedFile = File(destPath);
      if (!await savedFile.exists()) {
        print('❌ Failed to save file');
        return null;
      }
      
      print('✅ File saved at: $destPath');

      // Create CustomSound object
      final customSound = CustomSound(
        id: id,
        name: pickedFile.name.replaceAll(RegExp(r'\.[^\.]+$'), ''), // Remove extension
        filePath: destPath,
        addedAt: DateTime.now(),
      );

      // Save to Hive
      await _saveSound(customSound);

      print('✅ Custom sound saved: ${customSound.name} at $destPath');
      return customSound;
    } catch (e) {
      print('❌ Error picking sound: $e');
      return null;
    }
  }

  /// Save a custom sound to storage
  Future<void> _saveSound(CustomSound sound) async {
    await init();
    await _box!.put(sound.id, sound.toJson());
  }

  /// Get all custom sounds
  Future<List<CustomSound>> getCustomSounds() async {
    await init();
    final sounds = <CustomSound>[];
    
    for (final key in _box!.keys) {
      final json = _box!.get(key);
      if (json != null) {
        try {
          sounds.add(CustomSound.fromJson(Map<String, dynamic>.from(json)));
        } catch (e) {
          print('Error loading sound $key: $e');
        }
      }
    }
    
    // Sort by added date (newest first)
    sounds.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return sounds;
  }

  /// Delete a custom sound
  Future<void> deleteSound(String soundId) async {
    await init();
    
    // Get the sound to find its file path
    final json = _box!.get(soundId);
    if (json != null) {
      final sound = CustomSound.fromJson(Map<String, dynamic>.from(json));
      
      // Delete the file
      final file = File(sound.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    // Remove from storage
    await _box!.delete(soundId);
    print('🗑️ Custom sound deleted: $soundId');
  }

  /// Check if a sound file exists
  Future<bool> soundExists(String? soundPath) async {
    if (soundPath == null || soundPath.isEmpty) return false;
    
    // Check if it's a predefined sound
    if (soundPath.startsWith('assets/')) {
      return true; // Asset sounds always exist
    }
    
    // Check if the file exists
    final file = File(soundPath);
    return await file.exists();
  }

  /// Get the display name for a sound path
  Future<String> getSoundName(String? soundPath) async {
    if (soundPath == null || soundPath.isEmpty) {
      return 'Default';
    }
    
    // Check predefined sounds
    for (final sound in predefinedSounds) {
      if (sound.assetPath == soundPath) {
        return sound.name;
      }
    }
    
    // Check custom sounds
    final customSounds = await getCustomSounds();
    for (final sound in customSounds) {
      if (sound.filePath == soundPath) {
        return sound.name;
      }
    }
    
    // Fallback: extract name from path
    return soundPath.split('/').last.replaceAll(RegExp(r'\.[^\.]+$'), '');
  }
}
