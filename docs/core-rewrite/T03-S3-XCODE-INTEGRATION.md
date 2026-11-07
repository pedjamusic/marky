# T03.S3 — Swift package and static Xcode integration

## Candidate

2026-11-07, based on `main/dd7c7e05849358f8daca46ed0f3977d87935220e`. Built from an isolated snapshot of the base with the T03.S3 edits. macOS 27.2 (26B123), arm64, Xcode 27.2 (27B52), macOS SDK 27.2, Apple Swift 6.4.2, Apple Clang 21.0.0 (clang-2100.4.1.1), CMake/CTest 4.4.5.

[Package.swift](../../core/Package.swift) defines a local static product and compiles `src/BuildInfo.cpp` as C++20. The [Xcode project](../../Marky.xcodeproj/project.pbxproj) adds it to the Marky app target. SwiftPM's public headers directory is empty pending T04. The private probe header, CMake manifest, C++ sources, harness and app Swift code are byte-identical to the base.

| Input or output | SHA-256 |
| --- | --- |
| `core/Package.swift` | `aa4cd89dd0f8729fb9b97df7a4e2b9c0fbfdabab60bb449bc601c6a08922e55b` |
| `Marky.xcodeproj/project.pbxproj` | `049d12784dc11b704101a368ff17fa3150e48cada57de6408d620034d950dec8` |
| `core/src/BuildInfo.cpp` | `bd272540c6a3286465742aa92c6c53a70083b03c161d011b38eab413fd1bb56d` |
| `core/CMakeLists.txt` | `770be28237e8bf4d0466c9a4e6c057a73a5bf4abf8337edfb246dc8bb1486db5` |
| Release `Marky.app/Contents/MacOS/Marky` | `173d46540cd741e7373742052ee8b784212dac61a47f3193a420fa7945010554` |

## Verification

Xcode ran the following from the candidate root. `$checks` was a fresh temporary output directory. The destination was native macOS arm64 in all three runs.

```bash
xcode_args=(-project Marky.xcodeproj -scheme Marky -destination 'platform=macOS,arch=arm64'
  -disableAutomaticPackageResolution -disablePackageRepositoryCache LD_GENERATE_MAP_FILE=YES)

xcodebuild "${xcode_args[@]}" -configuration Debug -derivedDataPath "$checks/xcode-debug" \
  -resultBundlePath "$checks/marky-unit.xcresult" -only-testing:MarkyTests test
xcodebuild "${xcode_args[@]}" -configuration Release -derivedDataPath "$checks/xcode-release" build
xcodebuild "${xcode_args[@]}" -configuration Debug -derivedDataPath "$checks/xcode-debug" \
  -resultBundlePath "$checks/marky-ui.xcresult" -parallel-testing-enabled NO \
  -only-testing:MarkyUITests/MarkyUITests/testSidebarSearchAndSelectionDisplaysDocument test
```

- The Debug build and all 106 unit tests passed. The focused reader UI test passed. Both result bundles report zero failures and zero skips.
- The Release build passed. `codesign --verify --deep --strict` passed and the app has sandbox and user-selected read-only entitlements. The native reader smoke ran under Xcode's UI-test runner. Release user acceptance is recorded below.
- Both Xcode builds compiled `core/src/BuildInfo.cpp` with `-std=c++20`. Each app target's `Marky.LinkFileList` contains `MarkyCore.o` once. Xcode uses a relocatable arm64 Mach-O object for this static product. The Debug app code in `Marky.debug.dylib` contains the probe symbol and the Release app's link map attributes the symbol to `MarkyCore.o`. `otool -L` on the app's Mach-O binaries and bundle inspection found no separate MarkyCore runtime library.
- `xcrun clang++ -std=c++20 -fprofile-instr-generate -Icore/src core/tests/CoreTests.cpp "$object" -o "$smoke"` linked the unchanged smoke harness against each Xcode-built object. Both executables passed. The profile flag supplies Apple's coverage runtime for the Xcode-built objects. This exercises the C++ object independently of the app's Swift reader.
- Xcode resolved only the local package with automatic resolution and the repository cache disabled. There were no package checkouts or lockfile. SwiftPM's package description reports a static library, no dependencies, and the same one production source as CMake. `xcrun swift build --package-path core --scratch-path "$checks/swiftpm" --disable-dependency-cache --disable-sandbox --disable-automatic-resolution --product MarkyCore` also passed and produced a static archive containing `MarkyCore.o`. For the restricted shell, `CLANG_MODULE_CACHE_PATH` pointed to a writable scratch directory and SwiftPM reported user cache access warnings. `swift package` with the same path, scratch and cache options and `describe --type json` supplied the manifest evidence.
- Fresh Mac CMake Debug and Release builds each passed 1/1 CTest, failed as expected with the intentional harness setting (CTest exit 8), then passed 1/1 again. Commands are in the [standalone procedures](../../core/README.md#macos). The configure runs added `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` to compare the compiled production source with SwiftPM and Xcode.

The restricted shell initially prevented Xcode from writing its normal manifest and module caches and prevented the signing trust check. Retrying with access to the Mac build and trust services passed. Xcode reported an outdated iOS simulator service and skipped AppIntents metadata extraction. The destination was macOS and there were no C++ or Swift compiler warnings.

## Acceptance and handoff

The user reported **PASS** ("pass") on 2026-11-07 for the signed Release candidate **0.2.4 (5)** at `/tmp/MarkyT03S3.cfOmdD/checks/xcode-release/Build/Products/Release/Marky.app`. The requested smoke was to launch this bundle, open a local Markdown folder, select a document, quit and relaunch to check access restoration. The user reported the aggregate result. The accepted binary and build inputs match E28; this acceptance record adds no new automated execution.

Windows/MSVC and Linux/GCC executions remain open under B03/OWE-T03. The core has no document API yet. T04.S1 is the next seam slice after this handoff. See [status](STATUS.md) for live acceptance and Git authorization.
