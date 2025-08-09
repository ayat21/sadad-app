import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddClientScreen extends StatefulWidget {
  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController clientNameController = TextEditingController();
  final TextEditingController manfazController = TextEditingController();
  final TextEditingController billController = TextEditingController();
  final TextEditingController totalBillController = TextEditingController();
  bool billStatus = false;
  final TextEditingController providerController = TextEditingController();

  Future<void> addClient() async {
    if (_formKey.currentState!.validate()) {
      final collection = FirebaseFirestore.instance.collection('clients');

      final inputNumber = numberController.text.trim();

      // تحقق من وجود الرقم مسبقًا
      final querySnapshot = await collection.where('number', isEqualTo: inputNumber).get();

      if (querySnapshot.docs.isNotEmpty) {
        // الرقم موجود بالفعل، أحذر أو أخبر المستخدم
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ الرقم موجود مسبقاً، الرجاء التأكد من الرقم')),
        );
        return; // إيقاف التنفيذ وعدم إضافة العميل
      }

      Map<String, dynamic> data = {
        "number": numberController.text.trim(),
        "client_name": clientNameController.text.trim(),
        "manfaz": manfazController.text.trim(),
        "bill": int.tryParse(billController.text.trim()) ?? 0,
        "bill_status": billStatus,
        "provider": providerController.text.trim(),
      };

      await collection.doc().set(data);

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إضافة العميل بنجاح!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('إضافة عميل جديد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: numberController,
                decoration: InputDecoration(labelText: 'الرقم'),
                validator: (value) =>
                value == null || value.isEmpty ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: clientNameController,
                decoration: InputDecoration(labelText: 'اسم العميل'),
                validator: (value) =>
                value == null || value.isEmpty ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: manfazController,
                decoration: InputDecoration(labelText: 'المنفذ'),
              ),
              TextFormField(
                controller: billController,
                decoration: InputDecoration(labelText: 'الفاتورة'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: totalBillController,
                decoration: InputDecoration(labelText: 'إجمالي الفاتورة'),
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                title: Text('حالة الفاتورة'),
                value: billStatus,
                onChanged: (val) {
                  setState(() {
                    billStatus = val;
                  });
                },
              ),
              TextFormField(
                controller: providerController,
                decoration: InputDecoration(labelText: 'المزود'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: addClient,
                child: const Text('إضافة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}