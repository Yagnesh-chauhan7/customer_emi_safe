import 'package:flutter/material.dart';
import '../services/frp_service.dart';

class FRPDemoScreen extends StatefulWidget {
  const FRPDemoScreen({Key? key}) : super(key: key);

  @override
  _FRPDemoScreenState createState() => _FRPDemoScreenState();
}

class _FRPDemoScreenState extends State<FRPDemoScreen> {
  final TextEditingController _accountController = TextEditingController();
  List<String> _accounts = [];
  bool _isFRPEnabled = false;
  String _statusMessage = 'Loading status...';

  @override
  void initState() {
    super.initState();
    _checkStatus();
    print(_statusMessage);
  }

  Future<void> _checkStatus() async {
    final status = await FRPService.getFRPStatus();
    setState(() {
      _isFRPEnabled = status['status'] ?? false;
      if (status['accounts'] != null) {
        _accounts = List<String>.from(status['accounts']);
      }
      _statusMessage = status['success'] == true 
          ? 'Status fetched successfully' 
          : 'Error: ${status['error']}';
    });

    print("_checkStatus ---> ${status['error']}");
  }

  Future<void> _enableFRP() async {
    if (_accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one account')),
      );
      return;
    }
    
    final result = await FRPService.enableFRP(_accounts);
    setState(() {
      _statusMessage = result['success'] == true 
          ? 'FRP Enabled Successfully' 
          : 'Failed: ${result['error']}';
    });

    print("_enableFRP ---> ${result['error']}");
    _checkStatus();
  }

  Future<void> _disableFRP() async {
    final result = await FRPService.disableFRP();
    setState(() {
      _statusMessage = result['success'] == true 
          ? 'FRP Disabled Successfully' 
          : 'Failed: ${result['error']}';
    });

    print("_disableFRP ---> ${result['error']}");
    _checkStatus();
  }

  void _addAccount() {
    final account = _accountController.text.trim();
    if (account.isNotEmpty && !_accounts.contains(account)) {
      setState(() {
        _accounts.add(account);
        _accountController.clear();
      });
    }
  }

  void _removeAccount(String account) {
    setState(() {
      _accounts.remove(account);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FRP Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('FRP Status: ${_isFRPEnabled ? "ENABLED" : "DISABLED"}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _isFRPEnabled ? Colors.green : Colors.red)),
                    const SizedBox(height: 8),
                    Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _accountController,
                    decoration: const InputDecoration(
                      labelText: 'Google Account (e.g. test@gmail.com)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addAccount,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Accounts:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: _accounts.length,
                itemBuilder: (context, index) {
                  final account = _accounts[index];
                  return ListTile(
                    title: Text(account),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeAccount(account),
                    ),
                  );
                },
              ),
            ),
            Text("113415044536067329262"),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _enableFRP,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Enable FRP'),
                ),
                ElevatedButton(
                  onPressed: _disableFRP,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Disable FRP'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

//todo: FRP Id Response
/*
{
  "resourceName": "people/113415044536067329262",
  "etag": "%EgMBLjcaBAECBQciDFNZZ3N0KytOWVI0PQ==",
  "metadata": {
    "sources": [
      {
        "type": "PROFILE",
        "id": "113415044536067329262",
        "etag": "#Rd9M6jZwz7o=",
        "profileMetadata": {
          "objectType": "PERSON",
          "userTypes": [
            "GOOGLE_USER"
          ]
        },
        "updateTime": "2026-05-12T03:08:49.513951Z"
      }
    ],
    "objectType": "PERSON"
  }
}
*/