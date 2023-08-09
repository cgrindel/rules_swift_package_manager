# stripe Example

## Bazel Integration Notes

### PaymentSheetExample

Had to remove `customModuleProvider="target"` from the `Main.storyboard`. See [this
article](https://forums.swift.org/t/can-a-swift-package-include-a-table-view/40498/6) for details.

Added two values to the `PaymentSheetExample.entitlements` file to address keychain errors. The
values added based upon [feedback in
Slack](https://bazelbuild.slack.com/archives/CD3QY5C2X/p1691568628104189?thread_ts=1691538673.461529&cid=CD3QY5C2X)
and [this article](https://developer.apple.com/forums/thread/666790?answerId=691863022#691863022):

```xml
  <key>com.apple.developer.team-identifier</key>
  <string>TEAMID</string>
  <key>application-identifier</key>
  <string>TEAMID.com.stripe.PaymentSheet-Example</string>
```

Original error when bringing up the "Flow Controller" screens:

```
StripePaymentSheet/LinkSecureCookieStore.swift:56: Assertion failed: Unexpected status code -34018
2023-08-08 17:35:30.544275-0600 iosapp[46149:2011110] StripePaymentSheet/LinkSecureCookieStore.swift:56: Assertion failed: Unexpected status code -34018
```
