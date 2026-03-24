// lib/screens/personal_info_screen.dart
import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class PersonalInfoScreen extends StatefulWidget {
  final ApiService api;

  const PersonalInfoScreen({super.key, required this.api});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  bool _isLoading = true;
  bool _isSaving  = false;

  final _nameCtrl       = TextEditingController();
  final _fatherCtrl     = TextEditingController();
  final _motherCtrl     = TextEditingController();
  final _dobCtrl        = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _addressCtrl    = TextEditingController();
  final _districtCtrl   = TextEditingController();
  final _stateCtrl      = TextEditingController();
  final _pincodeCtrl    = TextEditingController();
  final _aadharCtrl     = TextEditingController();

  String? _selectedGender;
  String? _selectedCategory;

  static const _genders    = ['Male', 'Female', 'Other'];
  static const _categories = ['General', 'OBC', 'OBC-NCL', 'SC', 'ST', 'EWS'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await widget.api.getPersonalInfo();
    _nameCtrl.text     = info.name;
    _fatherCtrl.text   = info.fatherName;
    _motherCtrl.text   = info.motherName;
    _dobCtrl.text      = info.dob;
    _phoneCtrl.text    = info.phone;
    _emailCtrl.text    = info.email;
    _addressCtrl.text  = info.address;
    _districtCtrl.text = info.district;
    _stateCtrl.text    = info.state;
    _pincodeCtrl.text  = info.pincode;
    _aadharCtrl.text   = info.aadharLast4;
    setState(() {
      _selectedGender   = info.gender.isNotEmpty   ? info.gender   : null;
      _selectedCategory = info.category.isNotEmpty ? info.category : null;
      _isLoading        = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final info = PersonalInfo(
      name:        _nameCtrl.text.trim(),
      fatherName:  _fatherCtrl.text.trim(),
      motherName:  _motherCtrl.text.trim(),
      dob:         _dobCtrl.text.trim(),
      gender:      _selectedGender   ?? '',
      category:    _selectedCategory ?? '',
      phone:       _phoneCtrl.text.trim(),
      email:       _emailCtrl.text.trim(),
      address:     _addressCtrl.text.trim(),
      district:    _districtCtrl.text.trim(),
      state:       _stateCtrl.text.trim(),
      pincode:     _pincodeCtrl.text.trim(),
      aadharLast4: _aadharCtrl.text.trim(),
    );
    await widget.api.savePersonalInfo(info);
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Details save ho gayi!', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _fatherCtrl, _motherCtrl, _dobCtrl, _phoneCtrl,
        _emailCtrl, _addressCtrl, _districtCtrl, _stateCtrl, _pincodeCtrl, _aadharCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A6B3C), Color(0xFF0D4A28)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Form Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('Form bharne ke liye apni details', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPrivacyNote(),
                  const SizedBox(height: 16),
                  _buildSection('👤 Personal Details', [
                    _buildField('Poora Naam', _nameCtrl, hint: 'Jaise aadhar card mein hai', icon: Icons.person_rounded),
                    _buildField("Pita Ka Naam", _fatherCtrl, hint: "Father's name", icon: Icons.family_restroom_rounded),
                    _buildField("Mata Ka Naam", _motherCtrl, hint: "Mother's name", icon: Icons.family_restroom_rounded),
                    _buildField('Date of Birth', _dobCtrl, hint: 'DD/MM/YYYY', icon: Icons.cake_rounded, keyboard: TextInputType.datetime),
                    _buildDropdown('Gender', _genders, _selectedGender, (v) => setState(() => _selectedGender = v), Icons.wc_rounded),
                    _buildDropdown('Category', _categories, _selectedCategory, (v) => setState(() => _selectedCategory = v), Icons.badge_rounded),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('📞 Contact Details', [
                    _buildField('Mobile Number', _phoneCtrl, hint: '10-digit number', icon: Icons.phone_rounded, keyboard: TextInputType.phone),
                    _buildField('Email Address', _emailCtrl, hint: 'example@email.com', icon: Icons.email_rounded, keyboard: TextInputType.emailAddress),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('🏠 Address', [
                    _buildField('Full Address', _addressCtrl, hint: 'House no., Street, Mohalla', icon: Icons.home_rounded, maxLines: 2),
                    _buildField('District', _districtCtrl, hint: 'Jile ka naam', icon: Icons.location_city_rounded),
                    _buildField('State', _stateCtrl, hint: 'Rajya ka naam', icon: Icons.map_rounded),
                    _buildField('Pin Code', _pincodeCtrl, hint: '6-digit PIN', icon: Icons.pin_drop_rounded, keyboard: TextInputType.number),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('🪪 Identity (Optional)', [
                    _buildField('Aadhar Last 4 Digits', _aadharCtrl,
                        hint: 'Sirf last 4 digits (reference ke liye)',
                        icon: Icons.credit_card_rounded,
                        keyboard: TextInputType.number,
                        maxLength: 4),
                  ]),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Save Karo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_rounded, color: AppColors.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Yeh details sirf aapke phone pe save hoti hain. Koi bhi server pe nahi jaati.',
              style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> fields) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 14),
          ...fields,
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    String hint = '',
    IconData icon = Icons.edit_rounded,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value,
      ValueChanged<String?> onChanged, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text('Select $label'),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        ),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
