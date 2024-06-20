# google_maps Example

This example was copied from [one the demos example in
maps-sdk-for-ios-samples](https://github.com/googlemaps-samples/maps-sdk-for-ios-samples/tree/main/GoogleMaps-Swift/GoogleMapsSwiftDemos). It was simplified in order to avoid too large of an example.

## Why is this interesting?

The Google [ios-maps-sdk](https://github.com/googlemaps/ios-maps-sdk) downloads a static xcframework. This
exercises the xcframework static library detection logic in `rules_swift_package_manager`.  
Additionally, the SDK is patched in order to remove an additional `import` that would otherwise prevent it from compiling using `rules_swift_package_manager`.
