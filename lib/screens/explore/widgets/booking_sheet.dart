import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/puja.dart';
import '../../../services/auth_service.dart';
import '../../../services/temple_service.dart';
import '../../../theme/app_colors.dart';
import '../../profile/bookings_screen.dart';

class BookingSheet extends StatefulWidget {
  final Puja puja;

  const BookingSheet({
    super.key,
    required this.puja,
  });

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gothraController = TextEditingController();
  final _sankalpController = TextEditingController();
  
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill user information if authenticated
    final user = context.read<AuthService>().currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _gothraController.dispose();
    _sankalpController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.gold,
              onPrimary: AppColors.bg,
              surface: Color(0xFF16121F),
              onSurface: AppColors.cream,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF0F0C16),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date for the Puja'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final templeService = context.read<TempleService>();
      final isMaintenance = await templeService.checkMaintenanceMode();
      if (isMaintenance) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('System is currently under maintenance. Payments and purchases are temporarily disabled.'),
              backgroundColor: AppColors.red,
            ),
          );
        }
        return;
      }

      final formattedDate = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
      final templeId = widget.puja.templeId?.id ?? '';
      
      final success = await context.read<TempleService>().bookPuja(
        pujaId: widget.puja.id,
        templeId: templeId,
        date: formattedDate,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        gothra: _gothraController.text.trim().isEmpty ? 'Kashyap' : _gothraController.text.trim(),
        sankalp: _sankalpController.text.trim().isEmpty ? 'For family wellbeing' : _sankalpController.text.trim(),
        price: widget.puja.price,
      );

      setState(() {
        _isLoading = false;
      });

      if (success) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF16121F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.green, size: 28),
                  SizedBox(width: 12),
                  Text('Puja Booked', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'Your booking for ${widget.puja.name} has been placed successfully! ',
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
            ),
          );

          await Future.delayed(const Duration(seconds: 2));

          if (!mounted) return;

          Navigator.of(context).popUntil((route) => route.isFirst);

          if (!mounted) return;

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PujaBookingsScreen(),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking failed: ${e.toString().replaceAll('ApiException: ', '')}'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const inputBorder = OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    const focusBorder = OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.gold),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F0C16),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              
              // Puja Summary Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    if (widget.puja.image.startsWith('http'))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(widget.puja.image, width: 56, height: 56, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.temple_hindu_outlined, color: AppColors.gold),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.puja.name,
                            style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.puja.templeId?.name ?? 'Temple',
                            style: const TextStyle(color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${widget.puja.price.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.puja.duration,
                          style: const TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              const Text(
                'BOOKING DETAILS',
                style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),

              // Name Field
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.cream, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Devotee Name',
                  labelStyle: TextStyle(color: AppColors.muted, fontSize: 12),
                  enabledBorder: inputBorder,
                  focusedBorder: focusBorder,
                  errorBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.red), borderRadius: BorderRadius.all(Radius.circular(12))),
                  focusedErrorBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.red), borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter devotee name' : null,
              ),
              const SizedBox(height: 14),

              // Phone Field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.cream, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Contact Phone',
                  labelStyle: TextStyle(color: AppColors.muted, fontSize: 12),
                  enabledBorder: inputBorder,
                  focusedBorder: focusBorder,
                  errorBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.red), borderRadius: BorderRadius.all(Radius.circular(12))),
                  focusedErrorBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.red), borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter contact phone' : null,
              ),
              const SizedBox(height: 14),

              // Gothra Field
              TextFormField(
                controller: _gothraController,
                style: const TextStyle(color: AppColors.cream, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Gothra (Optional, default: Kashyap)',
                  labelStyle: TextStyle(color: AppColors.muted, fontSize: 12),
                  enabledBorder: inputBorder,
                  focusedBorder: focusBorder,
                ),
              ),
              const SizedBox(height: 14),

              // Sankalp Field
              TextFormField(
                controller: _sankalpController,
                maxLines: 2,
                style: const TextStyle(color: AppColors.cream, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Sankalp / Purpose (Optional)',
                  labelStyle: TextStyle(color: AppColors.muted, fontSize: 12),
                  enabledBorder: inputBorder,
                  focusedBorder: focusBorder,
                ),
              ),
              const SizedBox(height: 16),

              // Date Picker Selector Button
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0C16),
                    border: Border.all(color: _selectedDate != null ? AppColors.gold : AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate == null 
                            ? 'Select Puja Date' 
                            : 'Date: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        style: TextStyle(
                          color: _selectedDate != null ? AppColors.gold : AppColors.muted,
                          fontSize: 14,
                          fontWeight: _selectedDate != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Icon(
                        Icons.calendar_month_rounded, 
                        color: _selectedDate != null ? AppColors.gold : AppColors.muted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.bg),
                          ),
                        )
                      : const Text(
                          'CONFIRM PUJA BOOKING',
                          style: TextStyle(
                            color: AppColors.bg,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }
}
