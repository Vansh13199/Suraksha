import 'package:flutter/material.dart';
import '../../models/contact_model.dart';
import '../../core/theme/app_theme.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  // Local state for demo purposes, in real app bind to Provider
  List<ContactModel> _contacts = [
    ContactModel(id: '1', name: 'Mom', phoneNumber: '+91 9876543210', priority: 1),
  ];

  void _addContact() {
    // Show Dialog to add contact
    showDialog(context: context, builder: (context) {
       final nameCtrl = TextEditingController();
       final numCtrl = TextEditingController();
       return AlertDialog(
         title: const Text("Add Contact"),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
             const SizedBox(height: 8),
             TextField(controller: numCtrl, decoration: const InputDecoration(labelText: "Phone")),
           ],
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
           TextButton(
             onPressed: () {
               setState(() {
                 _contacts.add(ContactModel(
                   id: DateTime.now().toString(),
                   name: nameCtrl.text,
                   phoneNumber: numCtrl.text,
                   priority: _contacts.length + 1,
                 ));
               });
               Navigator.pop(context);
             }, 
             child: const Text("Add")
           ),
         ],
       );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency Contacts")),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _contacts.isEmpty 
        ? const Center(child: Text("No contacts added yet.")) 
        : ListView.builder(
          itemCount: _contacts.length,
          itemBuilder: (context, index) {
            final contact = _contacts[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.lightBlue,
                child: Text(contact.name[0], style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              title: Text(contact.name),
              subtitle: Text(contact.phoneNumber),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppTheme.errorRed),
                onPressed: () {
                  setState(() {
                    _contacts.removeAt(index);
                  });
                },
              ),
            );
          },
        ),
    );
  }
}
