import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../consultation/widgets/pandit_card.dart';

class SavedPanditsScreen extends StatefulWidget {
  const SavedPanditsScreen({super.key});

  @override
  State<SavedPanditsScreen> createState() => _SavedPanditsScreenState();
}

class _SavedPanditsScreenState extends State<SavedPanditsScreen> {
  List<Map<String, dynamic>> _savedPandits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPandits();
  }

  Future<void> _loadSavedPandits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDataList = prefs.getStringList('saved_pandits_data') ?? [];
      
      final List<Map<String, dynamic>> loadedList = [];
      for (String item in savedDataList) {
        try {
          loadedList.add(Map<String, dynamic>.from(jsonDecode(item)));
        } catch (e) {
          // Ignore invalid JSON
        }
      }
      
      if (mounted) {
        setState(() {
          _savedPandits = loadedList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.cream, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Saved Pandits',
          style: TextStyle(
            color: AppColors.cream,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _savedPandits.isEmpty
              ? const Center(
                  child: Text(
                    'You have no saved pandits yet.',
                    style: TextStyle(color: AppColors.muted, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: _savedPandits.length,
                  itemBuilder: (context, index) {
                    final expert = _savedPandits[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: PanditCard(expert: expert),
                    );
                  },
                ),
    );
  }
}
