import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../services/address_service.dart';
import '../../models/address.dart';

class AddEditAddressScreen extends StatefulWidget {
  final Address? address;

  const AddEditAddressScreen({super.key, this.address});

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _houseNoController;
  late TextEditingController _areaController;
  late TextEditingController _landmarkController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  
  String _type = 'Home';
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.address?.name ?? '');
    _phoneController = TextEditingController(text: widget.address?.phone ?? '');
    _houseNoController = TextEditingController(text: widget.address?.houseNo ?? '');
    _areaController = TextEditingController(text: widget.address?.area ?? '');
    _landmarkController = TextEditingController(text: widget.address?.landmark ?? '');
    _cityController = TextEditingController(text: widget.address?.city ?? '');
    _stateController = TextEditingController(text: widget.address?.state ?? '');
    _pincodeController = TextEditingController(text: widget.address?.pincode ?? '');
    
    _type = widget.address?.type ?? 'Home';
    _isDefault = widget.address?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _houseNoController.dispose();
    _areaController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final address = Address(
      id: widget.address?.id ?? '',
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      houseNo: _houseNoController.text.trim(),
      area: _areaController.text.trim(),
      landmark: _landmarkController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      type: _type,
      isDefault: _isDefault,
    );

    try {
      if (widget.address == null) {
        await context.read<AddressService>().addAddress(address);
      } else {
        await context.read<AddressService>().updateAddress(address);
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.address == null ? 'Add New Address' : 'Edit Address', style: const TextStyle(color: AppColors.cream)),
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Contact Information', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline,
              validator: (v) => v!.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Phone is required' : null,
            ),
            
            const SizedBox(height: 24),
            const Text('Address Details', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _houseNoController,
                    label: 'House / Flat No',
                    icon: Icons.door_front_door_outlined,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _areaController,
                    label: 'Area / Street',
                    icon: Icons.streetview_outlined,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _landmarkController,
              label: 'Landmark (Optional)',
              icon: Icons.flag_outlined,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _cityController,
                    label: 'City',
                    icon: Icons.location_city_outlined,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _stateController,
                    label: 'State',
                    icon: Icons.map_outlined,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _pincodeController,
              label: 'Pincode',
              icon: Icons.pin_drop_outlined,
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            
            const SizedBox(height: 24),
            const Text('Address Type', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: ['Home', 'Work', 'Other'].map((type) {
                final isSelected = _type == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = type),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.gold.withValues(alpha: 0.1) : Colors.transparent,
                        border: Border.all(color: isSelected ? AppColors.gold : AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        type,
                        style: TextStyle(
                          color: isSelected ? AppColors.gold : AppColors.muted,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            if (widget.address?.isDefault != true)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as Default Address', style: TextStyle(color: AppColors.cream)),
                value: _isDefault,
                activeColor: AppColors.gold,
                checkColor: Colors.black,
                onChanged: (val) => setState(() => _isDefault = val ?? false),
              ),

            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'SAVE ADDRESS',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.cream),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.muted),
        prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.02),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      ),
    );
  }
}
