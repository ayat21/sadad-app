import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:multi_select_flutter/util/multi_select_list_type.dart';
import 'package:sadadet/users_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'addClientScreen.dart';
import 'edit_client_screen.dart';
import 'upload_excel_screen.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';



class HomeScreen extends StatefulWidget {
  final String username;
  final String role; // admin أو manfaz
  final String? manfazName;

  const HomeScreen({
    super.key,
    required this.username,
    required this.role,
    this.manfazName,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  String? selectedPaymentStatus;
  Set<String> copiedNumbers = {};
  void _toggleCopyNumber(String number) {
    setState(() {
      if (copiedNumbers.contains(number)) {
        copiedNumbers.remove(number);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ تم إزالة الرقم: $number')),
        );
      } else {
        copiedNumbers.add(number);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ تم نسخ الرقم: $number')),
        );
      }

      // تحديث النسخ في الكليب بورد
      final fullText = copiedNumbers.join('\n');
      Clipboard.setData(ClipboardData(text: fullText));
    });
  }

  String searchQuery = '';
  late Query<Map<String, dynamic>> query;

  // متغيرات الفلترة
  String? selectedManfaz;
  String? selectedProvider;
  DateTimeRange? selectedDateRange;

  List<String> manfazOptions = [];
  List<String> selectedManfez = [];

  Future<void> fetchManfazOptions() async {
    final snapshot = await FirebaseFirestore.instance.collection('clients').get();
    final manfazSet = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['manfaz'] != null && data['manfaz'].toString().isNotEmpty) {
        manfazSet.add(data['manfaz']);
      }
    }
    setState(() {
      manfazOptions = manfazSet.toList();
    });
  }

  @override
  void initState() {
    super.initState();
    query = _buildQuery();
    fetchManfazOptions();
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> baseQuery =
    FirebaseFirestore.instance.collection('clients');

    if (selectedProvider != null && selectedProvider!.isNotEmpty) {
      baseQuery = baseQuery.where('provider', isEqualTo: selectedProvider);
    } // 1. فلترة حسب المنفذ (لو موجود)
    //   لو role == manfaz، خلي الفلتر على المنفذ اللي دخل بيه اليوزر (widget.manfazName)
    //   لو admin واخترت منفذ معين، فلتر على اللي اختاره
    String? manfazFilter;
    if (widget.role == 'admin') {
      manfazFilter = selectedManfaz; // ممكن تكون null = الكل
    } else {
      manfazFilter = widget.manfazName;
    }
    if (selectedManfez.isNotEmpty) {
      baseQuery = baseQuery.where('manfaz', whereIn: selectedManfez.length <= 10 ? selectedManfez : selectedManfez.sublist(0, 10));
    } else if (widget.role != 'admin' && widget.manfazName != null && widget.manfazName!.isNotEmpty) {
      // لو مش admin يبقى حصراً على منفذ المستخدم (لأن ليس له صلاحية اختيار)
      baseQuery = baseQuery.where('manfaz', whereIn: selectedManfez);
    }

    // 2. فلترة حسب حالة السداد (لو محددة)
    if (selectedPaymentStatus != null && selectedPaymentStatus!.isNotEmpty) {
      baseQuery = baseQuery.where(
          'bill_status',
          isEqualTo: selectedPaymentStatus == 'مسدد'
      );
    }


    // 3. فلترة حسب التاريخ
    if (selectedDateRange != null) {
      final range = selectedDateRange; // متغير محلي غير null

      final startOfDay = DateTime(range!.start.year, range.start.month, range.start.day, 0, 0, 0);
      final startOfNextDay = DateTime(range.end.year, range.end.month, range.end.day).add(Duration(days: 1));

      baseQuery = baseQuery
          .where('payment_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('payment_date', isLessThan: Timestamp.fromDate(startOfNextDay));
    }
    return baseQuery;
  }


  void _updateSearchQuery(String query) {
    setState(() {
      searchQuery = query.trim();
    });
  }

  Future<void> _exportToExcel(
      bool paidOnly,
      BuildContext context, {
        bool isStop = false,
        String? selectedManfaz,
        String? selectedProvider,
        DateTimeRange? selectedDateRange,
      })
  async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('clients')
          .where('bill_status', isEqualTo: paidOnly);

      if (selectedManfez.isNotEmpty) {
        query = query.where('manfaz', whereIn: selectedManfez.length <= 10 ? selectedManfez : selectedManfez.sublist(0, 10));
      }

      if (selectedProvider != null && selectedProvider.isNotEmpty) {
        query = query.where('provider', isEqualTo: selectedProvider);
      }

      if (selectedDateRange != null) {
        final range = selectedDateRange;

        final startOfDay = DateTime(range.start.year, range.start.month, range.start.day, 0, 0, 0);
        final startOfNextDay = DateTime(range.end.year, range.end.month, range.end.day).add(Duration(days: 1));

        query = query
            .where('payment_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('payment_date', isLessThan: Timestamp.fromDate(startOfNextDay));
      }


      final snapshot = await query.get();
      print("🔥 عدد العملاء المسترجعين دالخ اكسبد: ${snapshot.docs.length}");
      final rows = <List<String>>[];
      int stoppedCount = 0;

      rows.add([
        "الرقم",
        "الاسم",
        "المنفذ",
        "الفاتورة",
        "الشبكه",
        "مين سدد",
        "تاريخ السداد",
        "حالة الايقاف",
      ]);

      WriteBatch? batch;
      if (!paidOnly && isStop) {
        batch = FirebaseFirestore.instance.batch();
      }

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        bool isCurrentlyStopped = data['isStopped'] == true;

        if (!paidOnly && isStop && !isCurrentlyStopped) {
          batch!.update(doc.reference, {'isStopped': true});
          isCurrentlyStopped = true; // لازم نحدثه هنا عشان الإكسل يقرأ القيمة الصح
          stoppedCount++;
        }

        rows.add([
          data['number'].toString(),
          data['client_name'] ?? '',
          data['manfaz'] ?? '',
          data['bill'].toString(),
          data['provider'] ?? '',
          data['paid_by'] ?? '',
          data['payment_date'] != null
              ? (data['payment_date'] as Timestamp).toDate().toString()
              : '',
          isCurrentlyStopped ? 'موقوف' : 'غير موقوف',
        ]);
      }

      if (!paidOnly && isStop && batch != null) {
        await batch.commit(); // 🟢 مهم جدًا
      }


      if (!paidOnly && isStop && context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars(); // تنظيف الرسائل السابقة
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(stoppedCount > 0
                ? "تم إيقاف $stoppedCount رقم غير مسدد بنجاح"
                : "لا يوجد أرقام غير مسددة لإيقافها"),
            backgroundColor: stoppedCount > 0 ? Colors.red : Colors.orange,
          ),
        );
      }


      final excel = Excel.createExcel();
      Sheet sheet = excel['Clients'];
      for (var row in rows) {
        sheet.appendRow(row);
      }

      final fileBytes = excel.encode();
      if (fileBytes == null) return;

      final dir = await getTemporaryDirectory();
      final fileName = paidOnly
          ? "المسددين.xlsx"
          : isStop
          ? "الغير_مسددين_بعد_الايقاف.xlsx"
          : "الغير_مسددين.xlsx";
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(fileBytes);

      await Share.shareXFiles([XFile(file.path)], text: "ملف العملاء");
      if (!paidOnly && isStop && context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars(); // تنظيف الرسائل السابقة
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(stoppedCount > 0
                ? "تم إيقاف $stoppedCount رقم غير مسدد بنجاح"
                : "لا يوجد أرقام غير مسددة لإيقافها"),
            backgroundColor: stoppedCount > 0 ? Colors.red : Colors.orange,
          ),
        );
      }
    } catch (e, stack) {
      print("🔥 حصل خطأ أثناء تصدير الإكسل: $e");
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ أثناء تصدير الملف: $e")),
      );
    }
  }


// كود الايقاف
  Future<void> _exportStoppedPaidClients(
      BuildContext context, {
        String? selectedManfaz,
        String? selectedProvider,
        DateTimeRange? selectedDateRange,
      })
  async {
    Query query = FirebaseFirestore.instance
        .collection('clients')
        .where('bill_status', isEqualTo: true)
        .where('isStopped', isEqualTo: true);

    if (selectedManfez.isNotEmpty) {
      query = query.where('manfaz', whereIn: selectedManfez.length <= 10 ? selectedManfez : selectedManfez.sublist(0, 10));
    }

    if (selectedProvider != null && selectedProvider.isNotEmpty) {
      query = query.where('provider', isEqualTo: selectedProvider);
    }

    if (selectedDateRange != null) {
      query = query.where('payment_date', isGreaterThanOrEqualTo: Timestamp.fromDate(selectedDateRange.start));
      query = query.where('payment_date', isLessThanOrEqualTo: Timestamp.fromDate(selectedDateRange.end));
    }

    final snapshot = await query.get();
    print("🔥 عدد العملاء المسترجعين دالخ بيد: ${snapshot.docs.length}");
    final rows = <List<String>>[];

    rows.add([
      "الرقم",
      "الاسم",
      "المنفذ",
      "الفاتورة",
      "الشبكه",
      "مين سدد",
      "تاريخ السداد"
    ]);

    final batch = FirebaseFirestore.instance.batch();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;

      // أضف الصف
      rows.add([
        data['number'].toString(),
        data['client_name'] ?? '',
        data['manfaz'] ?? '',
        data['bill'].toString(),
        data['provider'] ?? '',
        data['paid_by'] ?? '',
        data['payment_date'] != null
            ? (data['payment_date'] as Timestamp).toDate().toString()
            : '',
      ]);

      // أضف تحديث فك الإيقاف للدُفعة
      batch.update(doc.reference, {'isStopped': false});
    }

// نفذ كل التحديثات دفعة واحدة
    await batch.commit();

    if (rows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("لا يوجد عملاء مسددين بعد الإيقاف"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final excel = Excel.createExcel();
    final sheetName = selectedManfaz != null && selectedManfaz.isNotEmpty
        ? selectedManfaz
        : "Clients";
    final sheet = excel[sheetName];

    for (var row in rows) {
      sheet.appendRow(row);
    }

    final fileBytes = excel.encode();
    if (fileBytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/المسددين_بعد_الايقاف.xlsx');
    await file.writeAsBytes(fileBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: "ملف المسددين بعد الإيقاف",
    );
  }




  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // مسح بيانات الدخول

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _showFilterDialog() async {
    final manfazController =
    TextEditingController(text: selectedManfaz ?? '');
    final providerController = TextEditingController(text: selectedProvider ?? '');

    DateTimeRange? pickedDateRange = selectedDateRange;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('تصفية البيانات'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.role == 'admin')
                      MultiSelectDialogField<String>(
                        items: manfazOptions.map((e) => MultiSelectItem<String>(e, e)).toList(),
                        title: Text("اختر المنافذ"),
                        buttonText: Text("اختر المنافذ"),
                        searchable: true,
                        cancelText: Text("إلغاء"),
                        confirmText: Text("تأكيد"),
                        listType: MultiSelectListType.CHIP,
                        initialValue: selectedManfez,
                        onConfirm: (values) {
                          setStateDialog(() {
                            selectedManfez = values.cast<String>();
                          });
                        },
                      ),
                    const SizedBox(height: 8),

                    TextField(

                      controller: providerController,
                      decoration: const InputDecoration(labelText: 'الشبكة'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pickedDateRange == null
                                ? 'لم يتم اختيار تاريخ'
                                : '${pickedDateRange?.start.toLocal().toString().split(' ')[0]} إلى ${pickedDateRange?.end.toLocal().toString().split(' ')[0]}',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              initialDateRange: pickedDateRange,
                            );
                            if (picked != null) {
                              setStateDialog(() {
                                pickedDateRange = picked;
                              });
                            }
                          },
                          child: const Text('اختيار التاريخ'),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('حالة السداد:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Radio<String>(
                              value: '',
                              groupValue: selectedPaymentStatus ?? '',
                              onChanged: (value) {
                                setStateDialog(() {
                                  selectedPaymentStatus = value!;
                                  query = _buildQuery(); // تحديث الاستعلام هنا
                                });
                              },
                            ),
                            const Text('الكل'),
                          ],
                        ),
                        Row(
                          children: [
                            Radio<String>(
                              value: 'مسدد',
                              groupValue: selectedPaymentStatus ?? '',
                              onChanged: (value) {
                                setStateDialog(() {
                                  selectedPaymentStatus = value!;
                                  query = _buildQuery(); // تحديث الاستعلام هنا
                                });
                              },
                            ),
                            const Text('مسدد'),
                          ],
                        ),
                        Row(
                          children: [
                            Radio<String>(
                              value: 'غير مسدد',
                              groupValue: selectedPaymentStatus ?? '',
                              onChanged: (value) {
                                setStateDialog(() {
                                  selectedPaymentStatus = value!;
                                  query = _buildQuery(); // تحديث الاستعلام هنا
                                });
                              },
                            ),
                            const Text('غير مسدد'),
                          ],
                        ),
                      ],
                    ),

                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedManfez = [];
                      selectedProvider = null;
                      selectedDateRange = null;
                      selectedPaymentStatus = null;
                      query = _buildQuery();
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('إلغاء الفلترة'),
                ),
                TextButton(
                  onPressed: () {


                    setState(() {
                      selectedManfaz = manfazController.text.trim().isEmpty
                          ? null
                          : manfazController.text.trim();
                      selectedProvider = providerController.text.trim().isEmpty
                          ? null
                          : providerController.text.trim();

                      selectedDateRange = pickedDateRange;
                      query = _buildQuery();
                    });

                    Navigator.of(context).pop();
                  },
                  child: const Text('تطبيق الفلترة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> fixCorruptedPhoneNumbers() async {
    final collection = FirebaseFirestore.instance.collection('clients');
    final snapshot = await collection.get();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('isStopped')) {
        await doc.reference.update({'isStopped': false});
      }
    }

    int fixedCount = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final number = data['number'];

      if (number is Timestamp) {
        final millis = number.toDate().millisecondsSinceEpoch.toString();
        final corrected = millis.length >= 10
            ? millis.substring(millis.length - 10)
            : millis;

        await doc.reference.update({'number': corrected});
        fixedCount++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ تم تصحيح $fixedCount رقم تليفون')),
    );
  }

  String formatPhoneNumber(dynamic number) {
    // لو Timestamp نحوله لتاريخ ISO ونرجع فقط الجزء الرقمي منه
    if (number is Timestamp) {
      final date = number.toDate();
      final iso = date.toIso8601String(); // مثلاً: 2000-01-01T00:00:00.000
      final numeric = iso.replaceAll(RegExp(r'\D'), ''); // يحذف كل الرموز غير الرقمية
      return numeric;
    }

    // لو DateTime
    if (number is DateTime) {
      final iso = number.toIso8601String();
      return iso.replaceAll(RegExp(r'\D'), '');
    }

    // لو String أو int أو أي نوع تاني
    return number.toString();
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(



      appBar: AppBar(
        title: Text(
          'مرحبًا، ${widget.username}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.teal[300],
        actions: [
          if (widget.username == 'admin') // هنا مكانك
            IconButton(
              icon: const Icon(Icons.people),
              tooltip: 'عرض المستخدمين',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UsersListScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'فلترة',
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل خروج',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              onChanged: _updateSearchQuery,
              decoration: InputDecoration(
                hintText: 'ابحث بالهاتف أو الاسم',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          _buildSummary(),
          const SizedBox(height: 8),
          const Divider(height: 2),
          const SizedBox(height: 8),
          Container(
            alignment: Alignment.center,
            color: Colors.amber[50],
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              (selectedManfez.isNotEmpty)
                  ? selectedManfez.join('، ')
                  : (widget.role == 'admin' ? 'كل المنافذ' : (widget.manfazName ?? '--')),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: _buildClientList()),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [

            FloatingActionButton.small(
              heroTag: "refresh",
              tooltip: 'تحديث',
              onPressed: () {
                setState(() {
                  selectedManfaz = null;
                  selectedProvider = null;
                  selectedDateRange = null;
                  query = _buildQuery();
                  searchQuery = '';
                });
              },
              child: const Icon(Icons.refresh),
            ),
            FloatingActionButton.small(
              heroTag: "paid",
              tooltip: 'تصدير المسددين',
              backgroundColor: Colors.green,
              onPressed: () {
                _exportToExcel(
                  true,
                  context,
                  isStop: false,
                  selectedManfaz: selectedManfaz,
                  selectedProvider: selectedProvider,
                  selectedDateRange: selectedDateRange,
                );
              },
              child: const Icon(Icons.file_download),
            ),
            FloatingActionButton.small(
              heroTag: "stop_numbers",
              tooltip: 'سحب/إيقاف الأرقام الغير مسددة',
              backgroundColor: Colors.red,
              onPressed: () async {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("اختار العملية"),
                      content: const Text("هل تريد فقط سحب الأرقام؟ أم سحب وإيقاف الأرقام؟"),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _exportToExcel(
                              false, // غير مسددين
                              context,
                              isStop: false,
                              selectedManfaz: selectedManfaz,
                              selectedProvider: selectedProvider,
                              selectedDateRange: selectedDateRange,
                            );
                          },
                          child: const Text("سحب فقط"),
                        ),
                        TextButton(
                             onPressed: () async {
                    Navigator.pop(context);
                    await _exportToExcel(
                              false, // غير مسددين
                              context,
                              isStop: true,
                              selectedManfaz: selectedManfaz,
                              selectedProvider: selectedProvider,
                              selectedDateRange: selectedDateRange,
                            );
                          },
                          child: const Text("سحب وإيقاف"),
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Icon(Icons.block),
            ),

            FloatingActionButton.small(
              heroTag: "stopped_paid",
              tooltip: 'سحب المسددين بعد الإيقاف',
              backgroundColor: Colors.amber,
              onPressed: () async {
                await _exportStoppedPaidClients(
                  context,
                  selectedManfaz: selectedManfaz,
                  selectedProvider: selectedProvider,
                  selectedDateRange: selectedDateRange,
                );
              },
              child: const Icon(Icons.file_download),
            ),
            if (widget.username == 'admin')
            FloatingActionButton.small(
              heroTag: "upload",
              tooltip: 'رفع أكسل',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UploadExcelScreen(),
                  ),
                );
              },
              child: const Icon(Icons.upload),
            ),
            if (widget.username == 'admin')
            FloatingActionButton.small(
              heroTag: "addClient",
              tooltip: 'إضافة عميل جديد',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>  AddClientScreen(),
                  ),
                );
              },
              child: const Icon(Icons.person_add),
            ),
          ],
        ),
      )
          ,
    );
  }

  Widget _buildSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        int totalPaid = 0;
        int totalUnpaid = 0;
        int totalPaidAmount = 0;
        int totalUnpaidAmount = 0;

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          int bill = int.tryParse(data['bill'].toString()) ?? 0;

          if (data['bill_status'] == true) {
            totalPaid++;
            totalPaidAmount += bill;
          } else {
            totalUnpaid++;
            totalUnpaidAmount += bill;
          }
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Text('المسددين',
                    style: TextStyle(
                        color: Colors.blue[800], fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text('عدد: $totalPaid',
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(width: 8),
                    Text('مبلغ: $totalPaidAmount',
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ],
            ),
            Column(
              children: [
                Text('غير مسددين',
                    style: TextStyle(
                        color: Colors.blue[800], fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text('عدد: $totalUnpaid',
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(width: 8),
                    Text('مبلغ: $totalUnpaidAmount',
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildClientList() {
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'حدث خطأ في تحميل البيانات!\n\n${snapshot.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['client_name'] ?? '').toString().toLowerCase();
          final number = (data['number'] ?? '').toString().split('.')[0];

          return name.contains(searchQuery.toLowerCase()) ||
              number.contains(searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('لا يوجد عملاء'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            return Card(
              color: (data["bill_status"] == true) ? Colors.green[50] : Colors.red[50],
              elevation: 3,
              shadowColor: Colors.grey.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Row(
                    children: [
                      Text('${(data['bill'] ?? 0).toInt()} ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.black)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          data["client_name"] ?? "--",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontSize: 16),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: (data["provider"] ?? "--"),
                          style: const TextStyle(color: Colors.blue, fontSize: 15),
                          children: [
                            const TextSpan(
                                text: " - ",
                                style: TextStyle(color: Colors.orange, fontSize: 15)),
                            TextSpan(
                              text: (data["manfaz"] ?? "--"),
                              style: const TextStyle(color: Colors.orange, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _toggleCopyNumber(data['number']),
                        child: Text(
                          data['number'],
                          style: TextStyle(
                            color: copiedNumbers.contains(data['number']) ? Colors.green : Colors.black45,

                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      if (data["bill_status"] == true && data["payment_date"] != null)
                        Text(
                          DateFormat('yyyy-MM-dd hh:mm a').format(
                            (data["payment_date"] as Timestamp).toDate(),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  trailing: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.username == 'admin')
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.teal),

                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditClientScreen(
                                  clientId: docs[index].id,
                                  data: data,
                                ),
                              ),
                            );
                          },
                          tooltip: 'تعديل بيانات العميل',
                        ),
                      if (widget.username == 'admin')
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('تأكيد الحذف'),
                              content: const Text('هل أنت متأكد أنك تريد حذف هذا العميل؟'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('إلغاء'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('حذف'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await docs[index].reference.delete();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم حذف العميل بنجاح')),
                              );
                            }
                          }
                        },
                        tooltip: 'حذف العميل',
                      ),
                      // السويتش وباقي الأدوات الأخرى
                      Switch(
                        value: data["bill_status"] ?? false,
                        onChanged: (widget.username == 'admin' || data["bill_status"] != true)
                            ? (val) async {
                          bool confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(val ? 'تأكيد السداد' : 'تأكيد الإلغاء'),
                              content: Text(val
                                  ? 'هل أنت متأكد أنك تريد وضع هذا الرقم كمسدد؟'
                                  : 'هل أنت متأكد أنك تريد وضع هذا الرقم كغير مسدد؟ سيتم حذف تاريخ الدفع.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('إلغاء'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('تأكيد'),
                                ),
                              ],
                            ),
                          ) ?? false;

                          if (confirm) {
                            await docs[index].reference.update({
                              'bill_status': val,
                              if (val)
                                'payment_date': Timestamp.now()
                              else
                                'payment_date': FieldValue.delete(),
                              if (val)
                                'paid_by': widget.username
                              else
                                'paid_by': FieldValue.delete(),
                            });
                          }
                        }
                            : null,
                        activeColor: Colors.green,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data["bill_status"] == true ? "مسدد" : "غير مسدد",
                        style: TextStyle(
                          color:
                          data["bill_status"] == true ? Colors.green : Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ), );
          },
        );
      },
    );
  }

}