import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_user_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كل المستخدمين')),
      body: Column(
        children: [

          // مربع البحث أعلى الشاشة
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث باسم المستخدم أو كلمة السر',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() {
                  searchQuery = val.trim();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('خطأ: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final username = (data['username'] ?? '').toString().toLowerCase();
                  final password = (data['password'] ?? '').toString().toLowerCase();
                  return username.contains(searchQuery.toLowerCase())
                      || password.contains(searchQuery.toLowerCase());
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('لا يوجد مستخدمين'));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 2),
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>? ?? {};
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(
                        data['username'] ?? '--',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                          "الدور: ${data['role'] ?? '--'}\n"
                              "المنفذ: ${data['manfaz'] ?? '--'}\n"
                              "كلمة السر: ${data['password'] ?? '--'}"
                      ),
                      trailing: (data['username'] != 'admin')
                          ? IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'حذف المستخدم',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('تأكيد الحذف'),
                              content: const Text('هل أنت متأكد أنك تريد حذف هذا المستخدم؟'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await docs[i].reference.delete();
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم حذف المستخدم!')));
                          }
                        },
                      )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'إضافة مستخدم جديد',
        child: const Icon(Icons.person_add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddUserScreen()),
          );
        },
      ),
    );
  }
}