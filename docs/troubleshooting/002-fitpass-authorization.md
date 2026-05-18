# FitPass Authorization Persistence Issue

- **ID**: TR-002
- **Status**: Investigating
- **Linked Issue**: [redroid-script-eee]

## Description
FitPass app starts on the emulator but requires login. The transplanted data from the physical device contains an encrypted session that the emulator cannot decrypt.

## Findings
1.  **Hardware-Bound Keys**: The app uses `flutter_secure_storage`, which relies on the Android KeyStore.
2.  **Version Incompatibility**: 
    - Physical Phone (Android 15) uses **Keystore 2.0** (`persistent.sqlite`).
    - Emulator (Android 11) uses **Legacy Keystore** (file-based in `user_0/`).
    - Binary transplantation of keys is impossible across these versions.
3.  **Plaintext Extraction**: Successfully extracted the plaintext JWT `accessToken` from the phone using Frida 16.6.6.
4.  **Injection Blocker**: Frida on the ReDroid emulator crashes with a `NullPointerException` when initializing the Java bridge, preventing automated injection of the plaintext token.

## Extracted Data (Reference)
- **Plaintext Access Token**: eyJ0eXAiOiJKV1Qi... (Stored in debug/tasks/fitpass/frida_retry.log)
- **App Package**: rs.abstract.fitpass
- **Secure Storage Key**: VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg_accessToken

## Next Steps
- [ ] Perform a **manual login** on the emulator one time.
- [ ] Capture the resulting authorized `/data/data/` and `/data/misc/keystore/user_0/` files from the emulator.
- [ ] Integrate these "native" authorized files into `stuff/apps.py` for a permanent pre-authorized build.
