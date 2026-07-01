// lib/modules/products/views/barcode_scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/global_providers.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  final Function(String) onBarcodeScanned;
  final bool searchInDatabase; // 🚀 الحل النهائي: تحديد هل نبحث في القاعدة أم نكتفي بالقراءة

  const BarcodeScannerScreen({
    super.key,
    required this.onBarcodeScanned,
    this.searchInDatabase = true, // افتراضياً يبحث (لشاشات البيع والمشتريات)
  });

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _isInitialized = false;
  bool _isTorchOn = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _controller?.stop();
        break;
      case AppLifecycleState.resumed:
        _controller?.start();
        break;
      default:
        break;
    }
  }

  void _initScanner() {
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    setState(() => _isInitialized = true);
  }

  // ==================== المعالجة عند التقاط الباركود ====================
  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;

    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      setState(() => _isProcessing = true);
      final code = barcodes.first.rawValue!;

      // 1. إيقاف الكاميرا مؤقتاً
      _controller?.stop();

      // 🚀 الحل النهائي: إذا طلبنا عدم البحث (كما في شاشة التعديل)، نعيد الرقم ونغلق فوراً!
      if (!widget.searchInDatabase) {
        Navigator.pop(context); // إغلاق شاشة الماسح
        widget.onBarcodeScanned(code); // إرسال الرقم للحقل النصي
        return;
      }

      // 2. البحث عن المنتج في قاعدة البيانات (خاص بشاشات الفواتير والبيع)
      final db = ref.read(databaseHelperProvider);
      final product = await db.searchProductByAnyBarcode(code);

      if (!mounted) return;

      // 3. إظهار نافذة التفاصيل
      if (product != null) {
        _showProductDetails(product, code);
      } else {
        _showNotFound(code); // 👈 هذه النافذة ذات علامة التعجب التي ظهرت لك
      }
    }
  }

  // ==================== نافذة المنتج الموجود ====================
  void _showProductDetails(Map<String, dynamic> product, String code) {
    final stock = (product['current_stock'] as num?)?.toInt() ?? 0;
    final price = (product['unit_price'] as num?)?.toDouble() ?? 0.0;
    final unitName = product['unit_name']?.toString() ?? '';
    final productName = product['name']?.toString() ?? 'منتج غير معروف';

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF12213A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFFD4AF37), width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFFD4AF37), size: 36),
            ),
            const SizedBox(height: 16),
            Text(productName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('الباركود: $code', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _infoBox('الكمية المتوفرة', '$stock $unitName', Icons.inventory_2_rounded, const Color(0xFF3B82F6))),
                const SizedBox(width: 12),
                Expanded(child: _infoBox('سعر البيع', '$price ريال', Icons.sell_rounded, const Color(0xFF10B981))),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () { Navigator.pop(sheetContext); _controller?.start(); setState(() => _isProcessing = false); },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('مسح آخر', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(sheetContext); Navigator.pop(context); widget.onBarcodeScanned(code); },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: AppColors.navy, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('تأكيد واستخدام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== نافذة المنتج غير الموجود ====================
  void _showNotFound(String code) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF12213A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.redAccent, width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('المنتج غير مسجل', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('الباركود: $code', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () { Navigator.pop(sheetContext); _controller?.start(); setState(() => _isProcessing = false); },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('إلغاء وإعادة المسح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(sheetContext); Navigator.pop(context); widget.onBarcodeScanned(code); },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('استخدام الكود (منتج جديد)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(children: [Icon(icon, color: color, size: 24), const SizedBox(height: 8), FittedBox(child: Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold))), const SizedBox(height: 4), Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11))]),
    );
  }

  void _toggleTorch() {
    _controller?.toggleTorch();
    setState(() => _isTorchOn = !_isTorchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: AppColors.navy, foregroundColor: AppColors.primary, elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primary), onPressed: () => Navigator.pop(context)),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)), const SizedBox(width: 8),
          const Text('ماسح الباركود', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 17)),
        ]),
        actions: [IconButton(icon: Icon(_isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: _isTorchOn ? AppColors.primary : Colors.white54), onPressed: _toggleTorch, tooltip: 'الفلاش')],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(2), child: Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.navy, AppColors.primary.withOpacity(0.6), AppColors.navy])))),
      ),
      body: _isInitialized && _controller != null
          ? Stack(children: [
        MobileScanner(controller: _controller!, onDetect: _onDetect),
        _buildScanOverlay(context),
        Positioned(bottom: 80, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: AppColors.navy.withOpacity(0.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withOpacity(0.3))), child: const Text('وجّه الكاميرا نحو الباركود', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))))),
      ])
          : const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))),
    );
  }

  Widget _buildScanOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaSize = size.width * 0.7;
    return Stack(children: [
      ColorFiltered(colorFilter: ColorFilter.mode(AppColors.navy.withOpacity(0.6), BlendMode.srcOut), child: Stack(children: [Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)), Center(child: Container(width: scanAreaSize, height: scanAreaSize, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20))))])),
      Center(child: Container(width: scanAreaSize, height: scanAreaSize, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withOpacity(0.6), width: 2)), child: Stack(children: [..._buildCorners(scanAreaSize)]))),
    ]);
  }

  List<Widget> _buildCorners(double size) {
    const cornerLength = 30.0; const cornerWidth = 3.0; const color = AppColors.primary; const radius = Radius.circular(20);
    return [
      Positioned(top: 0, left: 0, child: Container(width: cornerLength, height: cornerWidth, decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.only(topLeft: radius)))), Positioned(top: 0, left: 0, child: Container(width: cornerWidth, height: cornerLength, decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.only(topLeft: radius)))),
      Positioned(top: 0, right: 0, child: Container(width: cornerLength, height: cornerWidth, decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.only(topRight: radius)))), Positioned(top: 0, right: 0, child: Container(width: cornerWidth, height: cornerLength, decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.only(topRight: radius)))),
      Positioned(bottom: 0, left: 0, child: Container(width: cornerLength, height: cornerWidth, decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.only(bottomLeft: radius)))), Positioned(bottom: 0, left: 0, child: Container(width: cornerWidth, height: cornerLength, decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.only(bottomLeft: radius)))),
      Positioned(bottom: 0, right: 0, child: Container(width: cornerLength, height: cornerWidth, decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.only(bottomRight: radius)))), Positioned(bottom: 0, right: 0, child: Container(width: cornerWidth, height: cornerLength, decoration: const BoxDecoration(color: color, borderRadius: BorderRadius.only(bottomRight: radius)))),
    ];
  }
}