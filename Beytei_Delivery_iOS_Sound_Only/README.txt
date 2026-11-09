BEYTEI - DELIVERY COURIER ONLY - iOS SOUND FIX

Use this package only for the DELIVERY COURIER app that has:
    lib/dev/tx.dart

This fix DOES NOT replace lib/data/services/push_notification_service.dart
and DOES NOT modify any Dart/Flutter/Android files or your server.

WHY: Delivery courier NotificationService in lib/dev/tx.dart already
uses iOS sound: woo_sound.caf.
The Laravel server-side FCMService also already asks APNs for woo_sound.caf
in the inspected GitHub source.
Missing step: add CAF sound as an Xcode Runner Bundle Resource.

WINDOWS POWERSHELL:
1. Copy the full folder Beytei_Delivery_iOS_Sound_Only into Flutter project root.
2. Run from project root:
   powershell -NoProfile -ExecutionPolicy Bypass -File ".\Beytei_Delivery_iOS_Sound_Only\install_delivery_ios_sound.ps1" -ProjectPath "."
3. Check git status --short. Confirm only ios/Runner/woo_sound.caf and
   ios/Runner.xcodeproj/project.pbxproj were modified by this script.
4. Commit and push these iOS files, then build new iOS version through Codemagic.
   CRITICAL: Make sure the Codemagic Flutter entrypoint is lib/dev/tx.dart
   rather than lib/main.dart (which belongs to the taxi app).
5. Test with the courier app open, in background, and with the phone locked.

If the earlier, WRONG package has been installed, first restore its modified
lib/data/services/push_notification_service.dart from the backup it created,
or recover it from your last good Git commit after reviewing the diff.

IMPORTANT: Confirm the live server's APNs payload really uses woo_sound.caf.
The repository source already contains that name, but GitHub and server can differ.
Apple notification sounds are subject to device sound/Focus/silent settings.
