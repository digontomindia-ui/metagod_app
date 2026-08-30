import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../services/address_service.dart';
import '../../models/address.dart';
import 'add_edit_address_screen.dart';

class AddressesScreen extends StatefulWidget {
  final bool isSelectionMode;
  
  const AddressesScreen({super.key, this.isSelectionMode = false});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressService>().fetchAddresses();
    });
  }

  void _confirmDelete(BuildContext context, Address address) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete Address', style: TextStyle(color: AppColors.cream)),
        content: const Text('Are you sure you want to delete this address?', style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<AddressService>().deleteAddress(address.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting address: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final addressService = context.watch<AddressService>();
    final addresses = addressService.addresses;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.isSelectionMode ? 'Select Address' : 'Saved Addresses', style: const TextStyle(color: AppColors.cream)),
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),
      body: addressService.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : addressService.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(addressService.error!, style: const TextStyle(color: AppColors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => addressService.fetchAddresses(),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                        child: const Text('Retry', style: TextStyle(color: Colors.black)),
                      )
                    ],
                  ),
                )
              : addresses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off_outlined, size: 64, color: AppColors.muted.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            'No addresses found',
                            style: TextStyle(color: AppColors.cream, fontSize: 18),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: addresses.length,
                      itemBuilder: (context, index) {
                        final address = addresses[index];
                        return _buildAddressCard(address);
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEditAddressScreen()),
          );
        },
        backgroundColor: AppColors.gold,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Add New', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAddressCard(Address address) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: address.isDefault ? AppColors.gold : AppColors.border),
      ),
      child: InkWell(
        onTap: widget.isSelectionMode ? () {
          Navigator.pop(context, address);
        } : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    address.type.toLowerCase() == 'home' 
                        ? Icons.home_rounded 
                        : address.type.toLowerCase() == 'work' 
                            ? Icons.work_rounded 
                            : Icons.location_on_rounded,
                    color: AppColors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    address.type.toUpperCase(),
                    style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (address.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('DEFAULT', style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  if (!widget.isSelectionMode) ...[
                    PopupMenuButton(
                      icon: const Icon(Icons.more_vert, color: AppColors.muted),
                      color: AppColors.card,
                      itemBuilder: (context) => [
                        if (!address.isDefault)
                          const PopupMenuItem(
                            value: 'default',
                            child: Text('Set as Default', style: TextStyle(color: AppColors.cream)),
                          ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit', style: TextStyle(color: AppColors.cream)),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: TextStyle(color: AppColors.red)),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AddEditAddressScreen(address: address)),
                          );
                        } else if (value == 'delete') {
                          _confirmDelete(context, address);
                        } else if (value == 'default') {
                          try {
                            await context.read<AddressService>().setDefaultAddress(address.id);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to set default: $e')),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Text(address.name, style: const TextStyle(color: AppColors.cream, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(address.phone, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              Text(
                address.formattedAddress,
                style: const TextStyle(color: AppColors.muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
