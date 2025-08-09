import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadExcelScreen extends StatefulWidget {
  const UploadExcelScreen({super.key});

  @override
  State<UploadExcelScreen> createState() => _UploadExcelScreenState();
}

class _UploadExcelScreenState extends State<UploadExcelScreen> {
  bool uploading = false;
  int totalRows = 0;
  int uploadedRows = 0;

  Future<void> deleteOldData() async {
    var collection = FirebaseFirestore.instance.collection('clients');
    var snapshots = await collection.get();

    WriteBatch batch = FirebaseFirestore.instance.batch();
    int counter = 0;

    for (var doc in snapshots.docs) {
      batch.delete(doc.reference);
      counter++;

      if (counter == 500) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        counter = 0;
      }
    }

    if (counter > 0) {
      await batch.commit();
    }

    print('Old data deleted in batches');
  }

  Future<void> pickAndUploadExcel() async {
    try {
      setState(() {
        uploading = true;
        uploadedRows = 0;
        totalRows = 0;
      });

      final XTypeGroup typeGroup = XTypeGroup(
        label: 'excel',
        extensions: ['xlsx'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file != null) {
        print('File selected successfully');

        await deleteOldData();

        var bytes = await file.readAsBytes();
        var excel = Excel.decodeBytes(bytes);
        final collection = FirebaseFirestore.instance.collection('clients');
        WriteBatch batch = FirebaseFirestore.instance.batch();
        int counter = 0;

        for (var table in excel.tables.keys) {
          final rows = excel.tables[table]!.rows;
          totalRows = rows.length - 1; // exclude header row

          for (int row = 1; row < rows.length; row++) {
            List<Data?> rowData = rows[row];

            if (rowData.length < 7) continue;

            String number = rowData[0]?.value is double
                ? (rowData[0]!.value as double).toInt().toString()
                : rowData[0]?.value.toString().trim() ?? '-';

            String clientName = rowData[1]?.value.toString().trim() ?? '-';
            String manfaz = rowData[2]?.value.toString().trim() ?? '-';

            String rawBill = rowData[3]?.value.toString().trim() ?? '0';
            int bill = double.tryParse(rawBill)?.toInt() ?? 0;

            String rawTotalBill = rowData[4]?.value.toString().trim() ?? '0';
            int totalBill = int.tryParse(rawTotalBill) ?? 0;

            String billRaw = rowData[5]?.value.toString().trim() ?? '0';
            bool billStatus = billRaw == '1';

            print('Row $row: number=${rowData[0]?.value}, status=$billRaw → $billStatus');

            String provider = rowData[6]?.value.toString().trim() ?? '-';

            Map<String, dynamic> data = {
              "number": number,
              "client_name": clientName,
              "manfaz": manfaz,
              "bill": bill,
              "total_bill": totalBill,
              "bill_status": billStatus,
              "provider": provider,
            };

            DocumentReference docRef = collection.doc();
            batch.set(docRef, data);
            counter++;
            uploadedRows++;

            if (counter == 500) {
              setState(() {}); // لتحديث الـ progress
              await batch.commit();
              batch = FirebaseFirestore.instance.batch();
              counter = 0;
            }
          }
        }

        if (counter > 0) {
          await batch.commit();
        }

        setState(() {
          uploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ تم رفع الشيت بنجاح!")),
        );

        await Future.delayed(const Duration(seconds: 2));
        Navigator.pop(context);
      } else {
        setState(() => uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("لم يتم اختيار ملف.")),
        );
      }
    } catch (error) {
      setState(() => uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = totalRows > 0 ? uploadedRows / totalRows : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('📥 رفع شيت أكسل')),
      body: Center(
        child: uploading
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🚀 جاري رفع البيانات...'),
            const SizedBox(height: 16),
            CircularProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text('تم رفع $uploadedRows من $totalRows صف (${(progress * 100).toStringAsFixed(1)}%)'),
          ],
        )
            : ElevatedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text('اختيار ورفع الشيت'),
          onPressed: pickAndUploadExcel,
        ),
      ),
    );
  }
}
