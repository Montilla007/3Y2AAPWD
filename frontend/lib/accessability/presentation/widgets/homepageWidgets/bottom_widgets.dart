import 'dart:async';
import 'dart:math';

import 'package:AccessAbility/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/create_space_widget.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/join_space_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/add_place.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/map_content.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BottomWidgets extends StatefulWidget {
  final ScrollController scrollController;
  final String activeSpaceId;
  final Function(String) onCategorySelected;
  final Function(LatLng, String) onMemberPressed;

  const BottomWidgets({
    super.key,
    required this.scrollController,
    required this.activeSpaceId,
    required this.onCategorySelected,
    required this.onMemberPressed,
  });

  @override
  _BottomWidgetsState createState() => _BottomWidgetsState();
}

class _BottomWidgetsState extends State<BottomWidgets> {
  int _activeIndex = 0; // 0: People, 1: Buildings, 2: Map
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _members = [];
  String? _creatorId;
  String? _selectedMemberId;
  bool _showCreateSpace = false;
  bool _showJoinSpace = false;
  final TextEditingController _spaceNameController = TextEditingController();
  final List<TextEditingController> _verificationCodeControllers =
      List.generate(6, (index) => TextEditingController());

  StreamSubscription<DocumentSnapshot>? _membersListener;
  final List<StreamSubscription<DocumentSnapshot>> _locationListeners = [];

  final List<FocusNode> _verificationCodeFocusNodes =
      List.generate(6, (index) => FocusNode());

  @override
  void initState() {
    super.initState();
    _listenToMembers();
    _setupVerificationCodeFocusListeners();
  }

  @override
  void didUpdateWidget(BottomWidgets oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeSpaceId != oldWidget.activeSpaceId) {
      if (widget.activeSpaceId.isEmpty) {
        setState(() {
          _showCreateSpace = false;
          _showJoinSpace = false;
          _members = []; // Clear members list
        });
      }
      _listenToMembers(); // Reinitialize the listener when activeSpaceId changes
    }
  }

  @override
  void dispose() {
    _membersListener?.cancel();
    _membersListener = null;
    _locationListeners.forEach((listener) => listener.cancel());
    _locationListeners.clear();
    _spaceNameController.dispose();
    for (final controller in _verificationCodeControllers) {
      controller.dispose();
    }
    for (final node in _verificationCodeFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // Listen to members in real time
  void _listenToMembers() {
    if (widget.activeSpaceId.isEmpty) {
      _membersListener?.cancel();
      _membersListener = null;
      _locationListeners.forEach((listener) => listener.cancel());
      _locationListeners.clear();
      setState(() {
        _members = [];
      });
      return;
    }

    _membersListener?.cancel();
    _membersListener = null;
    _locationListeners.forEach((listener) => listener.cancel());
    _locationListeners.clear();

    _membersListener = _firestore
        .collection('Spaces')
        .doc(widget.activeSpaceId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        setState(() {
          _members = [];
        });
        return;
      }

      final members = snapshot['members'] != null
          ? List<String>.from(snapshot['members'])
          : [];
      final creatorId = snapshot['creator'];

      if (members.isEmpty) {
        setState(() {
          _members = [];
        });
        return;
      }

      final usersSnapshot = await _firestore
          .collection('Users')
          .where('uid', whereIn: members)
          .get();

      final updatedMembers =
          await Future.wait(usersSnapshot.docs.map((doc) async {
        final locationSnapshot =
            await _firestore.collection('UserLocations').doc(doc['uid']).get();
        final locationData = locationSnapshot.data();
        String address = 'Fetching address...';
        if (locationData != null) {
          final lat = locationData['latitude'];
          final lng = locationData['longitude'];
          address = await _getAddressFromLatLng(LatLng(lat, lng));
        }
        return {
          'uid': doc['uid'],
          'username': doc['username'] ?? 'Unknown',
          'profilePicture': doc['profilePicture'] ??
              'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.appspot.com/o/profile_pictures%2Fdefault_profile.png?alt=media&token=bc7a75a7-a78e-4460-b816-026a8fc341ba',
          'address': address,
          'lastUpdate': locationData?['timestamp'],
        };
      }));

      setState(() {
        _members = updatedMembers;
        _creatorId = creatorId;
      });

      for (final member in members) {
        final listener = _firestore
            .collection('UserLocations')
            .doc(member)
            .snapshots()
            .listen((locationSnapshot) async {
          final locationData = locationSnapshot.data();
          if (locationData != null) {
            final lat = locationData['latitude'];
            final lng = locationData['longitude'];
            final address = await _getAddressFromLatLng(LatLng(lat, lng));
            setState(() {
              final index = _members.indexWhere((m) => m['uid'] == member);
              if (index != -1) {
                _members[index]['address'] = address;
                _members[index]['lastUpdate'] = locationData['timestamp'];
              }
            });
          }
        });
        _locationListeners.add(listener);
      }
    });
  }

  // Set up focus listeners for verification code fields
  void _setupVerificationCodeFocusListeners() {
    for (int i = 0; i < _verificationCodeControllers.length; i++) {
      _verificationCodeControllers[i].addListener(() {
        if (_verificationCodeControllers[i].text.isNotEmpty && i < 5) {
          FocusScope.of(context)
              .requestFocus(_verificationCodeFocusNodes[i + 1]);
        }
      });
    }
  }

  Future<void> _addPerson() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final email = await _showAddPersonDialog();
    if (email == null || email.isEmpty) return;

    if (email == user.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You cannot send a verification code to yourself')),
      );
      return;
    }

    final receiverSnapshot = await _firestore
        .collection('Users')
        .where('email', isEqualTo: email)
        .get();

    if (receiverSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
      return;
    }

    final receiverID = receiverSnapshot.docs.first.id;

    final spaceSnapshot =
        await _firestore.collection('Spaces').doc(widget.activeSpaceId).get();

    if (!spaceSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Space not found')),
      );
      return;
    }

    final existingCode = spaceSnapshot['verificationCode'];
    final codeTimestamp = spaceSnapshot['codeTimestamp']?.toDate();

    String verificationCode;
    if (existingCode != null && codeTimestamp != null) {
      final now = DateTime.now();
      final difference = now.difference(codeTimestamp).inMinutes;
      verificationCode =
          difference < 10 ? existingCode : _generateVerificationCode();
    } else {
      verificationCode = _generateVerificationCode();
    }

    final hasChatRoom = await _chatService.hasChatRoom(user.uid, receiverID);
    if (!hasChatRoom) {
      await _chatService.sendChatRequest(
        receiverID,
        'Join My Space! \n Your verification code is: $verificationCode (Expires in 10 minutes)',
      );
    } else {
      await _chatService.sendMessage(
        receiverID,
        'Join My Space! \n Your verification code is: $verificationCode (Expires in 10 minutes)',
      );
    }

    await _firestore.collection('Spaces').doc(widget.activeSpaceId).update({
      'verificationCode': verificationCode,
      'codeTimestamp': DateTime.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification code sent via chat')),
    );
  }

  Future<String?> _showAddPersonDialog() async {
    String? email;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Send Code'),
          content: TextField(
            decoration: const InputDecoration(labelText: 'Email'),
            onChanged: (value) => email = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    return email;
  }

  Future<void> _createSpace() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final spaceName = _spaceNameController.text;
    if (spaceName.isEmpty) return;

    final verificationCode = _generateVerificationCode();
    await _firestore.collection('Spaces').add({
      'name': spaceName,
      'creator': user.uid,
      'members': [user.uid],
      'verificationCode': verificationCode,
      'codeTimestamp': DateTime.now(),
      'createdAt': DateTime.now(),
    });

    _spaceNameController.clear();
    setState(() {
      _showCreateSpace = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Space created successfully')),
    );
  }

  Future<void> _joinSpace() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final verificationCode = _verificationCodeControllers
        .map((controller) => controller.text)
        .join();
    if (verificationCode.isEmpty) return;

    final snapshot = await _firestore
        .collection('Spaces')
        .where('verificationCode', isEqualTo: verificationCode)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final spaceId = snapshot.docs.first.id;
      final codeTimestamp = snapshot.docs.first['codeTimestamp']?.toDate();

      if (codeTimestamp != null) {
        final now = DateTime.now();
        final difference = now.difference(codeTimestamp).inMinutes;
        if (difference > 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification code has expired')),
          );
          return;
        }
      }

      await _firestore.collection('Spaces').doc(spaceId).update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      for (final controller in _verificationCodeControllers) {
        controller.clear();
      }
      setState(() {
        _showJoinSpace = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined space successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid verification code')),
      );
    }
  }

  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.8,
      builder: (BuildContext context, ScrollController scrollController) {
        return Column(
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 2,
                          color: Colors.grey.shade700,
                          margin: const EdgeInsets.only(bottom: 8),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Text to Speech, Speech to Text",
                                  style: TextStyle(
                                    color: Color(0xFF6750A4),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.mic,
                                color: Color(0xFF6750A4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildButton(Icons.people, 0),
                            _buildButton(Icons.business, 1),
                            _buildButton(Icons.map, 2),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (!_showCreateSpace &&
                            !_showJoinSpace &&
                            _activeIndex == 0 &&
                            widget.activeSpaceId.isEmpty) ...[
                          // Center the title and make it bold
                          const Align(
                            alignment: Alignment.center,
                            child: Text(
                              "My Space",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Align(
                            alignment: Alignment.center,
                            child: Text(
                              "Create a new space or join an existing one today", // Lengthened text
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign
                                  .center, // Ensures proper alignment if it wraps
                            ),
                          ),

                          const SizedBox(height: 25),
                          // const Padding(
                          //   padding: EdgeInsets.only(left: 15.0),
                          //   child: Row(
                          //     mainAxisAlignment: MainAxisAlignment.start,
                          //     crossAxisAlignment: CrossAxisAlignment.start,
                          //     children: [
                          //       Text(
                          //         "My Space",
                          //         style: TextStyle(
                          //           fontWeight: FontWeight.w800,
                          //           fontSize: 20,
                          //         ),
                          //       ),
                          //     ],
                          //   ),
                          // ),
                          // const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Fixed width for "Create Space" button
                              SizedBox(
                                width: 150,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _showCreateSpace = true;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6750A4),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                  ),
                                  child: const Text(
                                    'Create Space',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Fixed width for "Join Space" button
                              SizedBox(
                                width: 150,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _showJoinSpace = true;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6750A4),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                  ),
                                  child: const Text(
                                    'Join Space',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_showCreateSpace) _buildCreateSpaceForm(),
                        if (_showJoinSpace) _buildJoinSpaceForm(),
                        _buildContent(),
                        if (_creatorId == _auth.currentUser?.uid &&
                            _activeIndex == 0 &&
                            widget.activeSpaceId.isNotEmpty)
                          ElevatedButton(
                            onPressed: _addPerson,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6750A4)),
                            child: const Text('Send code'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCreateSpaceForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header row with centered title and back button on the right
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Create my space',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _spaceNameController,
            decoration: const InputDecoration(
              labelText: 'Space Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _createSpace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 50, vertical: 15),
                  ),
                  child: const Text(
                    'Create',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 10), // Adds spacing between buttons

              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showCreateSpace = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Color(0xFF6750A4)), // Border color
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10), // Same border radius
                    ),
                  ),
                  child: const Text(
                    'Back',
                    style: TextStyle(
                        color: Color(0xFF6750A4)), // Text color to match border
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildJoinSpaceForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Main heading
          const Text(
            'Enter the Invite Code',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Subheading or helper text
          const Text(
            'Get the code from the person setting up your Space',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),

          // Code input fields
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First 3 fields
              for (int i = 0; i < 3; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 40,
                  child: TextField(
                    controller: _verificationCodeControllers[i],
                    focusNode: _verificationCodeFocusNodes[i],
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              const Text('-', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              // Last 3 fields
              for (int i = 3; i < 6; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 40,
                  child: TextField(
                    controller: _verificationCodeControllers[i],
                    focusNode: _verificationCodeFocusNodes[i],
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Submit button
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _joinSpace,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6750A4),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10), // Border radius 10
                      ),
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10), // Adds spacing between buttons
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _showJoinSpace = false;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFF6750A4)), // Border color
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10), // Same border radius
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                          color:
                              Color(0xFF6750A4)), // Text color to match border
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, int index) {
    bool isActive = _activeIndex == index;
    return SizedBox(
      width: 100,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _activeIndex = index;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? const Color(0xFF6750A4)
              : const Color.fromARGB(255, 211, 198, 248),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(16),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFF6750A4),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_activeIndex) {
      case 0:
        if (widget.activeSpaceId.isNotEmpty) {
          return Column(
            children: _members
                .where((member) => member['uid'] != _auth.currentUser?.uid)
                .map((member) => GestureDetector(
                      onTap: () async {
                        setState(() {
                          _selectedMemberId = member['uid'];
                        });

                        final locationSnapshot = await _firestore
                            .collection('UserLocations')
                            .doc(member['uid'])
                            .get();
                        final locationData = locationSnapshot.data();
                        if (locationData != null) {
                          final lat = locationData['latitude'];
                          final lng = locationData['longitude'];
                          final address =
                              await _getAddressFromLatLng(LatLng(lat, lng));

                          setState(() {
                            member['address'] = address;
                            member['lastUpdate'] = locationData['timestamp'];
                          });

                          widget.onMemberPressed(
                              LatLng(lat, lng), member['uid']);
                        }
                      },
                      child: Container(
                        color: _selectedMemberId == member['uid']
                            ? const Color(0xFF6750A4)
                            : Colors.white,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: member['profilePicture'] != null &&
                                    member['profilePicture'].startsWith('http')
                                ? NetworkImage(member['profilePicture'])
                                : const AssetImage(
                                        'assets/images/others/default_profile.png')
                                    as ImageProvider,
                          ),
                          title: Text(
                            member['username'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Location: ${member['address'] ?? 'Fetching address...'}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              if (member['lastUpdate'] != null)
                                Text(
                                  'Last location update: ${_getTimeDifference((member['lastUpdate'] as Timestamp).toDate())}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.chat),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/chatconvo',
                                arguments: {
                                  'receiverEmail': member['username'],
                                  'receiverID': member['uid'],
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ))
                .toList(),
          );
        } else {
          return const Center(
            child: Text(
              '',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
      case 1:
        return const AddPlaceWidget();
      case 2:
        return MapContent(
          onCategorySelected: widget.onCategorySelected,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<String> _getAddressFromLatLng(LatLng latLng) async {
    try {
      final geocodingService = GeocodingService();
      final address = await geocodingService.getAddressFromLatLng(latLng);
      return address;
    } catch (e) {
      print('Error fetching address: $e');
      return 'Address unavailable';
    }
  }

  String _getTimeDifference(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute(s) ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour(s) ago';
    } else {
      return '${difference.inDays} day(s) ago';
    }
  }
}
