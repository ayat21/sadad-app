import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditClientScreen extends StatefulWidget {
  final String clientId;
  final Map<String, dynamic> data;

  const EditClientScreen({super.key, required this.clientId, required this.data});

  @override
  State<EditClientScreen> createState() => _EditClientScreenState();
}

class _EditClientScreenState extends State<EditClientScreen> {
  late TextEditingController nameController;
  late TextEditingController numberController;
  late TextEditingController manfazController;
  late TextEditingController providerController;
  late TextEditingController billController;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.data['client_name'] ?? '');
    numberController = TextEditingController(text: widget.data['number']?.toString() ?? '');
    manfazController = TextEditingController(text: widget.data['manfaz'] ?? '');
    providerController = TextEditingController(text: widget.data['provider'] ?? '');
    billController = TextEditingController(text: widget.data['bill']?.toString() ?? '');
  }

  Future<void> _saveEdits() async {
    if (!_formKey.currentState!.validate()) return;

    await FirebaseFirestore.instance
        .collection('clients')
        .doc(widget.clientId)
        .update({
      'client_name': nameController.text.trim(),
      'number': numberController.text.trim(),
      'manfaz': manfazController.text.trim(),
      'provider': providerController.text.trim(),
      'bill': int.tryParse(billController.text.trim()) ?? 0,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث بيانات العميل!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل بيانات عميل')),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم العميل'),
                  validator: (v) => v!.isEmpty ? "مطلوب" : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: numberController,
                  decoration: const InputDecoration(labelText: 'رقم العميل'),
                  validator: (v) => v!.isEmpty ? "مطلوب" : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: manfazController,
                  decoration: const InputDecoration(labelText: 'المنفذ'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: providerController,
                  decoration: const InputDecoration(labelText: 'الشبكة'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: billController,
                  decoration: const InputDecoration(labelText: 'قيمة الفاتورة'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _saveEdits,
                  child: const Text('حفظ التعديلات'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}