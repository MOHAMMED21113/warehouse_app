// lib/modules/products/views/serial_numbers_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';

class SerialNumbersScreen extends ConsumerStatefulWidget {
  const SerialNumbersScreen({super.key});

  @override
  ConsumerState<SerialNumbersScreen> createState() => _SerialNumbersScreenState();
}

class _SerialNumbersScreenState extends ConsumerState<SerialNumbersScreen> {
  final _searchController = TextEditingController();
  Map<String, dynamic>? _foundSerial;
  bool _searched = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع الأرقام التسلسلية (Serial Numbers Tracking)'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'ابحث برقم السيريال (Serial Number / IMEI)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded, color: AppColors.primary),
                  onPressed: _searchSerial,
                ),
              ),
              onSubmitted: (_) => _searchSerial(),
            ),
            const SizedBox(height: 24),
            if (_searched && _foundSerial == null)
              const Center(child: Text('لم يتم العثور على أي منتج يحمل هذا الرقم التسلسلي', style: TextStyle(color: AppColors.error, fontSize: 16))),
            if (_foundSerial != null)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('المنتج: ${_foundSerial!['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: (_foundSerial!['is_sold'] == 1 ? AppColors.error : AppColors.success).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _foundSerial!['is_sold'] == 1 ? 'مباع' : 'متوفر بالمخزن',
                              style: TextStyle(color: _foundSerial!['is_sold'] == 1 ? AppColors.error : AppColors.success, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Text('السيريال: ${_foundSerial!['serial_number']}', style: const TextStyle(fontSize: 16)),
                      if (_foundSerial!['invoice_id'] != null)
                        Text('مرتبط بالفاتورة رقم: #${_foundSerial!['invoice_id']}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchSerial() async {
    final sn = _searchController.text.trim();
    if (sn.isEmpty) return;
    final db = ref.read(databaseHelperProvider);
    final res = await db.getProductBySerialNumber(sn);
    setState(() {
      _foundSerial = res;
      _searched = true;
    });
  }
}
