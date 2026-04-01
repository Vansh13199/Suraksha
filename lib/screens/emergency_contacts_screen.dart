import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/emergency_contact_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sos_provider.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/modern_card.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final AuthService _authService = AuthService();
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    final contacts = await _authService.getEmergencyContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    }
  }

  void _addContact() {
    final nameCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Add Emergency Contact"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Name"),
                  validator: (val) => val == null || val.isEmpty ? "Name required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: numCtrl,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    prefixText: "+91 ",
                    counterText: "",
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (val) {
                     if (val == null || val.isEmpty) return "Phone required";
                     if (val.length != 10) return "Must be 10 digits";
                     return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                
                // Capture values and messenger BEFORE popping dialog
                final name = nameCtrl.text.trim();
                final phone = "+91${numCtrl.text.trim()}";
                final messenger = ScaffoldMessenger.of(context);
                
                Navigator.pop(context); // Close dialog
                
                setState(() => _isLoading = true);
                
                final success = await _authService.addEmergencyContact(
                  name,
                  phone,
                  "Family", // Default relation for now
                );

                if (success) {
                   await _loadContacts();
                   // Sync the SOS provider so the background logic has the fresh list
                   if (mounted) {
                     Provider.of<SosProvider>(context, listen: false).refreshContacts();
                   }
                   messenger.showSnackBar(
                     const SnackBar(content: Text("Contact Added"), backgroundColor: AppTheme.successGreen),
                   );
                } else {
                   await _loadContacts();
                   messenger.showSnackBar(
                     const SnackBar(content: Text("Failed to add contact (Limit 5 or Duplicate)"), backgroundColor: AppTheme.alertRed),
                   );
                }
              },
              child: const Text("Add Contact"),
            ),
          ],
        );
      }
    );
  }

  void _deleteContact(String id) async {
    // Show confirmation dialog before deleting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Contact?"),
        content: const Text("Are you sure you want to remove this emergency contact?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Remove", style: TextStyle(color: AppTheme.alertRed))),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final success = await _authService.deleteEmergencyContact(id);
    if (success) {
      await _loadContacts();
      if (mounted) {
        // Sync the SOS provider so the background logic has the fresh list
        Provider.of<SosProvider>(context, listen: false).refreshContacts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contact Deleted"), backgroundColor: Colors.orange),
        );
      }
    } else {
      await _loadContacts();
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Failed to delete contact"), backgroundColor: AppTheme.alertRed),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency Contacts")),
      floatingActionButton: _contacts.length < 5 
        ? FloatingActionButton.extended(
            onPressed: _addContact,
            backgroundColor: AppTheme.primaryBlue,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text("Add Contact", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        : null,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _contacts.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.contact_phone_outlined, size: 80, color: AppTheme.textGrey.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  const Text(
                    "No contacts added yet",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Add up to 5 trusted contacts to be\nnotified in case of emergency.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textGrey),
                  ),
                ],
              ),
            ) 
          : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _contacts.length,
            itemBuilder: (context, index) {
              final contact = _contacts[index];
              return ModernCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.secondaryBlue.withOpacity(0.2),
                    child: Text(
                      contact.name[0].toUpperCase(), 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)
                    ),
                  ),
                  title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(contact.phoneNumber),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.alertRed),
                    onPressed: () => _deleteContact(contact.id),
                  ),
                ),
              );
            },
          ),
    );
  }
}
