import 'dart:async';
import 'dart:math';

import 'package:accessability/accessability/backgroundServices/place_notification_service.dart';
import 'package:accessability/accessability/backgroundServices/space_member_notification_service.dart';
import 'package:accessability/accessability/backgroundServices/distance_notification_service.dart';
import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:accessability/accessability/backgroundServices/pwd_location_notification_service.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'location_updates',
      initialNotificationTitle: 'Location Updates',
      initialNotificationContent: 'Tracking your location in the background',
      foregroundServiceNotificationId: 1,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );

  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();

    final pwdNotificationService = PWDLocationNotificationService();
    await pwdNotificationService.initialize();

    final placeNotificationService = PlaceNotificationService();
    await placeNotificationService.initialize();

    final spaceMemberNotificationService = SpaceMemberNotificationService();
    await spaceMemberNotificationService.initialize();

    final distanceNotificationService = DistanceNotificationService();
    await distanceNotificationService.initialize();

    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title: "Location Tracking",
        content: "Your location is being updated.",
      );
      service.setAsForegroundService();
    }

    // Check if the user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      service.invoke('stopService');
      return;
    }

    // Initialize ChatService for expiration checking
    final chatService = ChatService();

    // Initialize location service
    final location = Location();

    // Timer for periodic expiration checks (every 5 minutes)
    Timer.periodic(Duration(minutes: 5), (timer) async {
      try {
        await chatService.checkAndExpireRequests();
        print('Completed expiration check cycle');
      } catch (e) {
        print('Error in expiration check timer: $e');
      }
    });

    print('Background service initialized successfully');

    // // 🧪 TEST MODE - Set this to true to test with static data
    // final bool testMode = false;
    // final bool testHomeDistance = false;

    // if (testMode) {
    //   print('🧪 TEST MODE: Starting test sequence');

    //   if (testHomeDistance) {
    //     print('🏠 HOME DISTANCE TEST: Starting home distance test');
    //     await _runHomeDistanceTest(distanceNotificationService, user.uid);
    //   } else {
    //     print('📍 REGULAR TEST: Starting static location test');
    //     await _runStaticLocationTest(distanceNotificationService, user.uid);
    //   }

    //   print('🧪 TEST MODE: Test completed');
    //   return; // Stop real location updates during test
    // }

    // Listen for location updates (REAL MODE)
    location.onLocationChanged.listen((LocationData locationData) async {
      if (locationData.latitude == null || locationData.longitude == null) {
        return;
      }

      final latLng = LatLng(locationData.latitude!, locationData.longitude!);

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('UserLocations')
          .doc(user.uid)
          .set({
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'timestamp': DateTime.now(),
      });

      // Check for nearby PWD locations
      print('Checking for PWD locations...');
      pwdNotificationService.checkLocationForNotifications(latLng);

      // Check for nearby regular places
      print('Checking for regular places...');
      placeNotificationService.checkLocationForNotifications(latLng);

      // Check for significant movement and notify space members
      print('Checking for significant movement...');
      distanceNotificationService.checkLocationForNotifications(latLng);

      print('Checking distance to home markers...');
      final userSpaces = await _getUserSpaces(user.uid);
      for (final spaceId in userSpaces) {
        await distanceNotificationService.checkHomeDistance(latLng, spaceId);
      }

      service.invoke('update', {
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
      });
    });

    // Start monitoring for all services
    pwdNotificationService.startLocationMonitoring();
    placeNotificationService.startLocationMonitoring();
    distanceNotificationService.startLocationMonitoring();
    print('Location monitoring started');

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Keep alive
    while (service is AndroidServiceInstance &&
        await service.isForegroundService()) {
      await Future.delayed(const Duration(seconds: 5));
    }
  } catch (e) {
    print('Error in background service: $e');
  }
}

// Future<void> _runHomeDistanceTest(
//     DistanceNotificationService distanceService, String userId) async {
//   try {
//     print('🏠 HOME DISTANCE TEST: Starting home distance notification test');

//     // First, let's create some test home places for other users in your spaces
//     await _createTestHomePlaces(userId);

//     // Get user's spaces
//     final userSpaces = await _getUserSpaces(userId);
//     if (userSpaces.isEmpty) {
//       print('❌ No spaces found for user - cannot test home distance');
//       return;
//     }

//     // Test locations that simulate moving closer/further from home places
//     final testLocations = [
//       {
//         'name': 'Far from Home',
//         'latLng': LatLng(1.5000, 103.8000), // ~16km from test homes
//         'description': 'Starting far away from home locations',
//         'expectedDistance': 16.0
//       },
//       {
//         'name': 'Getting Closer',
//         'latLng': LatLng(1.4200, 103.8200), // ~8km from test homes
//         'description': 'Moving closer to home - should trigger notification',
//         'expectedDistance': 8.0
//       },
//       {
//         'name': 'Very Close',
//         'latLng': LatLng(1.3800, 103.8300), // ~3km from test homes
//         'description': 'Very close to home - should trigger notification',
//         'expectedDistance': 3.0
//       },
//       {
//         'name': 'Moving Away',
//         'latLng': LatLng(1.4500, 103.8000), // ~11km from test homes
//         'description': 'Moving away from home - should trigger notification',
//         'expectedDistance': 11.0
//       },
//     ];

//     print(
//         '🏠 HOME TEST: Starting with ${testLocations.length} test locations around home areas');

//     for (int i = 0; i < testLocations.length; i++) {
//       final location = testLocations[i];
//       final latLng = location['latLng'] as LatLng;

//       print(
//           '🏠 HOME TEST [${i + 1}/${testLocations.length}]: ${location['name']}');
//       print('   📍 Coordinates: ${latLng.latitude}, ${latLng.longitude}');
//       print('   📝 ${location['description']}');
//       print('   🎯 Expected distance: ${location['expectedDistance']} km');

//       // Update Firestore with test location
//       await FirebaseFirestore.instance
//           .collection('UserLocations')
//           .doc(userId)
//           .set({
//         'latitude': latLng.latitude,
//         'longitude': latLng.longitude,
//         'timestamp': DateTime.now(),
//         'is_test_data': true,
//       });

//       // Trigger HOME distance check for each space
//       for (final spaceId in userSpaces) {
//         print('   🔍 Checking home distance for space: $spaceId');
//         await distanceService.checkHomeDistance(latLng, spaceId);
//       }

//       // Wait before next test location to see notifications
//       if (i < testLocations.length - 1) {
//         print('🏠 HOME TEST: Waiting 15 seconds before next location...');
//         await Future.delayed(Duration(seconds: 15));
//       }
//     }

//     print('🏠 HOME TEST: All home distance test locations completed!');
//     print(
//         '🏠 CHECK: Look for HOME distance notifications on other space members devices');
//   } catch (e) {
//     print('❌ HOME TEST ERROR: $e');
//   }
// }

// // Helper method to create test home places for other users
// Future<void> _createTestHomePlaces(String currentUserId) async {
//   try {
//     print('🏠 Creating test home places...');

//     // Get user's spaces and members
//     final userSpaces = await _getUserSpaces(currentUserId);

//     for (final spaceId in userSpaces) {
//       final spaceDoc = await FirebaseFirestore.instance
//           .collection('Spaces')
//           .doc(spaceId)
//           .get();
//       if (!spaceDoc.exists) continue;

//       final members = List<String>.from(spaceDoc.data()?['members'] ?? []);
//       final otherMembers =
//           members.where((memberId) => memberId != currentUserId).toList();

//       if (otherMembers.isEmpty) {
//         print(
//             '   ⚠️ No other members in space $spaceId to create test homes for');
//         continue;
//       }

//       // Create test home places for other members
//       for (int i = 0; i < min(2, otherMembers.length); i++) {
//         // Create max 2 test homes per space
//         final memberId = otherMembers[i];

//         // Check if this member already has a home place
//         final existingHomeQuery = await FirebaseFirestore.instance
//             .collection('Places')
//             .where('userId', isEqualTo: memberId)
//             .where('isHome', isEqualTo: true)
//             .limit(1)
//             .get();

//         if (existingHomeQuery.docs.isNotEmpty) {
//           print('   ✅ Member $memberId already has a home place');
//           continue;
//         }

//         // Create a test home place for this member
//         final testHomeLocation = LatLng(1.3500 + (i * 0.01),
//             103.8000 + (i * 0.01)); // Slightly different locations

//         // Get member info for display name
//         final memberDoc = await FirebaseFirestore.instance
//             .collection('Users')
//             .doc(memberId)
//             .get();
//         final memberData = memberDoc.data();
//         final memberName = memberData?['firstName']?.toString() ??
//             memberData?['username']?.toString() ??
//             'TestUser${i + 1}';

//         final homePlace = {
//           'userId': memberId,
//           'name': '$memberName\'s Home',
//           'category': 'home',
//           'latitude': testHomeLocation.latitude,
//           'longitude': testHomeLocation.longitude,
//           'timestamp': FieldValue.serverTimestamp(),
//           'isHome': true,
//           'source': 'user',
//           'notificationRadius': 100.0,
//           'isFavorite': false,
//         };

//         await FirebaseFirestore.instance.collection('Places').add(homePlace);
//         print(
//             '   🏠 Created test home for $memberName at ${testHomeLocation.latitude}, ${testHomeLocation.longitude}');
//       }
//     }

//     print('✅ Test home places creation completed');
//   } catch (e) {
//     print('❌ Error creating test home places: $e');
//   }
// }

// // 🧪 TEST METHOD: Run static location test sequence
// Future<void> _runStaticLocationTest(
//     DistanceNotificationService distanceService, String userId) async {
//   try {
//     // Test locations (use coordinates that are >5km apart)
//     final testLocations = [
//       {
//         'name': 'Singapore Start',
//         'latLng': LatLng(1.3521, 103.8198),
//         'description': 'Initial position'
//       },
//       {
//         'name': 'North Singapore',
//         'latLng': LatLng(1.4500, 103.8500),
//         'description': '11km away - should trigger notification'
//       },
//       {
//         'name': 'South Singapore',
//         'latLng': LatLng(1.2903, 103.8515),
//         'description': '7km from previous - should trigger'
//       },
//       {
//         'name': 'Far West',
//         'latLng': LatLng(1.3521, 103.6000),
//         'description': '24km from start - should trigger'
//       },
//     ];

//     print('🧪 TEST: Starting with ${testLocations.length} test locations');

//     for (int i = 0; i < testLocations.length; i++) {
//       final location = testLocations[i];
//       final latLng = location['latLng'] as LatLng;

//       print('🧪 TEST [${i + 1}/${testLocations.length}]: ${location['name']}');
//       print('   📍 Coordinates: ${latLng.latitude}, ${latLng.longitude}');
//       print('   📝 ${location['description']}');

//       // Update Firestore with test location
//       await FirebaseFirestore.instance
//           .collection('UserLocations')
//           .doc(userId)
//           .set({
//         'latitude': latLng.latitude,
//         'longitude': latLng.longitude,
//         'timestamp': DateTime.now(),
//         'is_test_data': true, // Mark as test data
//       });

//       // Trigger distance check
//       await distanceService.checkLocationForNotifications(latLng);

//       // Wait before next test location
//       if (i < testLocations.length - 1) {
//         print('🧪 TEST: Waiting 10 seconds before next location...');
//         await Future.delayed(Duration(seconds: 10));
//       }
//     }

//     print('🧪 TEST: All test locations completed!');
//     print(
//         '🧪 CHECK: Look for notifications on this device and other space members devices');
//   } catch (e) {
//     print('❌ TEST ERROR: $e');
//   }
// }

// Helper method: Get user's spaces
Future<List<String>> _getUserSpaces(String userId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('Spaces')
        .where('members', arrayContains: userId)
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  } catch (e) {
    print('Error getting user spaces: $e');
    return [];
  }
}
