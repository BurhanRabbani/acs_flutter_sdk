import 'package:acs_flutter_sdk/acs_flutter_sdk.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ACS Flutter SDK Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _sdk = AcsFlutterSdk();
  String _platformVersion = 'Unknown';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initPlatformState();
  }

  Future<void> _initPlatformState() async {
    try {
      final version = await _sdk.getPlatformVersion() ?? 'Unknown';
      if (mounted) {
        setState(() => _platformVersion = version);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _platformVersion = 'Error: $e');
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Azure Communication Services'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Identity'),
            Tab(icon: Icon(Icons.call), text: 'Calling'),
            Tab(icon: Icon(Icons.chat), text: 'Chat'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Platform: $_platformVersion',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                IdentityTab(sdk: _sdk),
                CallingTab(sdk: _sdk),
                ChatTab(sdk: _sdk),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Identity Tab
class IdentityTab extends StatefulWidget {
  final AcsFlutterSdk sdk;

  const IdentityTab({super.key, required this.sdk});

  @override
  State<IdentityTab> createState() => _IdentityTabState();
}

class _IdentityTabState extends State<IdentityTab> {
  final _connectionStringController = TextEditingController();
  String _status = 'Not initialized';
  bool _isLoading = false;

  @override
  void dispose() {
    _connectionStringController.dispose();
    super.dispose();
  }

  Future<void> _initializeIdentity() async {
    if (_connectionStringController.text.isEmpty) {
      _showError('Please enter a connection string');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final identityClient = widget.sdk.createIdentityClient();
      await identityClient.initialize(_connectionStringController.text);
      setState(() {
        _status = 'Identity client initialized successfully';
        _isLoading = false;
      });
      _showSuccess('Identity client initialized');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Identity Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Note: In production, identity operations should be performed server-side for security.',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _connectionStringController,
            decoration: const InputDecoration(
              labelText: 'Connection String',
              hintText: 'Enter your ACS connection string',
              border: OutlineInputBorder(),
              helperText: 'Get this from Azure Portal',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _initializeIdentity,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: const Text('Initialize Identity Client'),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            color: Colors.blue,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Production Best Practices',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '1. Never expose connection strings in client apps\n'
                    '2. Create users and generate tokens on your backend\n'
                    '3. Implement token refresh mechanism\n'
                    '4. Use secure storage for tokens',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Calling Tab
class CallingTab extends StatefulWidget {
  final AcsFlutterSdk sdk;

  const CallingTab({super.key, required this.sdk});

  @override
  State<CallingTab> createState() => _CallingTabState();
}

class _CallingTabState extends State<CallingTab> {
  final _accessTokenController = TextEditingController();
  final _participantController = TextEditingController();
  String _status = 'Not initialized';
  bool _isLoading = false;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isVideoOn = false;
  late AcsCallClient _callClient;

  @override
  void initState() {
    super.initState();
    _callClient = widget.sdk.createCallClient();
  }

  @override
  void dispose() {
    _accessTokenController.dispose();
    _participantController.dispose();
    _callClient.dispose();
    super.dispose();
  }

  Future<void> _initializeCalling() async {
    if (_accessTokenController.text.isEmpty) {
      _showError('Please enter an access token');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _callClient.initialize(_accessTokenController.text);
      setState(() {
        _status = 'Calling client initialized';
        _isLoading = false;
      });
      _showSuccess('Calling client initialized');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
      _showError(e.toString());
    }
  }

  Future<void> _startCall() async {
    if (_participantController.text.isEmpty) {
      _showError('Please enter participant ID');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _callClient.startCall([
        _participantController.text,
      ], withVideo: _isVideoOn);
      setState(() {
        _status = 'Call started';
        _isInCall = true;
        _isLoading = false;
      });
      _showSuccess('Call started');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
      _showError(e.toString());
    }
  }

  Future<void> _endCall() async {
    setState(() => _isLoading = true);

    try {
      await _callClient.endCall();
      setState(() {
        _status = 'Call ended';
        _isInCall = false;
        _isMuted = false;
        _isVideoOn = false;
        _isLoading = false;
      });
      _showSuccess('Call ended');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
      _showError(e.toString());
    }
  }

  Future<void> _toggleMute() async {
    try {
      if (_isMuted) {
        await _callClient.unmuteAudio();
        setState(() => _isMuted = false);
        _showSuccess('Unmuted');
      } else {
        await _callClient.muteAudio();
        setState(() => _isMuted = true);
        _showSuccess('Muted');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _toggleVideo() async {
    try {
      if (_isVideoOn) {
        await _callClient.stopVideo();
        setState(() => _isVideoOn = false);
        _showSuccess('Video stopped');
      } else {
        await _callClient.startVideo();
        setState(() => _isVideoOn = true);
        _showSuccess('Video started');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Voice & Video Calling',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _accessTokenController,
            decoration: const InputDecoration(
              labelText: 'Access Token',
              hintText: 'Enter your access token',
              border: OutlineInputBorder(),
              helperText: 'Get this from your backend',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _initializeCalling,
            icon: const Icon(Icons.login),
            label: const Text('Initialize Calling Client'),
          ),
          const Divider(height: 32),
          TextField(
            controller: _participantController,
            decoration: const InputDecoration(
              labelText: 'Participant ID',
              hintText: 'Enter participant user ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (!_isInCall)
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _startCall,
              icon: const Icon(Icons.call),
              label: const Text('Start Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleMute,
                    icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                    label: Text(_isMuted ? 'Unmute' : 'Mute'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleVideo,
                    icon: Icon(
                      _isVideoOn ? Icons.videocam : Icons.videocam_off,
                    ),
                    label: Text(_isVideoOn ? 'Stop Video' : 'Start Video'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _endCall,
              icon: const Icon(Icons.call_end),
              label: const Text('End Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_status),
                  if (_isInCall) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.circle, size: 12, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text('In call'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Chat Tab
class ChatTab extends StatefulWidget {
  final AcsFlutterSdk sdk;

  const ChatTab({super.key, required this.sdk});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _accessTokenController = TextEditingController();
  final _threadIdController = TextEditingController();
  final _messageController = TextEditingController();
  String _status = 'Not initialized';
  bool _isLoading = false;
  bool _isInThread = false;
  final List<ChatMessage> _messages = [];
  late AcsChatClient _chatClient;

  @override
  void initState() {
    super.initState();
    _chatClient = widget.sdk.createChatClient();
  }

  @override
  void dispose() {
    _accessTokenController.dispose();
    _threadIdController.dispose();
    _messageController.dispose();
    _chatClient.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    if (_accessTokenController.text.isEmpty) {
      _showError('Please enter an access token');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _chatClient.initialize(_accessTokenController.text);
      setState(() {
        _status = 'Chat client initialized';
        _isLoading = false;
      });
      _showSuccess('Chat client initialized');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
      _showError(e.toString());
    }
  }

  Future<void> _joinThread() async {
    if (_threadIdController.text.isEmpty) {
      _showError('Please enter thread ID');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _chatClient.joinChatThread(_threadIdController.text);
      setState(() {
        _status = 'Joined thread';
        _isInThread = true;
        _isLoading = false;
      });
      _showSuccess('Joined thread');
      _loadMessages();
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
      _showError(e.toString());
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatClient.getMessages(_threadIdController.text);
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) {
      _showError('Please enter a message');
      return;
    }

    try {
      await _chatClient.sendMessage(
        _threadIdController.text,
        _messageController.text,
      );
      _messageController.clear();
      _showSuccess('Message sent');
      _loadMessages();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Chat',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _accessTokenController,
                  decoration: const InputDecoration(
                    labelText: 'Access Token',
                    hintText: 'Enter your access token',
                    border: OutlineInputBorder(),
                    helperText: 'Get this from your backend',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _initializeChat,
                  icon: const Icon(Icons.login),
                  label: const Text('Initialize Chat Client'),
                ),
                const Divider(height: 32),
                TextField(
                  controller: _threadIdController,
                  decoration: const InputDecoration(
                    labelText: 'Thread ID',
                    hintText: 'Enter chat thread ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading || _isInThread ? null : _joinThread,
                  icon: const Icon(Icons.group),
                  label: const Text('Join Thread'),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_status),
                        if (_isInThread) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.circle, size: 12, color: Colors.green),
                              const SizedBox(width: 8),
                              const Text('In thread'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_isInThread) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Messages',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_messages.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No messages yet'),
                      ),
                    )
                  else
                    ..._messages.map(
                      (message) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(message.content),
                          subtitle: Text(
                            'From: ${message.senderId}\n${message.sentOn}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (_isInThread)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
