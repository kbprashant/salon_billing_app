import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class NewBillPage extends StatefulWidget {
  @override
  State<NewBillPage> createState() => _NewBillPageState();
}

final List<Map<String, dynamic>> availableServices = [
  {"name": "Haircutting", "price": 150},
  {"name": "Shaving", "price": 80},
  {"name": "Face Wash", "price": 100},
  {"name": "Hair Cutting & Shaving", "price": 250},
  {"name": "Beard Trimming", "price": 100},
  {"name": "Stylish Haircut", "price": 200},
  {"name": "Pop Cutting", "price": 200},
  {"name": "Head Oil Massage", "price": 200},
  {"name": "D-TAN", "price": 250},
  {"name": "Powder Hair Colouring", "price": 200},
  {"name": "Shampoo Hair Colouring", "price": 250},
  {"name": "Hair Dryer & Spray", "price": 100},
  {"name": "Face Massage", "price": 100},
  {"name": "Face Bleach", "price": 300},
  {"name": "Facial", "price": 800},
  {"name": "Combo 1", "price": 450},
  {"name": "Combo 2", "price": 650},
  {"name": "Combo 3", "price": 600},
  {"name": "Combo 4", "price": 1300},
  {"name": "Combo 5", "price": 450},
  {"name": "Combo 6", "price": 1400},
  {"name": "Fruit Facial", "price": 599},
  {"name": "Papaya Facial", "price": 699},
  {"name": "Wine Facial", "price": 799},
  {"name": "Diamond Facial", "price": 899},
  {"name": "Gold Facial", "price": 999},
];

Map<String, dynamic>? selectedService;

class _NewBillPageState extends State<NewBillPage> {
  final phoneController = TextEditingController();
  final serviceController = TextEditingController();
  final nameController = TextEditingController();
  List<Map<String, dynamic>> services = [];

  void addService() {
    if (serviceController.text.isNotEmpty) {
      setState(() {
        services.add({
          'name': serviceController.text.trim(),
          'price': 100, // default price, can be made editable
        });
        serviceController.clear();
      });
    }
  }

  int getTotal() {
    return services.fold(0, (sum, item) => sum + (item['price'] as int));
  }

  // Inside _NewBillPageState

  Future<void> saveAndSend() async {
    final rawPhone = phoneController.text.trim();
    final name = nameController.text.trim();

    // --- Validation Checks ---
    // 1. Validate Name
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter customer name.")),
      );
      return;
    }

    // 2. Validate Phone Number (10 digits)
    // Remove any non-digit characters to check length accurately
    final digitsOnlyPhone = rawPhone.replaceAll(
      RegExp(r'\D'),
      '',
    ); // Get only digits for length check
    if (digitsOnlyPhone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid 10-digit phone number."),
        ),
      );
      return;
    }

    // 3. Validate Services
    if (services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one service.")),
      );
      return;
    }
    // --- End Validation Checks ---

    String phone =
        rawPhone.startsWith('+')
            ? rawPhone
            : '+91$rawPhone'; // Ensure +91 prefix for India

    String whatsappPhoneNumber = digitsOnlyPhone;
    if (!whatsappPhoneNumber.startsWith('91')) {
      // Assuming default India code is '91'
      whatsappPhoneNumber = '91$whatsappPhoneNumber';
    }

    String fullFormattedPhone =
        '+91$digitsOnlyPhone'; // Ensure it has +91 for internal records/PDF

    final total = getTotal();
    final timestamp = DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy hh:mm a').format(timestamp);
    final invoiceNumber = 'INV${timestamp.millisecondsSinceEpoch}';
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Show a loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Generating bill... Please wait.")),
    );

    try {
      // Load logo
      final ByteData bytes = await rootBundle.load('assets/logoblack.png');
      final Uint8List logoData = bytes.buffer.asUint8List();

      final pdf = pw.Document();
      final logoImage = pw.MemoryImage(logoData);

      final fontRegular = pw.Font.ttf(
        await rootBundle.load("assets/fonts/NotoSans-Regular.ttf"),
      );
      final fontBold = pw.Font.ttf(
        await rootBundle.load("assets/fonts/NotoSans-Bold.ttf"),
      );

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Image(logoImage, width: 300)),
                pw.SizedBox(height: 20),
                pw.Text(
                  "Arul Anath Saloon - Bill",
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  "Invoice: $invoiceNumber",
                  style: pw.TextStyle(font: fontRegular, fontSize: 14),
                ),
                pw.Text(
                  "Date: $formattedDate",
                  style: pw.TextStyle(font: fontRegular, fontSize: 14),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  "Customer Name: $name",
                  style: pw.TextStyle(font: fontRegular),
                ),
                pw.Text(
                  "Phone: $phone",
                  style: pw.TextStyle(font: fontRegular),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  "Services:",
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                ...services.map(
                  (s) => pw.Text(
                    "${s['name']} - ₹${s['price']}",
                    style: pw.TextStyle(font: fontRegular),
                  ),
                ),
                pw.Divider(),
                pw.Text(
                  "Total: ₹$total",
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/bill_$invoiceNumber.pdf");
      await file.writeAsBytes(await pdf.save());

      final ref = FirebaseStorage.instance.ref().child(
        "bills/$uid/bill_$invoiceNumber.pdf",
      );
      await ref.putFile(file);
      final pdfUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('bills').add({
        'uid': uid,
        'name': name,
        'phone': fullFormattedPhone,
        'services': services,
        'total': total,
        'invoiceNumber': invoiceNumber,
        'timestamp': Timestamp.fromDate(timestamp),
        'pdfUrl': pdfUrl,
      });

      String serviceList = services.map((e) => "- ${e['name']}").join("\n");
      String message =
          "🧾 *Arul Ananth Saloon - Bill*\n"
          "Invoice: $invoiceNumber\n"
          "$formattedDate\n"
          "Name: $name\n"
          "Phone: $phone\n\n"
          "$serviceList\n"
          "Total: ₹$total\n\n"
          "🔗 View Bill: $pdfUrl";

      final filePath = file.path;

      if (Platform.isAndroid) {
        final whatsappUri = Uri.parse(
          "https://wa.me/$whatsappPhoneNumber?text=${Uri.encodeComponent(message)}", // Use whatsappPhoneNumber here
        );
        try {
          if (await canLaunchUrl(whatsappUri)) {
            await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
          } else {
            throw "Cannot launch WhatsApp";
          }
        } catch (e) {
          debugPrint("WhatsApp launch error: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not launch WhatsApp")),
          );
        }
      } else {
        await Share.shareXFiles([XFile(filePath)], text: message);
      }

      // Clear form only after successful operations
      setState(() {
        phoneController.clear();
        services.clear();
        nameController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bill generated and sent successfully!")),
      );
    } catch (e) {
      debugPrint("Error generating or sending bill: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to generate or send bill: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black, const Color.fromARGB(255, 146, 27, 27)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // Replaced Text with Image.asset for your logo
              Center(
                child: Image.asset(
                  'assets/logo.png', // **Make sure this path is correct**
                  height: 140, // Adjust the height as needed
                ),
              ),
              const SizedBox(height: 16),
              _glassCard(
                child: Column(
                  children: [
                    _styledTextField(
                      phoneController,
                      'Customer Phone Number',
                      keyboardType:
                          TextInputType.phone, // Set keyboard to phone
                      maxLength: 10, // Max length for 10 digits
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ], // Only allow digits
                    ),
                    const SizedBox(height: 16),
                    _styledTextField(nameController, 'Customer Name'),
                    const SizedBox(height: 16),
                    _serviceSelector(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (services.isNotEmpty)
                _glassCard(child: _buildSummarySection()),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: saveAndSend,
                icon: const Icon(Icons.send),
                label: const Text('Generate & Send Bill'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: child,
    );
  }

  Widget _styledTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType, // Use the passed keyboard type
      inputFormatters: inputFormatters, // Apply input formatters
      maxLength: maxLength, // Set max length
      decoration: InputDecoration(
        counterText: "", // Hide the default character counter
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white12),
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.redAccent),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _serviceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Services", style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        Column(
          children:
              availableServices.map((service) {
                bool isSelected = services.any(
                  (s) => s['name'] == service['name'],
                );
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        services.removeWhere(
                          (s) => s['name'] == service['name'],
                        );
                      } else {
                        services.add({
                          'name': service['name'],
                          'price': service['price'],
                        });
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827), // dark background
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 12),
                        _getServiceIcon(service['name']),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            service['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          "Rs. ${service['price']}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _getServiceIcon(String name) {
    IconData icon;
    switch (name.toLowerCase()) {
      case 'haircutting':
      case 'stylish haircut':
      case 'pop cutting':
        icon = Icons.content_cut;
        break;
      case 'shaving':
      case 'beard trimming':
        icon = Icons.cut;
        break;
      case 'face wash':
      case 'face massage':
      case 'face bleach':
      case 'd-tan':
      case 'facial':
      case 'fruit facial':
      case 'papaya facial':
      case 'wine facial':
      case 'diamond facial':
      case 'gold facial':
        icon = Icons.face_retouching_natural;
        break;
      case 'powder hair colouring':
      case 'shampoo hair colouring':
        icon = Icons.brush;
        break;
      case 'head oil massage':
        icon = Icons.spa;
        break;
      case 'hair dryer & spray':
        icon = Icons.dry_cleaning;
        break;
      case 'hair cutting & shaving':
        icon = Icons.content_cut_outlined; // A combination icon
        break;
      // You can add more specific cases for combos if you have distinct icons
      case 'combo 1':
      case 'combo 2':
      case 'combo 3':
      case 'combo 4':
      case 'combo 5':
      case 'combo 6':
        icon = Icons.bubble_chart; // Generic combo icon
        break;
      default:
        icon =
            Icons.miscellaneous_services; // Default icon for unlisted services
    }

    return Icon(icon, color: Colors.redAccent);
  }

  Widget _buildSummarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selected Services',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        ...services.map(
          (item) => ListTile(
            title: Text(
              item['name'],
              style: const TextStyle(color: Colors.white),
            ),
            trailing: Text(
              "₹${item['price']}",
              style: const TextStyle(color: Colors.white),
            ),
            onLongPress: () {
              setState(() {
                services.remove(item);
              });
            },
          ),
        ),
        const Divider(color: Colors.white30),
        Text(
          "Total: ₹${getTotal()}",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
