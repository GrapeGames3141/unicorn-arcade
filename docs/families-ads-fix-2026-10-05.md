# Child-directed banner release contract

Unicorn Arcade (`com.grapegames.wlarcade`) serves children only. This change addresses
SDK eligibility and initialization safeguards; it does not identify the rejected ad
or promise Google Play approval.

## Android integration

- Retain the existing Poing 5 GDScript banner wrappers and layout. Use the compatible
  **Poing Android v4.3.1 backend for Godot 4.7.1**, with
  **`com.google.android.gms:play-services-ads:24.9.0`**. The installed archive declares
  that exact dependency. No Next-Gen SDK or third-party mediation is exported.
- Google's Families self-certified list explicitly includes this Maven artifact at
  versions 19.0.0 and later:
  https://support.google.com/googleplay/android-developer/answer/12955712?hl=en
- Version 24.9.0 is an official stable SDK release:
  https://developers.google.com/admob/android/rel-notes
- Backend archive:
  https://github.com/poingstudios/godot-admob-plugin/releases/download/v4.3.1/poing-godot-admob-android-v4.7.1.zip
  SHA-256: `b2429ce2f10c06bec55d3de5273eec6942e4129cf64fccf730d865b5e7d0bfb6`.
- The pinned compiled backend is checked with `javap` for legacy targeting calls
  and the banner/size JNI methods actually used by the game. Its banner API matches
  the wrappers; the v5 revenue signal is optional on this backend. Other v5-only
  Android APIs are not supported by this integration and must not be enabled.

## First-request protection

`ChildAdsPolicy` always creates TFCD TRUE, max G, and TFUA UNSPECIFIED. Google says
TFCD and TFUA should not both be TRUE; TFCD owns this child-only app. Unsafe
child-directed or content-rating configuration disables ads. The wrapper applies
the request configuration and registers its completion listener before invoking
the legacy SDK's initialization. The banner loads after initialization completes.

Official legacy SDK guidance:
https://developers.google.com/admob/android/targeting

## Release evidence and acceptance

- The focused Godot test verifies unsafe-config rejection, configuration values at
  the native boundary, call order, and an immediate initialization callback.
- CI checks the pinned backend archive and compiled native targeting/banner API.
- A Gradle gate checks the actual debug and release export dependency graphs for
  exact `play-services-ads:24.9.0`, rejecting Next-Gen and mediation adapters before
  packaging. Reports are retained as `UnicornArcade-ads-evidence`.
- Existing final APK/AAB checks retain package/version and absence of advertising-ID
  and AdServices permissions. Debug uses Google's test banner; release uses the
  configured production banner. Both retain the same child-directed G policy.
- A main push requests **internal testing**, not production. Following rejection,
  Google may require resubmission/review before availability.
- Physical-device first-ad behavior, the exact offending creative/network, and
  current account-side category settings remain separate evidence requirements.

The August checklist in `admob-family-ad-bar.md` is historical. This release
contract supersedes its SDK/configuration guidance; it does not change the audience.
