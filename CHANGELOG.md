## 2.1.0

* Remove unused `ACCESS_BACKGROUND_LOCATION` permission from the Android manifest.
* Upgrade Android toolchain (AGP, Kotlin, Gradle, compileSdk, Java 17) for compatibility with recent Flutter/Android Studio versions.
* Update example iOS project (deployment target, Podfile) for compatibility with current Xcode/CocoaPods tooling.
* Add `ArSensorSource` interface so sensors can be injected into `ArView`/`ArLocationWidget` instead of relying on a hardcoded singleton.
* Extract annotation positioning/collision logic into a standalone `AnnotationLayoutEngine`, unit tested independently of Flutter widgets.
* Fix `ArView` performing side effects (position updates, `onLocationChange`) during `build()`.
* Fix potential incorrect widget reconciliation by keying annotation views with `ValueKey(annotation.uid)`.
* Improve performance of annotation overlap resolution (O(n²) to O(n log n) in the common case).

## 20.16
* Upgrade sensor

## 2.0.15
* Update gradle

## 2.0.12

* Solve scale camera

## 2.0.11

* Update dependencies
* add permission HIGH_SAMPLING_RATE_SENSORS for android 12

## 2.0.5

* Solve ArPluginsNotFound for Android

## 2.0.0

* Add radar.

## 1.0.0

* Add documentation.

## 0.0.5

* Resolve bug.

## 0.0.4

* Filter pitch.

## 0.0.3

* Update example with fake annotation.
* Resolve offset for overlap annotation sort annotation for distance user

## 0.0.2

*  Update example.

## 0.0.1

*  Describe initial release.
