import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/custom_sound_service.dart';

class SoundPickerScreen extends StatefulWidget {
  final String? currentSoundPath;

  const SoundPickerScreen({
    super.key,
    this.currentSoundPath,
  });

  @override
  State<SoundPickerScreen> createState() => _SoundPickerScreenState();
}

class _SoundPickerScreenState extends State<SoundPickerScreen> {
  final CustomSoundService _soundService = CustomSoundService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<CustomSound> _customSounds = [];
  String? _selectedSoundPath;
  String? _playingSoundPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedSoundPath = widget.currentSoundPath ?? CustomSoundService.predefinedSounds.first.assetPath;
    _loadSounds();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSounds() async {
    setState(() => _isLoading = true);
    
    final sounds = await _soundService.getCustomSounds();
    
    if (mounted) {
      setState(() {
        _customSounds = sounds;
        _isLoading = false;
      });
    }
  }

  Future<void> _playSound(String soundPath, {bool isAsset = false}) async {
    try {
      await _audioPlayer.stop();
      
      if (_playingSoundPath == soundPath) {
        setState(() => _playingSoundPath = null);
        return;
      }
      
      if (isAsset) {
        await _audioPlayer.play(AssetSource(soundPath.replaceFirst('assets/', '')));
      } else {
        await _audioPlayer.play(DeviceFileSource(soundPath));
      }
      
      setState(() => _playingSoundPath = soundPath);
      
      // Stop after 3 seconds (preview)
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _playingSoundPath == soundPath) {
          _audioPlayer.stop();
          setState(() => _playingSoundPath = null);
        }
      });
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  Future<void> _addCustomSound() async {
    try {
      final newSound = await _soundService.pickAndSaveSound();
      
      if (newSound != null) {
        await _loadSounds();
        
        // Select the new sound
        setState(() {
          _selectedSoundPath = newSound.filePath;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "${newSound.name}"'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error adding custom sound: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add sound: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteSound(CustomSound sound) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Sound'),
        content: Text('Are you sure you want to delete "${sound.name}"?'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _soundService.deleteSound(sound.id);
      
      // If this was the selected sound, reset to default
      if (_selectedSoundPath == sound.filePath) {
        _selectedSoundPath = CustomSoundService.predefinedSounds.first.assetPath;
      }
      
      await _loadSounds();
    }
  }

  void _selectSound(String soundPath) {
    setState(() {
      _selectedSoundPath = soundPath;
    });
  }

  void _confirm() {
    _audioPlayer.stop();
    Navigator.pop(context, _selectedSoundPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        leading: TextButton(
          onPressed: () {
            _audioPlayer.stop();
            Navigator.pop(context);
          },
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 17,
            ),
          ),
        ),
        title: const Text(
          'Alarm Sound',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text(
              'Done',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              children: [
                const SizedBox(height: 20),
                
                // Predefined Sounds Section
                _buildSectionHeader('RINGTONES'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: CustomSoundService.predefinedSounds.asMap().entries.map((entry) {
                      final index = entry.key;
                      final sound = entry.value;
                      final isSelected = _selectedSoundPath == sound.assetPath;
                      final isPlaying = _playingSoundPath == sound.assetPath;
                      
                      return Column(
                        children: [
                          if (index > 0)
                            const Divider(height: 1, color: Color(0xFF3A3A3C), indent: 56),
                          _buildSoundTile(
                            emoji: sound.emoji,
                            name: sound.name,
                            isSelected: isSelected,
                            isPlaying: isPlaying,
                            onTap: () => _selectSound(sound.assetPath),
                            onPlay: () => _playSound(sound.assetPath, isAsset: true),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 30),

                // Custom Sounds Section
                _buildSectionHeader('MY SOUNDS'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // Add sound button
                      _buildAddSoundTile(),
                      
                      // Custom sounds list
                      ..._customSounds.asMap().entries.map((entry) {
                        final sound = entry.value;
                        final isSelected = _selectedSoundPath == sound.filePath;
                        final isPlaying = _playingSoundPath == sound.filePath;
                        
                        return Column(
                          children: [
                            const Divider(height: 1, color: Color(0xFF3A3A3C), indent: 56),
                            _buildSoundTile(
                              emoji: '🎵',
                              name: sound.name,
                              isSelected: isSelected,
                              isPlaying: isPlaying,
                              onTap: () => _selectSound(sound.filePath),
                              onPlay: () => _playSound(sound.filePath),
                              onDelete: () => _deleteSound(sound),
                              isCustom: true,
                            ),
                          ],
                        );
                      }),
                      
                      if (_customSounds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No custom sounds yet.\nTap + to add your own.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAddSoundTile() {
    return InkWell(
      onTap: _addCustomSound,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                CupertinoIcons.add,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Add Custom Sound',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundTile({
    required String emoji,
    required String name,
    required bool isSelected,
    required bool isPlaying,
    required VoidCallback onTap,
    required VoidCallback onPlay,
    VoidCallback? onDelete,
    bool isCustom = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Checkmark or emoji
            SizedBox(
              width: 32,
              child: isSelected
                  ? const Icon(
                      CupertinoIcons.checkmark,
                      color: AppTheme.primary,
                      size: 22,
                    )
                  : Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            
            // Sound name
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected ? AppTheme.primary : Colors.white,
                  fontSize: 17,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Play button
            IconButton(
              onPressed: onPlay,
              icon: Icon(
                isPlaying
                    ? CupertinoIcons.stop_circle
                    : CupertinoIcons.play_circle,
                color: isPlaying ? AppTheme.primary : AppTheme.textSecondary,
                size: 28,
              ),
            ),
            
            // Delete button (only for custom sounds)
            if (isCustom && onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  CupertinoIcons.trash,
                  color: AppTheme.error,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
