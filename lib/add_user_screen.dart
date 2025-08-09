import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  String? selectedRole;
  String? manfazName; // في حالة المستخدم role=manfaz

  final _formKey = GlobalKey<FormState>();

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    await FirebaseFirestore.instance.collection('users').add({
      'username': usernameController.text.trim(),
      'password': passwordController.text.trim(),
      'role': selectedRole,
      'manfaz': manfazName
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إضافة المستخدم بنجاح!')),
    );
    Navigator.pop(context); // العودة للخلف
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة مستخدم جديد')),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                validator: (v) => v!.isEmpty ? "مطلوب" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'كلمة السر'),
                validator: (v) => v!.isEmpty ? "مطلوب" : null,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('admin')),
                  DropdownMenuItem(value: 'manfaz', child: Text('manfaz')),
                ],
                onChanged: (val) {
                  setState(() {
                    selectedRole = val;
                  });
                },
                decoration: const InputDecoration(labelText: 'الدور'),
                validator: (v) => v == null ? "اختار الدور" : null,
              ),
              if (selectedRole == 'manfaz') ...[
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'اسم المنفذ'),
                  onChanged: (val) => manfazName = val.trim(),
                  validator: (v) {
                    if (selectedRole == 'manfaz' && (v == null || v.isEmpty)) return "مطلوب";
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                  onPressed: _addUser,
                  child: const Text('إضافة')
              ),
            ],
          ),
        ),
      ),
    );
  }
}