# Mandatory Google Play updates

Android 1.0.18+25 introduces an app-wide Google Play update gate. It checks at
startup and whenever the app resumes, covering login, restored sessions, all
portal routes, and notification-driven navigation. Web and non-Android targets
keep their existing behaviour.

When Google Play reports a newer version for the current user/device, the app
saves that required version code and starts Play's immediate update flow. There
is no Later/Skip option in the app. Cancellation or failure leaves an opaque
blocking screen over the entire Navigator, with Update now, Open Google Play,
and Check again actions. Underlying controls, focus and semantics are blocked.
Employees can close the app, but reopening keeps a confirmed requirement.

If only a flexible update is permitted, the app stays blocked throughout its
download and completion. Interrupted immediate updates resume on the next check.
If Play's in-app flow cannot start, the store button opens the app's Play listing,
with an HTTPS browser fallback if the Play app is unavailable.

A reported update success never unlocks the old build. The native installed
version code must reach the saved required version before access is restored.
The saved requirement is retained through later check/network failures and app
restarts, and cleared once the new build is installed.

## Google Play requirements and limits

Android does not allow this app to silently install a release without user
consent. Employees may enable Google Play's automatic updates, but Play controls
whether and when those run. The mandatory gate is the fallback when a newer
eligible version is available and has not been installed yet.

Publish a signed AAB with a higher version code to the appropriate Play track.
The employee's Play account and device must be eligible for that release;
staged rollout percentages, track membership, Play caching and device conditions
can affect availability. Sideloaded APKs and devices without Play cannot reliably
use the in-app update API. A failed check with no previously confirmed update
does not invent a version requirement or lock employees out indefinitely.
This is a client access policy, not a server authorization boundary.

Employees on older releases need one initial update to 1.0.18+25 or newer to gain
this enforcement. Older installed code cannot be changed remotely. Once this
release is installed, future eligible Play updates are checked and enforced
automatically without HR having to send update reminders each time.

## Validation

Tests cover no-update and unknown availability, mandatory persistence across
cancellation/restart/network failure, installed-build verification, interrupted
immediate updates, flexible download completion, store fallback, route coverage,
resume checks and unaffected web behaviour. Native helpers read the actual
installed Android package version and open that package's Play listing.

A real Play-installed Android device on an eligible test track is required to
verify Play's installation UI and restart behaviour. Flutter tests and a web
build do not establish that an AAB has been published or installed from Play.
