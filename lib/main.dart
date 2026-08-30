import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:convert';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatefulWidget {
  const DeliveryApp({super.key});

  @override
  State<DeliveryApp> createState() => _DeliveryAppState();
}

class _DeliveryAppState extends State<DeliveryApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تحویل بار و فروش',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('fa'),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: DeliveryScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  List<DeliveryItem> _currentItems = [];
  List<DeliveryItem> _filteredItems = [];
  List<Map<String, dynamic>> _manifestSearchResults = [];
  List<DeliveryManifest> _savedManifests = [];
  List<String> _smartLogs = [];
  List<ProductDatabaseItem> _productDatabase = [];
  List<SalesInvoice> _salesInvoices = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _purchasePriceController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _packageSizeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSearching = false;
  String _selectedUnit = 'عددی';
  bool _isLoading = false;
  bool _isPackageUnit = false;
  bool _isViewingManifest = false;
  DeliveryManifest? _viewingManifest;
  bool _isDarkMode = false;

  String _userEmail = 'rezagasem.82@gmail.com';
  String _userName = 'رضا گاسمی';

  @override
  void initState() {
    super.initState();
    _loadSavedManifests();
    _loadSmartLogs();
    _loadProductDatabase();
    _loadSalesInvoices();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _searchController.dispose();
    _barcodeController.dispose();
    _packageSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _userEmail = prefs.getString('user_email') ?? 'rezagasem.82@gmail.com';
      _userName = prefs.getString('user_name') ?? 'رضا گاسمی';
    });
  }

  String _formatNumber(String value) {
    if (value.isEmpty) return '';
    final number = int.tryParse(value.replaceAll(',', ''));
    if (number == null) return value;
    return number.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  String _formatPrice(int price) {
    return _formatNumber(price.toString());
  }

  int _convertPrice(String priceStr) {
    if (priceStr.isEmpty) return 0;
    final cleanPrice = int.tryParse(priceStr.replaceAll(',', ''));
    if (cleanPrice == null) return 0;
    return cleanPrice;
  }

  String _displayPrice(int price) {
    return '${_formatPrice(price)} ریال';
  }

  int _getNextManifestNumber() {
    return _savedManifests.length + 1;
  }

  int _getNextInvoiceNumber() {
    return _salesInvoices.length + 1;
  }

  Future<void> _scanBarcode({bool forSearchOnly = false}) async {
    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerScreen(),
        ),
      );

      if (!mounted) return;

      if (result != null && result.isNotEmpty) {
        if (forSearchOnly) {
          _searchController.text = result;
          _searchItems(result);
          _showBarcodeSearchResultDialog(result);
        } else {
          setState(() {
            _barcodeController.text = result;
          });

          final foundProduct = _productDatabase.firstWhere(
            (p) => p.barcode == result,
            orElse: () => ProductDatabaseItem(
                barcode: '', name: '', stock: 0, buyPrice: 0, sellPrice: 0),
          );

          if (foundProduct.barcode.isNotEmpty) {
            _nameController.text = foundProduct.name;
            _purchasePriceController.text = _formatPrice(foundProduct.buyPrice);
            _showSuccessMessage('کالا از بانک اطلاعاتی پیدا شد 🔍');
          } else {
            _showSuccessMessage('بارکد اسکن شد ✅');
          }
        }
      }
    } catch (e) {
      _showSuccessMessage('❌ خطا در اسکن بارکد');
    }
  }

  void _showBarcodeSearchResultDialog(String barcode) {
    final matches = _productDatabase.where((p) => p.barcode == barcode).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.qr_code_scanner, color: Colors.blue),
            SizedBox(width: 8),
            Text('نتیجه اسکن بارکد', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: matches.isEmpty
            ? Text('کالایی با بارکد $barcode در بانک اطلاعات پیدا نشد.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: matches.map((item) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📦 نام کالا: ${item.name}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('📊 موجودی: ${item.stock}',
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('🏷️ قیمت فروش: ${_displayPrice(item.sellPrice)}',
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.shopping_cart),
                          label: const Text('فروش این کالا'),
                          onPressed: () {
                            Navigator.pop(context);
                            _showSalesDialog(
                              productName: item.name,
                              productBarcode: item.barcode,
                              sellPrice: item.sellPrice,
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadProductDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString('product_database');
    if (dataStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(dataStr);
        setState(() {
          _productDatabase = decoded
              .map((item) => ProductDatabaseItem.fromJson(item))
              .toList();
        });
      } catch (e) {}
    }
  }

  Future<void> _saveProductDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    final dataJson = _productDatabase.map((p) => p.toJson()).toList();
    await prefs.setString('product_database', jsonEncode(dataJson));
  }

  void _openProductDatabaseScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDatabaseScreen(
          database: _productDatabase,
          onDatabaseUpdated: (updatedList) {
            setState(() {
              _productDatabase = updatedList;
            });
            _saveProductDatabase();
            _addSmartLog('🔄 بانک اطلاعاتی کالاها به‌روزرسانی شد');
          },
        ),
      ),
    );
  }

  Future<void> _loadSalesInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString('sales_invoices');
    if (dataStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(dataStr);
        setState(() {
          _salesInvoices = decoded
              .map((item) => SalesInvoice.fromJson(item))
              .toList();
        });
      } catch (e) {}
    }
  }

  Future<void> _saveSalesInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    final dataJson = _salesInvoices.map((p) => p.toJson()).toList();
    await prefs.setString('sales_invoices', jsonEncode(dataJson));
  }

  void _showSalesDialog({
    String? productName,
    String? productBarcode,
    int? sellPrice,
  }) {
    final nameCtrl = TextEditingController(text: productName ?? '');
    final barcodeCtrl = TextEditingController(text: productBarcode ?? '');
    final priceCtrl = TextEditingController(
        text: sellPrice != null ? _formatPrice(sellPrice) : '');
    final quantityCtrl = TextEditingController(text: '1');
    final customerNameCtrl = TextEditingController();
    final customerPhoneCtrl = TextEditingController();
    bool isCredit = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              '🧾 فاکتور فروش',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'نام کالا',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: barcodeCtrl,
                    decoration: InputDecoration(
                      labelText: 'بارکد',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceCtrl,
                    decoration: InputDecoration(
                      labelText: 'قیمت فروش (ریال)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final formatted = _formatNumber(value);
                      if (formatted != value) {
                        priceCtrl.value = TextEditingValue(
                          text: formatted,
                          selection:
                              TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: quantityCtrl,
                    decoration: InputDecoration(
                      labelText: 'تعداد',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: customerNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'نام مشتری (اختیاری)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: customerPhoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'شماره تماس مشتری (اختیاری)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isCredit,
                        onChanged: (value) {
                          setStateDialog(() {
                            isCredit = value ?? false;
                          });
                        },
                      ),
                      const Text('نسیه'),
                      const SizedBox(width: 16),
                      Text(
                        isCredit ? '🔴' : '🟢',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isCredit ? 'نسیه' : 'نقد',
                        style: TextStyle(
                          color: isCredit ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    _showSuccessMessage('❌ لطفاً نام کالا را وارد کنید');
                    return;
                  }

                  final price = _convertPrice(priceCtrl.text);
                  if (price <= 0) {
                    _showSuccessMessage('❌ لطفاً قیمت معتبر وارد کنید');
                    return;
                  }

                  final quantity = int.tryParse(quantityCtrl.text) ?? 1;
                  if (quantity <= 0) {
                    _showSuccessMessage('❌ تعداد باید بیشتر از صفر باشد');
                    return;
                  }

                  final invoice = SalesInvoice(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    number: _getNextInvoiceNumber(),
                    productName: name,
                    barcode: barcodeCtrl.text.trim(),
                    price: price,
                    quantity: quantity,
                    totalPrice: price * quantity,
                    customerName: customerNameCtrl.text.trim(),
                    customerPhone: customerPhoneCtrl.text.trim(),
                    isCredit: isCredit,
                    date: _getTodayDate(),
                    createdAt: DateTime.now().millisecondsSinceEpoch
                        .toString(),
                  );

                  setState(() {
                    _salesInvoices.add(invoice);
                  });
                  _saveSalesInvoices();
                  _addSmartLog(
                      '💰 فاکتور شماره ${invoice.number} ثبت شد - ${invoice.productName} x${invoice.quantity}');

                  final productIndex = _productDatabase.indexWhere(
                      (p) => p.barcode == invoice.barcode);
                  if (productIndex != -1) {
                    setState(() {
                      _productDatabase[productIndex] = ProductDatabaseItem(
                        barcode: _productDatabase[productIndex].barcode,
                        name: _productDatabase[productIndex].name,
                        stock: _productDatabase[productIndex].stock - quantity,
                        buyPrice: _productDatabase[productIndex].buyPrice,
                        sellPrice: _productDatabase[productIndex].sellPrice,
                      );
                    });
                    _saveProductDatabase();
                  }

                  Navigator.pop(context);
                  _showSuccessMessage(
                      '✅ فاکتور شماره ${invoice.number} ثبت شد');
                },
                child: const Text('ثبت فاکتور'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openSalesInvoicesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalesInvoicesScreen(
          invoices: _salesInvoices,
          onInvoiceDeleted: (invoiceId) {
            setState(() {
              _salesInvoices.removeWhere((inv) => inv.id == invoiceId);
            });
            _saveSalesInvoices();
            _addSmartLog('🗑️ فاکتور فروش حذف شد');
          },
          onInvoiceUpdated: (updatedInvoices) {
            setState(() {
              _salesInvoices = updatedInvoices;
            });
            _saveSalesInvoices();
          },
        ),
      ),
    );
  }

  void _openSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          isDarkMode: _isDarkMode,
          userEmail: _userEmail,
          userName: _userName,
          onSettingsChanged: (darkMode, email, name) {
            setState(() {
              _isDarkMode = darkMode;
              _userEmail = email;
              _userName = name;
            });
          },
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    OverlayEntry overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height / 2 - 60,
        left: MediaQuery.of(context).size.width / 2 - 120,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 240,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: message.contains('❌') || message.contains('خطا')
                  ? Colors.red.shade700
                  : Colors.green.shade700,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  message.contains('❌') || message.contains('خطا')
                      ? Icons.error_outline
                      : Icons.check_circle,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  void _addSmartLog(String message) {
    setState(() {
      final timestamp = DateTime.now();
      final time =
          '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
      _smartLogs.insert(0, '[$time] $message');
    });
    _saveSmartLogs();
  }

  Future<void> _loadSmartLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logsJson = prefs.getString('smart_logs');
    if (logsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(logsJson);
        setState(() {
          _smartLogs = decoded.map((item) => item.toString()).toList();
        });
      } catch (e) {}
    }
  }

  Future<void> _saveSmartLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('smart_logs', jsonEncode(_smartLogs));
  }

  void _clearSmartLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('پاک کردن گزارش هوشمند'),
        content:
            const Text('آیا از پاک کردن همه گزارش‌های هوشمند مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _smartLogs.clear();
              });
              _saveSmartLogs();
              Navigator.pop(context);
              _showSuccessMessage('گزارش‌ها پاک شدند 🗑️');
            },
            child: const Text('پاک کردن همه'),
          ),
        ],
      ),
    );
  }

  void _searchItems(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      _filteredItems.clear();
      _manifestSearchResults.clear();

      if (query.isEmpty) {
        _isSearching = false;
        return;
      }

      final searchTerm = query.toLowerCase().trim();

      final currentResults = _currentItems
          .where((item) =>
              item.name.toLowerCase().contains(searchTerm) ||
              item.barcode.contains(searchTerm))
          .toList();
      _filteredItems = currentResults;

      for (var manifest in _savedManifests) {
        for (var item in manifest.items) {
          if (item.name.toLowerCase().contains(searchTerm) ||
              item.barcode.contains(searchTerm)) {
            _manifestSearchResults.add({
              'manifest': manifest,
              'item': item,
            });
          }
        }
      }
    });
  }

  void _clearControllers() {
    _nameController.clear();
    _quantityController.clear();
    _purchasePriceController.clear();
    _barcodeController.clear();
    _packageSizeController.clear();
    setState(() {
      _selectedUnit = 'عددی';
      _isPackageUnit = false;
    });
  }

  void _showAddDialog({DeliveryManifest? targetManifest}) {
    _clearControllers();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          targetManifest != null
              ? 'افزودن کالا به بارنامه شماره ${targetManifest.number}'
              : 'اضافه کردن کالا',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _barcodeController,
                        decoration: InputDecoration(
                          labelText: 'شماره بارکد',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          hintText: 'اسکن یا دستی وارد کنید',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.camera_alt,
                          color: Colors.blue, size: 30),
                      onPressed: () => _scanBarcode(forSearchOnly: false),
                      tooltip: 'اسکن بارکد با دوربین',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'نام کالا',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفاً نام کالا را وارد کنید';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('واحد سنجش:'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'عددی', child: Text('عددی')),
                          DropdownMenuItem(
                              value: 'کیلویی', child: Text('کیلویی')),
                          DropdownMenuItem(
                              value: 'بسته‌ای', child: Text('بسته‌ای')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedUnit = value!;
                            _isPackageUnit = (value == 'بسته‌ای');
                            if (!_isPackageUnit) {
                              _packageSizeController.clear();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  decoration: InputDecoration(
                    labelText:
                        'تعداد (${_selectedUnit == 'بسته‌ای' ? 'بسته' : _selectedUnit})',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintText: _selectedUnit == 'بسته‌ای'
                        ? 'تعداد بسته‌ها'
                        : 'تعداد را وارد کنید',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفاً تعداد را وارد کنید';
                    }
                    if (int.tryParse(value) == null) {
                      return 'لطفاً یک عدد معتبر وارد کنید';
                    }
                    return null;
                  },
                ),
                if (_isPackageUnit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _packageSizeController,
                    decoration: InputDecoration(
                      labelText: 'تعداد داخل هر بسته (اختیاری)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText:
                          'مثلاً 10 - در صورت وارد نکردن، فقط بسته ثبت می‌شود',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _purchasePriceController,
                  decoration: InputDecoration(
                    labelText: 'قیمت خرید (ریال)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixText: 'ریال ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final formatted = _formatNumber(value);
                    if (formatted != value) {
                      _purchasePriceController.value = TextEditingValue(
                        text: formatted,
                        selection:
                            TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفاً قیمت خرید را وارد کنید';
                    }
                    final cleanValue = value.replaceAll(',', '');
                    if (int.tryParse(cleanValue) == null) {
                      return 'لطفاً یک عدد معتبر وارد کنید';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final newItem = DeliveryItem(
                  name: _nameController.text,
                  quantity: int.parse(_quantityController.text),
                  realQuantity: int.parse(_quantityController.text),
                  purchasePrice: _convertPrice(_purchasePriceController.text),
                  barcode: _barcodeController.text.isNotEmpty
                      ? _barcodeController.text
                      : DateTime.now().millisecondsSinceEpoch.toString(),
                  date: DateTime.now().millisecondsSinceEpoch.toString(),
                  unit: _selectedUnit,
                  packageSize: _packageSizeController.text.isNotEmpty
                      ? int.parse(_packageSizeController.text)
                      : 0,
                );

                if (targetManifest != null) {
                  setState(() {
                    targetManifest.items.add(newItem);
                    targetManifest.totalPrice +=
                        newItem.purchasePrice * newItem.realQuantity;
                  });
                  _addSmartLog(
                      '➕ کالا "${newItem.name}" به بارنامه شماره ${targetManifest.number} اضافه شد');
                  _saveManifestChanges(targetManifest);
                  Navigator.pop(context);
                  _showSuccessMessage('کالا اضافه شد ✅');
                } else {
                  setState(() {
                    _currentItems.add(newItem);
                    if (_searchController.text.isNotEmpty) {
                      _searchItems(_searchController.text);
                    }
                  });
                  _addSmartLog(
                      '✅ کالا "${_nameController.text}" با تعداد ${newItem.quantity} اضافه شد');
                  _clearControllers();
                  Navigator.pop(context);
                  _showSuccessMessage('کالا اضافه شد ✅');
                }
              }
            },
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      if (_isSearching && _filteredItems.isNotEmpty) {
        final itemToRemove = _filteredItems[index];
        _currentItems.remove(itemToRemove);
        _filteredItems.removeAt(index);
        if (_filteredItems.isEmpty) {
          _isSearching = false;
          _searchController.clear();
        }
      } else {
        _currentItems.removeAt(index);
      }
    });
  }

  int get _totalPurchasePrice {
    int total = 0;
    for (var item in _currentItems) {
      total += item.purchasePrice * item.realQuantity;
    }
    return total;
  }

  void _submitDelivery() async {
    final TextEditingController dateController = TextEditingController();
    dateController.text = _getTodayDate();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'ثبت نهایی تحویل بار',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لطفاً تاریخ بارنامه را وارد کنید:'),
            const SizedBox(height: 16),
            TextFormField(
              controller: dateController,
              decoration: InputDecoration(
                labelText: 'تاریخ (مثلاً ۱۴۰۴/۰۵/۱۵)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.calendar_today),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.green.shade100],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تعداد کالاها: ${_currentItems.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'مجموع قیمت: ${_displayPrice(_totalPurchasePrice)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'شماره بارنامه: ${_getNextManifestNumber()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final manifestDate = dateController.text.isEmpty
                  ? _getTodayDate()
                  : dateController.text;

              final manifest = DeliveryManifest(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                number: _getNextManifestNumber(),
                date: manifestDate,
                items: List.from(_currentItems),
                totalPrice: _totalPurchasePrice,
                createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
              );

              await _saveManifest(manifest);

              _addSmartLog(
                  '📋 بارنامه شماره ${manifest.number} با ${manifest.items.length} کالا ثبت شد');

              setState(() {
                _currentItems.clear();
                _filteredItems.clear();
                _searchController.clear();
                _isSearching = false;
              });

              Navigator.pop(context);
              _showSuccessMessage('بارنامه ثبت شد ✅');
            },
            child: const Text('ثبت نهایی'),
          ),
        ],
      ),
    );
  }

  String _getTodayDate() {
    final now = DateTime.now();
    final persianYear = now.year - 621;
    return '$persianYear/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveManifest(DeliveryManifest manifest) async {
    final prefs = await SharedPreferences.getInstance();
    final manifestsJson = _savedManifests.map((m) => m.toJson()).toList();
    manifestsJson.add(manifest.toJson());
    await prefs.setString('delivery_manifests', jsonEncode(manifestsJson));

    setState(() {
      _savedManifests.add(manifest);
    });
  }

  Future<void> _loadSavedManifests() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final manifestsJson = prefs.getString('delivery_manifests');

    if (manifestsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(manifestsJson);
        setState(() {
          _savedManifests =
              decoded.map((item) => DeliveryManifest.fromJson(item)).toList();
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startEditingManifest(DeliveryManifest manifest) {
    final dateController = TextEditingController(text: manifest.date);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'ویرایش بارنامه شماره ${manifest.number}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: dateController,
                    decoration: InputDecoration(
                      labelText: 'تاریخ بارنامه',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.edit_calendar),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'لیست کالاها:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.green),
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddDialog(targetManifest: manifest);
                        },
                        tooltip: 'افزودن کالا',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: manifest.items.length,
                      itemBuilder: (context, index) {
                        final item = manifest.items[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'تعداد: ${item.quantity} | ${_displayPrice(item.purchasePrice)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.red, size: 20),
                            onPressed: () {
                              setState(() {
                                final removedItem = manifest.items[index];
                                manifest.items.removeAt(index);
                                manifest.totalPrice -=
                                    removedItem.purchasePrice *
                                        removedItem.realQuantity;
                              });
                              setStateDialog(() {});
                              _addSmartLog(
                                  '❌ کالا "${item.name}" از بارنامه شماره ${manifest.number} حذف شد');
                              _saveManifestChanges(manifest);
                              _showSuccessMessage('کالا حذف شد ❌');
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final oldDate = manifest.date;
              final newDate = dateController.text;

              setState(() {
                manifest.date = newDate;
              });

              await _saveManifestChanges(manifest);

              if (oldDate != newDate) {
                _addSmartLog(
                    '📅 تاریخ بارنامه شماره ${manifest.number} از $oldDate به $newDate تغییر یافت');
              }

              Navigator.pop(context);
              _showSuccessMessage('تغییرات ذخیره شد ✅');
            },
            child: const Text('ذخیره تغییرات'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveManifestChanges(DeliveryManifest manifest) async {
    final prefs = await SharedPreferences.getInstance();
    final manifestsJson = _savedManifests.map((m) => m.toJson()).toList();
    await prefs.setString('delivery_manifests', jsonEncode(manifestsJson));
  }

  Future<void> _deleteManifest(DeliveryManifest manifest) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('حذف بارنامه شماره ${manifest.number}'),
        content: Text('آیا از حذف بارنامه تاریخ ${manifest.date} مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              setState(() {
                _savedManifests.remove(manifest);
              });

              final prefs = await SharedPreferences.getInstance();
              final manifestsJson =
                  _savedManifests.map((m) => m.toJson()).toList();
              await prefs.setString(
                  'delivery_manifests', jsonEncode(manifestsJson));

              _addSmartLog('🗑️ بارنامه شماره ${manifest.number} حذف شد');

              Navigator.pop(context);

              if (_isViewingManifest && _viewingManifest?.id == manifest.id) {
                setState(() {
                  _isViewingManifest = false;
                  _viewingManifest = null;
                });
              }

              _showSuccessMessage('بارنامه حذف شد 🗑️');
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _viewManifest(DeliveryManifest manifest) {
    setState(() {
      _viewingManifest = manifest;
      _isViewingManifest = true;
    });
  }

  void _goBackToMain() {
    setState(() {
      _isViewingManifest = false;
      _viewingManifest = null;
    });
  }

  void _cancelDelivery() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('لغو عملیات'),
        content: const Text(
            'آیا از لغو این محموله مطمئن هستید؟\nهمه کالاها حذف خواهند شد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              setState(() {
                _currentItems.clear();
                _filteredItems.clear();
                _searchController.clear();
                _isSearching = false;
              });
              _addSmartLog('❌ محموله لغو شد');
              Navigator.pop(context);
              _showSuccessMessage('محموله لغو شد ❌');
            },
            child: const Text('بله، لغو شود'),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartLogs() {
    if (_smartLogs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(
                'هیچ گزارشی موجود نیست',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '📊 گزارش هوشمند:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _clearSmartLogs,
              tooltip: 'پاک کردن گزارش‌ها',
            ),
          ],
        ),
        Container(
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ListView.builder(
            reverse: true,
            shrinkWrap: true,
            itemCount: _smartLogs.length,
            itemBuilder: (context, index) {
              final log = _smartLogs[index];
              final isSuccess = log.contains('✅');
              final isError = log.contains('❌') || log.contains('🗑️');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  log,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSuccess
                        ? Colors.green.shade700
                        : isError
                            ? Colors.red.shade700
                            : Colors.black87,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final searchDbMatches = _productDatabase.where((p) {
      final term = _searchController.text.toLowerCase().trim();
      return p.name.toLowerCase().contains(term) ||
          p.barcode.contains(term);
    }).toList();

    final totalResults = _filteredItems.length +
        _manifestSearchResults.length +
        searchDbMatches.length;

    if (totalResults == 0) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                '🔍 هیچ کالایی با این نام یا بارکد پیدا نشد',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '🔍 نتایج جستجو ($totalResults مورد):',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.blue,
              ),
            ),
          ),
          if (searchDbMatches.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '🗄️ از بانک اطلاعاتی کالاها:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            ...searchDbMatches.map((dbItem) => Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📦 نام کالا: ${dbItem.name}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('📊 موجودی: ${dbItem.stock}',
                          style: const TextStyle(fontSize: 13)),
                      Text('🏷️ قیمت فروش: ${_displayPrice(dbItem.sellPrice)}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                      if (dbItem.barcode.isNotEmpty)
                        Text('بارکد: ${dbItem.barcode}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                              ),
                              icon: const Icon(Icons.shopping_cart, size: 16),
                              label: const Text('فروش'),
                              onPressed: () {
                                _showSalesDialog(
                                  productName: dbItem.name,
                                  productBarcode: dbItem.barcode,
                                  sellPrice: dbItem.sellPrice,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
          ],
          if (_filteredItems.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '📦 کالاهای محموله جاری:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            ..._filteredItems
                .map((item) => _buildSearchResultItem(item, null)),
          ],
          if (_manifestSearchResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '📋 بارنامه‌های ذخیره شده:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            ..._manifestSearchResults.map((result) =>
                _buildManifestSearchResult(
                    result['manifest'], result['item'])),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(
      DeliveryItem item, DeliveryManifest? manifest) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.blue.shade700, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'تعداد: ${item.quantity}',
            style: const TextStyle(fontSize: 13),
          ),
          Text(
            'قیمت: ${_displayPrice(item.purchasePrice)}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            ),
            icon: const Icon(Icons.shopping_cart, size: 16),
            label: const Text('فروش'),
            onPressed: () {
              _showSalesDialog(
                productName: item.name,
                productBarcode: item.barcode,
                sellPrice: item.purchasePrice * 2,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManifestSearchResult(
      DeliveryManifest manifest, DeliveryItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: Colors.green.shade700, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بارنامه شماره ${manifest.number}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '📌 ${item.name} | تعداد: ${item.quantity}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            ),
            icon: const Icon(Icons.shopping_cart, size: 16),
            label: const Text('فروش'),
            onPressed: () {
              _showSalesDialog(
                productName: item.name,
                productBarcode: item.barcode,
                sellPrice: item.purchasePrice * 2,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: '🔍 جستجو (نام یا بارکد)',
                    hintText: 'جستجو در بارنامه‌ها و بانک کالا...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _isSearching = false;
                                _filteredItems.clear();
                                _manifestSearchResults.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: _searchItems,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.all(14),
                ),
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                onPressed: () => _scanBarcode(forSearchOnly: true),
                tooltip: 'جستجو با اسکن بارکد دوربین',
              ),
            ],
          ),
        ),
        _buildSmartLogs(),
        if (_isSearching)
          Expanded(
            child: _buildSearchResults(),
          )
        else
          Expanded(
            child: _currentItems.isEmpty && _savedManifests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'هیچ کالا یا بارنامه‌ای وجود ندارد',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'از دکمه‌های پایین برای مدیریت استفاده کنید',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _currentItems.isNotEmpty
                        ? _currentItems.length
                        : _savedManifests.length,
                    itemBuilder: (context, index) {
                      if (_currentItems.isNotEmpty) {
                        return _buildItemCard(index);
                      } else {
                        return GestureDetector(
                          onTap: () => _viewManifest(_savedManifests[index]),
                          child: _buildManifestCard(index),
                        );
                      }
                    },
                  ),
          ),
        if (!_isSearching)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('افزودن کالا'),
                    onPressed: () => _showAddDialog(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('فاکتور فروش'),
                    onPressed: () => _openSalesInvoicesScreen(),
                  ),
                ),
              ],
            ),
          ),
        if (_currentItems.isNotEmpty && !_isSearching) _buildBottomButtons(),
      ],
    );
  }

  Widget _buildItemCard(int index) {
    final item = _currentItems[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            '${(index + 1)}',
            style: TextStyle(color: Colors.blue.shade700),
          ),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.barcode.isNotEmpty)
              Text('بارکد: ${item.barcode}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text('واحد: ${item.unit}', style: const TextStyle(fontSize: 13)),
            Text(
                'تعداد: ${item.quantity}${item.packageSize > 0 ? ' (مجموع: ${item.realQuantity})' : ''}'),
            Text('قیمت خرید: ${_displayPrice(item.purchasePrice)}'),
            Text(
              'مجموع: ${_displayPrice(item.purchasePrice * item.realQuantity)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _removeItem(index),
        ),
      ),
    );
  }

  Widget _buildManifestCard(int index) {
    final manifest = _savedManifests[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Text(
            '${manifest.number}',
            style: TextStyle(color: Colors.green.shade700),
          ),
        ),
        title: Text(
          'بارنامه شماره ${manifest.number}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تاریخ: ${manifest.date}'),
            Text('تعداد کالاها: ${manifest.items.length}'),
            Text('مجموع: ${_displayPrice(manifest.totalPrice)}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.orange),
              onPressed: () => _startEditingManifest(manifest),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteManifest(manifest),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('مجموع قیمت خرید:',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  _displayPrice(_totalPurchasePrice),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _cancelDelivery,
                  child: const Text(
                    'لغو',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _submitDelivery,
                  child: const Text(
                    'ثبت نهایی',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManifestView() {
    final manifest = _viewingManifest!;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('شماره بارنامه:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${manifest.number}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تاریخ:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(manifest.date),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تعداد کالاها:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${manifest.items.length}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('مجموع قیمت:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_displayPrice(manifest.totalPrice),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: manifest.items.length,
            itemBuilder: (context, index) {
              final item = manifest.items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text('${index + 1}',
                        style: TextStyle(color: Colors.blue.shade700)),
                  ),
                  title: Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'تعداد: ${item.quantity}${item.packageSize > 0 ? ' (مجموع: ${item.realQuantity})' : ''}'),
                      Text('قیمت: ${_displayPrice(item.purchasePrice)}'),
                      Text(
                          'مجموع: ${_displayPrice(item.purchasePrice * item.realQuantity)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.shopping_cart, color: Colors.green),
                    onPressed: () {
                      _showSalesDialog(
                        productName: item.name,
                        productBarcode: item.barcode,
                        sellPrice: item.purchasePrice * 2,
                      );
                    },
                    tooltip: 'فروش',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isViewingManifest && _currentItems.isEmpty,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (_isViewingManifest) {
            _goBackToMain();
          } else if (_currentItems.isNotEmpty) {
            _cancelDelivery();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isViewingManifest
                ? 'بارنامه شماره ${_viewingManifest!.number}'
                : '📦 مدیریت تحویل بار و فروش',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.grey),
              tooltip: 'تنظیمات',
              onPressed: _openSettingsScreen,
            ),
            IconButton(
              icon: const Icon(Icons.storage_rounded, color: Colors.blue),
              tooltip: 'بانک اطلاعاتی کالاها',
              onPressed: _openProductDatabaseScreen,
            ),
            IconButton(
              icon: const Icon(Icons.receipt_long, color: Colors.green),
              tooltip: 'فاکتورهای فروش',
              onPressed: _openSalesInvoicesScreen,
            ),
            if (!_isViewingManifest) ...[
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'افزودن کالا',
                onPressed: () => _showAddDialog(),
              ),
            ],
            if (_isViewingManifest) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.orange),
                onPressed: () => _startEditingManifest(_viewingManifest!),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteManifest(_viewingManifest!),
              ),
            ],
          ],
          leading: _isViewingManifest
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBackToMain,
                )
              : null,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isViewingManifest
                ? _buildManifestView()
                : _buildMainView(),
      ),
    );
  }
}

// ==================== صفحه فاکتورهای فروش ====================

class SalesInvoicesScreen extends StatefulWidget {
  final List<SalesInvoice> invoices;
  final Function(String) onInvoiceDeleted;
  final Function(List<SalesInvoice>) onInvoiceUpdated;

  const SalesInvoicesScreen({
    super.key,
    required this.invoices,
    required this.onInvoiceDeleted,
    required this.onInvoiceUpdated,
  });

  @override
  State<SalesInvoicesScreen> createState() => _SalesInvoicesScreenState();
}

class _SalesInvoicesScreenState extends State<SalesInvoicesScreen> {
  List<SalesInvoice> _invoices = [];
  bool _showOnlyCredit = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _invoices = List.from(widget.invoices);
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  String _displayPrice(int price) {
    return '${_formatPrice(price)} ریال';
  }

  List<SalesInvoice> _getFilteredInvoices() {
    var filtered = _invoices;
    if (_showOnlyCredit) {
      filtered = filtered.where((inv) => inv.isCredit).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((inv) =>
          inv.productName.toLowerCase().contains(query) ||
          inv.barcode.contains(query) ||
          inv.customerName.toLowerCase().contains(query) ||
          inv.number.toString().contains(query)).toList();
    }
    return filtered;
  }

  void _deleteInvoice(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف فاکتور'),
        content: const Text('آیا از حذف این فاکتور مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              widget.onInvoiceDeleted(id);
              setState(() {
                _invoices.removeWhere((inv) => inv.id == id);
              });
              Navigator.pop(context);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredInvoices();
    final totalSales = filtered.fold<int>(0, (sum, inv) => sum + inv.totalPrice);
    final totalCredit = filtered
        .where((inv) => inv.isCredit)
        .fold<int>(0, (sum, inv) => sum + inv.totalPrice);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧾 فاکتورهای فروش'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () {
              _showSuccessMessage('⚠️ قابلیت PDF به زودی اضافه می‌شود');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: '🔍 جستجو در فاکتورها',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('نسیه'),
                  selected: _showOnlyCredit,
                  onSelected: (value) {
                    setState(() {
                      _showOnlyCredit = value;
                    });
                  },
                  avatar: _showOnlyCredit
                      ? const Icon(Icons.check, size: 16)
                      : null,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('تعداد فاکتورها',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('${filtered.length}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    const Text('مجموع فروش',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(_displayPrice(totalSales),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    const Text('مجموع نسیه',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(_displayPrice(totalCredit),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'هیچ فاکتوری یافت نشد',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final invoice = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                invoice.isCredit ? Colors.red : Colors.green,
                            child: Text(
                              '${invoice.number}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            invoice.productName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('بارکد: ${invoice.barcode}'),
                              Text('مشتری: ${invoice.customerName.isEmpty ? "نامشخص" : invoice.customerName}'),
                              Text('تعداد: ${invoice.quantity} | قیمت: ${_displayPrice(invoice.price)}'),
                              Text(
                                'مجموع: ${_displayPrice(invoice.totalPrice)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange),
                              ),
                              Text(
                                invoice.isCredit ? '🔴 نسیه' : '🟢 نقد',
                                style: TextStyle(
                                  color: invoice.isCredit ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('تاریخ: ${invoice.date}',
                                  style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _deleteInvoice(invoice.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('فاکتور جدید'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// ==================== صفحه تنظیمات ====================

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final String userEmail;
  final String userName;
  final Function(bool, String, String) onSettingsChanged;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.userEmail,
    required this.userName,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _darkMode;
  late TextEditingController _emailController;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.isDarkMode;
    _emailController = TextEditingController(text: widget.userEmail);
    _nameController = TextEditingController(text: widget.userName);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setString('user_email', _emailController.text);
    await prefs.setString('user_name', _nameController.text);
    widget.onSettingsChanged(_darkMode, _emailController.text, _nameController.text);
  }

  void _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'rezagasem.82@gmail.com',
      query: 'subject=پیشنهاد برای اپلیکیشن تحویل بار&body=سلام،%0A%0A',
    );
    try {
      await launchUrl(emailUri);
    } catch (e) {
      _showSnackbar('❌ خطا در باز کردن ایمیل');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ تنظیمات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await _saveSettings();
              _showSnackbar('✅ تنظیمات ذخیره شد');
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🌓 ظاهر',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('حالت تاریک (دارک مود)'),
                    subtitle: Text(_darkMode ? 'فعال' : 'غیرفعال'),
                    value: _darkMode,
                    onChanged: (value) {
                      setState(() {
                        _darkMode = value;
                      });
                    },
                    secondary: Icon(
                      _darkMode ? Icons.dark_mode : Icons.light_mode,
                      color: _darkMode ? Colors.white : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '👤 اطلاعات کاربر',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'نام کامل',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'ایمیل',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📧 ارتباط با ما',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.email, color: Colors.blue),
                    title: const Text('ارسال ایمیل'),
                    subtitle: const Text('rezagasem.82@gmail.com'),
                    onTap: _sendEmail,
                  ),
                  ListTile(
                    leading: const Icon(Icons.feedback, color: Colors.orange),
                    title: const Text('ارسال پیشنهاد'),
                    subtitle: const Text('نظرات و پیشنهادات خود را با ما به اشتراک بگذارید'),
                    onTap: _sendEmail,
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.apps, size: 48, color: Colors.blue),
                  const SizedBox(height: 8),
                  const Text(
                    'اپلیکیشن تحویل بار و فروش',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'نسخه 2.0.0',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'توسعه‌دهنده: رضا گاسمی',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '📧 rezagasem.82@gmail.com',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== صفحه بانک اطلاعاتی کالاها ====================

class ProductDatabaseScreen extends StatefulWidget {
  final List<ProductDatabaseItem> database;
  final Function(List<ProductDatabaseItem>) onDatabaseUpdated;

  const ProductDatabaseScreen({
    super.key,
    required this.database,
    required this.onDatabaseUpdated,
  });

  @override
  State<ProductDatabaseScreen> createState() => _ProductDatabaseScreenState();
}

class _ProductDatabaseScreenState extends State<ProductDatabaseScreen> {
  late List<ProductDatabaseItem> _items;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.database);
  }

  void _notifyUpdate() {
    widget.onDatabaseUpdated(_items);
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }

  void _showGuideDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('راهنمای فایل ورودی (اکسل / PDF)'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'جهت بارگذاری موفق فایل اکسل یا PDF، رعایت ساختار ستون‌ها الزامی است:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text('📌 ترتیب ستون‌های جدول به این صورت باشد:'),
              SizedBox(height: 8),
              Text('• ستون ۱ (A): شماره بارکد'),
              Text('• ستون ۲ (B): نام کالا'),
              Text('• ستون ۳ (C): تعداد موجودی'),
              Text('• ستون ۴ (D): قیمت خرید (ریال)'),
              Text('• ستون ۵ (E): قیمت فروش (ریال)'),
              SizedBox(height: 14),
              Text(
                'نکته: ردیف اول اکسل می‌تواند شامل تیتر ستون‌ها باشد. برنامه به‌طور خودکار اطلاعات را تبدیل و ذخیره می‌نماید.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('متوجه شدم'),
          ),
        ],
      ),
    );
  }

  Future<void> _importExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() {
        _isLoading = true;
      });

      final bytes = File(result.files.single.path!).readAsBytesSync();
      final excel = excel_lib.Excel.decodeBytes(bytes);

      int addedCount = 0;

      for (var table in excel.tables.keys) {
        final rows = excel.tables[table]?.rows;
        if (rows == null) continue;

        for (int i = 0; i < rows.length; i++) {
          final row = rows[i];
          if (row.length < 5) continue;

          final col0 = row[0]?.value?.toString().trim() ?? '';
          final col1 = row[1]?.value?.toString().trim() ?? '';

          if (col0.isEmpty && col1.isEmpty) continue;
          if (col0.contains('بارکد') || col1.contains('نام')) continue;

          final barcode = col0;
          final name = col1;
          final stock = int.tryParse(row[2]?.value?.toString() ?? '0') ?? 0;
          final buyPrice = int.tryParse(
                  row[3]?.value?.toString().replaceAll(',', '') ?? '0') ??
              0;
          final sellPrice = int.tryParse(
                  row[4]?.value?.toString().replaceAll(',', '') ?? '0') ??
              0;

          if (name.isNotEmpty) {
            _items.add(ProductDatabaseItem(
              barcode: barcode,
              name: name,
              stock: stock,
              buyPrice: buyPrice,
              sellPrice: sellPrice,
            ));
            addedCount++;
          }
        }
      }

      setState(() {
        _isLoading = false;
      });

      _notifyUpdate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$addedCount کالا با موفقیت از اکسل اضافه شد ✅')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در خواندن فایل اکسل ❌')),
      );
    }
  }

  Future<void> _importPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) return;

      setState(() {
        _isLoading = true;
      });

      // چون پکیج PDF حذف شده، پیام نمایش داده می‌شود
      _showSnackbar('⚠️ قابلیت وارد کردن PDF به زودی اضافه می‌شود');

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackbar('❌ خطا در خواندن فایل PDF');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showAddManualDialog() {
    final barcodeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final stockCtrl = TextEditingController();
    final buyCtrl = TextEditingController();
    final sellCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('افزودن دستی کالا به بانک'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: barcodeCtrl,
                  decoration: const InputDecoration(labelText: 'شماره بارکد (ستون ۱)'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'نام کالا (ستون ۲)'),
                  validator: (v) => v!.isEmpty ? 'نام کالا الزام است' : null,
                ),
                TextFormField(
                  controller: stockCtrl,
                  decoration: const InputDecoration(labelText: 'تعداد موجودی (ستون ۳)'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: buyCtrl,
                  decoration: const InputDecoration(labelText: 'قیمت خرید به ریال (ستون ۴)'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: sellCtrl,
                  decoration: const InputDecoration(labelText: 'قیمت فروش به ریال (ستون ۵)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _items.add(ProductDatabaseItem(
                    barcode: barcodeCtrl.text,
                    name: nameCtrl.text,
                    stock: int.tryParse(stockCtrl.text) ?? 0,
                    buyPrice: int.tryParse(buyCtrl.text.replaceAll(',', '')) ?? 0,
                    sellPrice: int.tryParse(sellCtrl.text.replaceAll(',', '')) ?? 0,
                  ));
                });
                _notifyUpdate();
                Navigator.pop(context);
                _showSnackbar('✅ کالا با موفقیت اضافه شد');
              }
            },
            child: const Text('ثبت'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🗄️ بانک اطلاعاتی کالاها'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.blue),
            tooltip: 'راهنمای ستون‌ها',
            onPressed: _showGuideDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'افزودن دستی',
            onPressed: _showAddManualDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.explicit),
                          label: const Text('ورود فایل اکسل'),
                          onPressed: _importExcel,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('ورود فایل PDF'),
                          onPressed: _importPdf,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.storage,
                                  size: 60, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('بانک اطلاعاتی خالی است'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _showGuideDialog,
                                child: const Text('مشاهده راهنمای ساختار فایل'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.purple.shade100,
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(item.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  'بارکد: ${item.barcode.isEmpty ? "ندارد" : item.barcode}\nموجودی: ${item.stock} | خرید: ${_formatPrice(item.buyPrice)} ریال',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('قیمت فروش:',
                                        style: TextStyle(fontSize: 10)),
                                    Text(
                                      '${_formatPrice(item.sellPrice)} ریال',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ==================== اسکنر بارکد ====================

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_scanned) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;

      if (value != null && value.isNotEmpty) {
        _scanned = true;
        _controller.stop();

        Navigator.pop(context, value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('اسکن بارکد'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 50,
            child: Text(
              'بارکد را داخل کادر قرار دهید',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== مدل‌های داده ====================

class ProductDatabaseItem {
  final String barcode;
  final String name;
  final int stock;
  final int buyPrice;
  final int sellPrice;

  ProductDatabaseItem({
    required this.barcode,
    required this.name,
    required this.stock,
    required this.buyPrice,
    required this.sellPrice,
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'name': name,
        'stock': stock,
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
      };

  factory ProductDatabaseItem.fromJson(Map<String, dynamic> json) =>
      ProductDatabaseItem(
        barcode: json['barcode'] ?? '',
        name: json['name'] ?? '',
        stock: json['stock'] ?? 0,
        buyPrice: json['buyPrice'] ?? 0,
        sellPrice: json['sellPrice'] ?? 0,
      );
}

class DeliveryItem {
  final String name;
  final int quantity;
  final int realQuantity;
  final int purchasePrice;
  final String barcode;
  final String date;
  final String unit;
  final int packageSize;

  DeliveryItem({
    required this.name,
    required this.quantity,
    required this.realQuantity,
    required this.purchasePrice,
    required this.barcode,
    required this.date,
    required this.unit,
    required this.packageSize,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'realQuantity': realQuantity,
        'purchasePrice': purchasePrice,
        'barcode': barcode,
        'date': date,
        'unit': unit,
        'packageSize': packageSize,
      };

  factory DeliveryItem.fromJson(Map<String, dynamic> json) => DeliveryItem(
        name: json['name'],
        quantity: json['quantity'],
        realQuantity: json['realQuantity'] ?? json['quantity'],
        purchasePrice: json['purchasePrice'] ?? 0,
        barcode: json['barcode'],
        date: json['date'],
        unit: json['unit'] ?? 'عددی',
        packageSize: json['packageSize'] ?? 0,
      );
}

class DeliveryManifest {
  String id;
  int number;
  String date;
  List<DeliveryItem> items;
  int totalPrice;
  String createdAt;

  DeliveryManifest({
    required this.id,
    required this.number,
    required this.date,
    required this.items,
    required this.totalPrice,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'date': date,
        'items': items.map((item) => item.toJson()).toList(),
        'totalPrice': totalPrice,
        'createdAt': createdAt,
      };

  factory DeliveryManifest.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List)
        .map((item) => DeliveryItem.fromJson(item))
        .toList();
    return DeliveryManifest(
      id: json['id'],
      number: json['number'] ?? 0,
      date: json['date'],
      items: itemsList,
      totalPrice: json['totalPrice'],
      createdAt: json['createdAt'],
    );
  }
}

class SalesInvoice {
  final String id;
  final int number;
  final String productName;
  final String barcode;
  final int price;
  final int quantity;
  final int totalPrice;
  final String customerName;
  final String customerPhone;
  final bool isCredit;
  final String date;
  final String createdAt;

  SalesInvoice({
    required this.id,
    required this.number,
    required this.productName,
    required this.barcode,
    required this.price,
    required this.quantity,
    required this.totalPrice,
    required this.customerName,
    required this.customerPhone,
    required this.isCredit,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'productName': productName,
        'barcode': barcode,
        'price': price,
        'quantity': quantity,
        'totalPrice': totalPrice,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'isCredit': isCredit,
        'date': date,
        'createdAt': createdAt,
      };

  factory SalesInvoice.fromJson(Map<String, dynamic> json) => SalesInvoice(
        id: json['id'],
        number: json['number'] ?? 0,
        productName: json['productName'] ?? '',
        barcode: json['barcode'] ?? '',
        price: json['price'] ?? 0,
        quantity: json['quantity'] ?? 0,
        totalPrice: json['totalPrice'] ?? 0,
        customerName: json['customerName'] ?? '',
        customerPhone: json['customerPhone'] ?? '',
        isCredit: json['isCredit'] ?? false,
        date: json['date'] ?? '',
        createdAt: json['createdAt'] ?? '',
      );
}