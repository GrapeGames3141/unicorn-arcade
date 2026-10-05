#!/usr/bin/env bash
# Export Godot Android release (AAB) + debug APK. Run from repo root on Ubuntu CI or locally.
set -euo pipefail

ROOT="${GODOT_CI_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJECT="${GODOT_PROJECT:-$ROOT/godot}"
GODOT_VERSION="${GODOT_VERSION:-4.7.1}"
GODOT_CHANNEL="${GODOT_CHANNEL:-stable}"
GODOT_TAG="${GODOT_VERSION}-${GODOT_CHANNEL}"
EXPORT_PRESET="${EXPORT_PRESET:-Android Alpha}"
VERSION_CODE="${VERSION_CODE:-1}"
RELEASE_PACKAGE_NAME="${RELEASE_PACKAGE_NAME:-com.grapegames.wlarcade}"
DEBUG_PACKAGE_NAME="${DEBUG_PACKAGE_NAME:-com.guettler.unicornarcade}"
GOOGLE_TEST_BANNER_UNIT_ID="ca-app-pub-3940256099942544/6300978111"

# shellcheck source=install-godot.sh
source "$ROOT/scripts/ci/install-godot.sh"

PRESET_PATH=""
PRESET_BACKUP=""

restore_export_preset() {
	if [[ -n "$PRESET_BACKUP" && -f "$PRESET_BACKUP" && -n "$PRESET_PATH" ]]; then
		cp "$PRESET_BACKUP" "$PRESET_PATH"
		rm -f "$PRESET_BACKUP"
		git -C "$ROOT" diff --exit-code -- godot/export_presets.cfg
	fi
}

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"


require_android_sdk() {
	if [[ -z "${ANDROID_SDK_ROOT}" ]]; then
		echo "ANDROID_SDK_ROOT or ANDROID_HOME must be set" >&2
		return 1
	fi
}

configure_godot_android_paths() {
	local settings_dir="$HOME/.config/godot"
	mkdir -p "$settings_dir"
	local settings_file="$settings_dir/editor_settings-4.tres"
	local java_home="${JAVA_HOME:-}"
	if [[ -z "$java_home" ]] && command -v java >/dev/null 2>&1; then
		java_home="$(readlink -f "$(command -v java)" | sed 's|/bin/java||')"
	fi
	cat >"$settings_file" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "${ANDROID_SDK_ROOT}"
export/android/java_sdk_path = "${java_home}"
EOF
}

start_adb_server() {
	local adb_bin="${ANDROID_SDK_ROOT}/platform-tools/adb"
	if [[ -x "$adb_bin" ]]; then
		"$adb_bin" start-server >/dev/null 2>&1 || true
	elif command -v adb >/dev/null 2>&1; then
		adb start-server >/dev/null 2>&1 || true
	fi
}

write_admob_config() {
	local banner="${1:-${ADMOB_BANNER_UNIT_ID:-$GOOGLE_TEST_BANNER_UNIT_ID}}"
	local enabled="${ADMOB_ADS_ENABLED:-true}"
	mkdir -p "$PROJECT/config"
	cat >"$PROJECT/config/admob.json" <<EOF
{
  "ads_enabled": ${enabled},
  "android_app_id": "ca-app-pub-2846735043546429~3696195593",
  "android_banner_unit_id": "${banner}",
  "child_directed": true,
  "tag_for_under_age_of_consent": false,
  "max_ad_content_rating": "G",
  "show_on_login": false,
  "banner_height_dp": 60
}
EOF
}

# Poing AdMob AARs live under addons/admob/android/bin (gitignored). Without them,
# Godot export skips the native plugin and device builds never show banners.
install_admob_android_binaries() {
	# v5's Next-Gen artifact is not on Google's Families self-certified list.
	# Keep the v5 GDScript banner API with its compatible v4.3.1 Android backend.
	local plugin_version="v4.3.1"
	[[ "$GODOT_VERSION" == "4.7.1" ]] || { echo "ERROR: Families backend is verified for Godot 4.7.1 only" >&2; exit 1; }
	local zip_name="poing-godot-admob-android-v${GODOT_VERSION}.zip"
	local expected_sha="b2429ce2f10c06bec55d3de5273eec6942e4129cf64fccf730d865b5e7d0bfb6"
	local url="https://github.com/poingstudios/godot-admob-plugin/releases/download/${plugin_version}/${zip_name}"
	local cache="${ADMOB_CACHE_DIR:-$HOME/.cache/unicorn-arcade/admob}/$plugin_version"
	local bin_dir="$PROJECT/addons/admob/android/bin"
	local marker="$bin_dir/ads/libs/poing-godot-admob-ads-release.aar"

	mkdir -p "$cache" "$bin_dir"
	if [[ ! -f "$cache/$zip_name" ]]; then
		echo "Downloading AdMob Android template ${zip_name} (${plugin_version})..."
		curl -fsSL -o "$cache/$zip_name" "$url"
	fi
	printf '%s  %s\n' "$expected_sha" "$cache/$zip_name" | sha256sum --check --status || {
		echo "ERROR: Families AdMob Android archive checksum mismatch" >&2; exit 1;
	}
	echo "Extracting AdMob Android binaries into $bin_dir..."
	# Do not install the optional third-party mediation libraries.
	unzip -qo "$cache/$zip_name" 'ads/*' 'package.gd' -d "$bin_dir"
	if [[ ! -f "$marker" || ! -f "$bin_dir/package.gd" ]]; then
		echo "ERROR: AdMob Android binaries missing after extract (expected $marker)" >&2
		exit 1
	fi
	mkdir -p "$PROJECT/build/android/ads-evidence"
	python3 "$ROOT/scripts/ci/verify-family-ads.py" "$bin_dir" | tee "$PROJECT/build/android/ads-evidence/native-backend.txt"
	echo "Families AdMob Android backend installed (${plugin_version}, play-services-ads 24.9.0)"
}

# Match main Capacitor CI: versionCode = run number, versionName = "1.<run_number>".
bump_version() {
	local preset="$PROJECT/export_presets.cfg"
	local version_name="${VERSION_NAME:-1.${VERSION_CODE}}"
	if [[ -n "${MIN_PLAY_VERSION_CODE:-}" ]]; then
		[[ "$VERSION_CODE" =~ ^[0-9]+$ && "$MIN_PLAY_VERSION_CODE" =~ ^[0-9]+$ ]] || {
			echo "ERROR: VERSION_CODE and MIN_PLAY_VERSION_CODE must be integers" >&2
			exit 1
		}
		if (( VERSION_CODE < MIN_PLAY_VERSION_CODE )); then
			echo "ERROR: Android versionCode=${VERSION_CODE} is below the required Play versionCode=${MIN_PLAY_VERSION_CODE}" >&2
			exit 1
		fi
	fi
	sed -i "s/^version\\/code=.*/version\\/code=${VERSION_CODE}/" "$preset"
	sed -i "s/^version\\/name=.*/version\\/name=\"${version_name}\"/" "$preset"
	echo "Android versionCode=${VERSION_CODE} versionName=${version_name}"
}

set_package_name() {
	local package_name="$1"
	local preset="$PROJECT/export_presets.cfg"
	sed -i "s|^package/unique_name=.*|package/unique_name=\"${package_name}\"|" "$preset"
}

godot_import_is_warm() {
	local probe imported_count
	probe="$(ls -1 "$PROJECT/.godot/imported"/unicorn_house_home_v1.png-*.ctex 2>/dev/null | head -1 || true)"
	[[ -n "$probe" && -s "$probe" ]] || return 1
	imported_count="$(find "$PROJECT/.godot/imported" -type f | wc -l | tr -d ' ')"
	# Fresh checkouts with a partial cache can have the probe but almost nothing else.
	[[ "${imported_count:-0}" -ge 200 ]]
}

sanitize_android_build_template() {
	local build_dir="$PROJECT/android/build"
	# The editor-created installer adds this marker, but android_source.zip does
	# not. Without it, Godot scans generated Android resources and writes files
	# such as icon_background.webp.import, which Android's resource merger rejects.
	: >"$build_dir/.gdignore"
	find "$build_dir" -type f -name '*.import' -delete
}

# This app is directed solely to children. Keep Advertising ID out of the final
# merged manifest even when the AdMob SDK or plugin declares it transitively.
enforce_child_directed_manifest() {
	local manifest="$PROJECT/android/build/src/main/AndroidManifest.xml"
	[[ -f "$manifest" ]] || {
		echo "ERROR: Android manifest is missing: $manifest" >&2
		exit 1
	}
	# Recreate the complete block on every run so cached templates cannot retain
	# an older, incomplete version of this policy.
	sed -i \
		-e '/Child-directed app: prevent AdMob dependencies from merging advertising identifiers/d' \
		-e '/com.google.android.gms.permission.AD_ID" tools:node="remove"/d' \
		-e '/android.permission.AD_ID" tools:node="remove"/d' \
		-e '/android.permission.ACCESS_ADSERVICES_AD_ID" tools:node="remove"/d' \
		-e '/android.permission.ACCESS_ADSERVICES_ATTRIBUTION" tools:node="remove"/d' \
		-e '/android.permission.ACCESS_ADSERVICES_TOPICS" tools:node="remove"/d' \
		"$manifest"
	sed -i '/^[[:space:]]*<supports-screens/i\
    <!-- Child-directed app: prevent AdMob dependencies from merging advertising identifiers. -->\
    <uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove" />\
    <uses-permission android:name="android.permission.AD_ID" tools:node="remove" />\
    <uses-permission android:name="android.permission.ACCESS_ADSERVICES_AD_ID" tools:node="remove" />\
    <uses-permission android:name="android.permission.ACCESS_ADSERVICES_ATTRIBUTION" tools:node="remove" />\
    <uses-permission android:name="android.permission.ACCESS_ADSERVICES_TOPICS" tools:node="remove" />\
' "$manifest"
	local removal_count
	removal_count="$(grep -Ec 'permission\.(AD_ID|ACCESS_ADSERVICES_(AD_ID|ATTRIBUTION|TOPICS))" tools:node="remove"' "$manifest")"
	[[ "$removal_count" == "5" ]] || {
		echo "ERROR: Failed to install all advertising-identifier manifest-removal rules" >&2
		exit 1
	}
}

ensure_android_build_template() {
	local marker="$PROJECT/android/build/build.gradle"
	local build_version_marker="$PROJECT/android/build/.build_version"
	local actual_version=""
	local expected_version godot_aar template_dir android_source
	validate_tracked_android_build_version
	expected_version="$(expected_android_build_version)"
	godot_aar="$(find "$PROJECT/android/build/libs" -name 'godot-lib*.aar' -type f 2>/dev/null | head -1 || true)"
	if [[ -f "$build_version_marker" ]]; then
		actual_version="$(tr -d '\r\n' <"$build_version_marker")"
	fi
	if [[ -f "$marker" && -n "$godot_aar" && -s "$godot_aar" && "$actual_version" == "$expected_version" ]]; then
		sanitize_android_build_template
		echo "Android build template cache accepted (${expected_version}); skipping install."
		return 0
	fi
	if [[ -f "$marker" || -n "$godot_aar" ]]; then
		echo "Rejecting Android build template cache: marker '${actual_version:-missing}', expected '${expected_version}'."
	fi

	# Never call `godot --install-android-build-template` alone in CI: headless Godot
	# prints the engine banner and then sits in the editor until the job times out.
	# Extract android_source.zip from the export templates instead (same payload).
	template_dir="$(android_export_template_dir)"
	android_source="$GODOT_SHARE_DIR/export_templates/${template_dir}/android_source.zip"
	[[ -s "$android_source" ]] || {
		echo "ERROR: missing Android source template at $android_source" >&2
		exit 1
	}

	echo "Installing Android build template from ${android_source} (unzip, no Godot)..."
	rm -rf "$PROJECT/android/build"
	mkdir -p "$PROJECT/android/build"
	unzip -qo "$android_source" -d "$PROJECT/android/build"
	chmod +x "$PROJECT/android/build/gradlew"
	printf '%s\n' "$expected_version" >"$PROJECT/android/build/.build_version"
	sanitize_android_build_template

	godot_aar="$(find "$PROJECT/android/build/libs" -name 'godot-lib*.aar' -type f 2>/dev/null | head -1 || true)"
	[[ -f "$marker" && -n "$godot_aar" && -s "$godot_aar" ]] || {
		echo "ERROR: Android build template extract did not produce godot-lib*.aar" >&2
		exit 1
	}
	echo "Android build template ready ($(du -sh "$PROJECT/android/build" | cut -f1))"
}

preflight_android_sdk() {
	local config="$PROJECT/android/build/config.gradle"
	local required_compile_sdk required_build_tools required_ndk
	[[ -f "$config" ]] || { echo "ERROR: Android build template config is missing: $config" >&2; exit 1; }

	required_compile_sdk="$(sed -nE 's/^[[:space:]]*compileSdk[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p' "$config")"
	required_build_tools="$(sed -nE "s/^[[:space:]]*buildTools[[:space:]]*:[[:space:]]*'([^']+)'.*/\1/p" "$config")"
	required_ndk="$(sed -nE "s/^[[:space:]]*ndkVersion[[:space:]]*:[[:space:]]*'([^']+)'.*/\1/p" "$config")"
	[[ "$required_compile_sdk" =~ ^[0-9]+$ ]] || { echo "ERROR: Could not read compileSdk from $config. Update this preflight for the current Godot template." >&2; exit 1; }
	[[ -n "$required_build_tools" ]] || { echo "ERROR: Could not read buildTools from $config. Update this preflight for the current Godot template." >&2; exit 1; }
	[[ -n "$required_ndk" ]] || { echo "ERROR: Could not read ndkVersion from $config. Update this preflight for the current Godot template." >&2; exit 1; }

	if [[ -n "${CI_ANDROID_COMPILE_SDK:-}" && "$CI_ANDROID_COMPILE_SDK" != "$required_compile_sdk" ]]; then
		echo "ERROR: Android build template requires API ${required_compile_sdk}, but CI provisions CI_ANDROID_COMPILE_SDK=${CI_ANDROID_COMPILE_SDK}. Update deploy-android.yml." >&2
		exit 1
	fi
	if [[ -n "${CI_ANDROID_BUILD_TOOLS_VERSION:-}" && "$CI_ANDROID_BUILD_TOOLS_VERSION" != "$required_build_tools" ]]; then
		echo "ERROR: Android build template requires build-tools ${required_build_tools}, but CI provisions CI_ANDROID_BUILD_TOOLS_VERSION=${CI_ANDROID_BUILD_TOOLS_VERSION}. Update deploy-android.yml." >&2
		exit 1
	fi
	if [[ -n "${CI_ANDROID_NDK_VERSION:-}" && "$CI_ANDROID_NDK_VERSION" != "$required_ndk" ]]; then
		echo "ERROR: Android build template requires NDK ${required_ndk}, but CI provisions CI_ANDROID_NDK_VERSION=${CI_ANDROID_NDK_VERSION}. Update deploy-android.yml." >&2
		exit 1
	fi

	[[ -f "$ANDROID_SDK_ROOT/platforms/android-${required_compile_sdk}/android.jar" ]] || {
		echo "ERROR: Android API ${required_compile_sdk} is missing from $ANDROID_SDK_ROOT. Install platforms;android-${required_compile_sdk}." >&2
		exit 1
	}
	[[ -x "$ANDROID_SDK_ROOT/build-tools/${required_build_tools}/aapt2" ]] || {
		echo "ERROR: Android build-tools ${required_build_tools} is missing from $ANDROID_SDK_ROOT. Install build-tools;${required_build_tools}." >&2
		exit 1
	}
	[[ -f "$ANDROID_SDK_ROOT/ndk/${required_ndk}/source.properties" ]] || {
		echo "ERROR: Android NDK ${required_ndk} is missing from $ANDROID_SDK_ROOT. Install ndk;${required_ndk}." >&2
		exit 1
	}

	echo "Android SDK preflight OK (API ${required_compile_sdk}, build-tools ${required_build_tools}, NDK ${required_ndk})"
}

build_legacy_profile_bridge() {
	local bridge="$PROJECT/android/legacy_profile_bridge"
	local output="$PROJECT/android/plugins"
	local godot_aar
	[[ -d "$bridge" ]] || { echo "ERROR: legacy bridge source missing" >&2; exit 1; }
	godot_aar="$(find "$PROJECT/android/build/libs/release" -name 'godot-lib*.aar' -type f | head -1)"
	[[ -z "$godot_aar" ]] && godot_aar="$(find "$PROJECT/android/build/libs" -name 'godot-lib*.aar' -type f | head -1)"
	[[ -n "$godot_aar" && -f "$godot_aar" ]] || { echo "ERROR: generated Godot library AAR missing" >&2; exit 1; }
	mkdir -p "$output"
	GODOT_ANDROID_LIBRARY_AAR="$godot_aar" LEGACY_BRIDGE_OUTPUT_DIR="$output" \
		"$PROJECT/android/build/gradlew" -p "$bridge" copyReleaseAar
	[[ -s "$output/legacy_profile_bridge.aar" ]] || { echo "ERROR: legacy bridge AAR was not built" >&2; exit 1; }
	cp "$bridge/legacy_profile_bridge.gdap" "$output/legacy_profile_bridge.gdap"
	[[ -s "$output/legacy_profile_bridge.gdap" ]] || { echo "ERROR: legacy bridge plugin descriptor was not installed" >&2; exit 1; }
}

set_export_format() {
	local format="$1"
	local preset="$PROJECT/export_presets.cfg"
	sed -i "s/^gradle_build\/export_format=.*/gradle_build\/export_format=${format}/" "$preset"
}

standalone_bundletool() {
	local version="${BUNDLETOOL_VERSION:-1.16.0}"
	local cache_dir="${BUNDLETOOL_CACHE_DIR:-$HOME/.cache/unicorn-arcade/bundletool}"
	local jar="${BUNDLETOOL_JAR:-$cache_dir/bundletool-all-${version}.jar}"
	if [[ ! -s "$jar" ]]; then
		mkdir -p "$cache_dir"
		# Status must go to stderr: callers capture stdout as the jar path.
		echo "Downloading official Bundletool ${version} for AAB validation..." >&2
		curl -fsSL -o "$jar" "https://github.com/google/bundletool/releases/download/${version}/bundletool-all-${version}.jar"
	fi
	[[ -s "$jar" ]] || { echo "ERROR: standalone Bundletool download is empty" >&2; exit 1; }
	java -jar "$jar" version >/dev/null || { echo "ERROR: standalone Bundletool is not executable" >&2; exit 1; }
	printf '%s\n' "$jar"
}

validate_artifact() {
	local artifact="$1" package_name="$2" expected_code="$3" expected_name="$4"
	local permissions=""
	[[ -s "$artifact" ]] || { echo "ERROR: missing Android artifact $artifact" >&2; exit 1; }
	if [[ "$artifact" == *.apk ]]; then
		local apkanalyzer="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/apkanalyzer"
		[[ -x "$apkanalyzer" ]] || apkanalyzer="$(find "${ANDROID_SDK_ROOT}/cmdline-tools" -name apkanalyzer -type f | head -1)"
		[[ -x "$apkanalyzer" ]] || { echo "ERROR: apkanalyzer is required for APK metadata validation" >&2; exit 1; }
		permissions="$("$apkanalyzer" manifest permissions "$artifact")"
		[[ "$("$apkanalyzer" manifest application-id "$artifact")" == "$package_name" ]] || { echo "ERROR: APK package mismatch" >&2; exit 1; }
		[[ "$("$apkanalyzer" manifest version-code "$artifact")" == "$expected_code" ]] || { echo "ERROR: APK versionCode mismatch" >&2; exit 1; }
		[[ "$("$apkanalyzer" manifest version-name "$artifact")" == "$expected_name" ]] || { echo "ERROR: APK versionName mismatch" >&2; exit 1; }
	else
		local bundletool
		bundletool="$(standalone_bundletool)"
		permissions="$(java -jar "$bundletool" dump manifest --bundle="$artifact" --xpath='/manifest/uses-permission/@android:name')"
		[[ "$(java -jar "$bundletool" dump manifest --bundle="$artifact" --xpath=/manifest/@package)" == "$package_name" ]] || { echo "ERROR: AAB package mismatch" >&2; exit 1; }
		[[ "$(java -jar "$bundletool" dump manifest --bundle="$artifact" --xpath=/manifest/@android:versionCode)" == "$expected_code" ]] || { echo "ERROR: AAB versionCode mismatch" >&2; exit 1; }
		[[ "$(java -jar "$bundletool" dump manifest --bundle="$artifact" --xpath=/manifest/@android:versionName)" == "$expected_name" ]] || { echo "ERROR: AAB versionName mismatch" >&2; exit 1; }
	fi
	if grep -Eq '^(com\.google\.android\.gms\.permission\.AD_ID|android\.permission\.(AD_ID|ACCESS_ADSERVICES_(AD_ID|ATTRIBUTION|TOPICS)))$' <<<"$permissions"; then
		echo "ERROR: Advertising identifier permission leaked into $artifact" >&2
		grep -E '^(com\.google\.android\.gms\.permission\.AD_ID|android\.permission\.(AD_ID|ACCESS_ADSERVICES_(AD_ID|ATTRIBUTION|TOPICS)))$' <<<"$permissions" >&2
		exit 1
	fi
	echo "Advertising identifier manifest check OK: no advertising ID or AdServices permissions in $(basename "$artifact")"
}

ensure_godot_import() {
	# Cold import of this project's GLBs/textures is ~30+ minutes. Skip when a
	# validated Actions cache already has the imported .ctex tree.
	if [[ "${FORCE_GODOT_IMPORT:-0}" != "1" ]] && godot_import_is_warm; then
		echo "Warm Godot import cache detected ($(du -sh "$PROJECT/.godot/imported" | cut -f1)); skipping --import."
		return 0
	fi
	echo "Importing project assets (cold or forced)..."
	godot --headless --path "$PROJECT" --import
	if ! godot_import_is_warm; then
		echo "ERROR: Godot import did not produce a usable .godot/imported cache" >&2
		exit 1
	fi
	echo "Godot import OK ($(du -sh "$PROJECT/.godot/imported" | cut -f1))"
}

export_android() {
	mkdir -p "$PROJECT/build/android"
	PRESET_PATH="$PROJECT/export_presets.cfg"
	PRESET_BACKUP="$(mktemp)"
	cp "$PRESET_PATH" "$PRESET_BACKUP"
	trap restore_export_preset EXIT
	install_admob_android_binaries
	# Runs inside the actual export's Gradle invocation, with Godot's resolved
	# plugin arguments. A separate `gradle dependencies` command would omit them.
	local gradle_home="${GRADLE_USER_HOME:-$HOME/.gradle}"
	mkdir -p "$gradle_home/init.d"
	cp "$ROOT/scripts/ci/families-ads.init.gradle" "$gradle_home/init.d/unicorn-families-ads.gradle"
	export UNICORN_ADS_EVIDENCE_DIR="$PROJECT/build/android/ads-evidence"
	local release_banner="${ADMOB_RELEASE_BANNER_UNIT_ID:-${ADMOB_BANNER_UNIT_ID:-$GOOGLE_TEST_BANNER_UNIT_ID}}"
	local debug_banner="${ADMOB_DEBUG_BANNER_UNIT_ID:-$GOOGLE_TEST_BANNER_UNIT_ID}"
	write_admob_config "$release_banner"
	bump_version
	set_export_format 1
	configure_godot_android_paths
	start_adb_server
	ensure_godot_import
	# Template install before bridge + export so we only pay for one Godot project load.
	ensure_android_build_template
	enforce_child_directed_manifest
	preflight_android_sdk
	build_legacy_profile_bridge

	local ads_aar="$PROJECT/addons/admob/android/bin/ads/libs/poing-godot-admob-ads-release.aar"
	if [[ ! -f "$ads_aar" ]]; then
		echo "ERROR: Refusing to export without AdMob AAR at $ads_aar" >&2
		exit 1
	fi

	echo "Exporting Play release AAB as ${RELEASE_PACKAGE_NAME}..."
	set_package_name "$RELEASE_PACKAGE_NAME"
	set_export_format 1
	godot --headless --path "$PROJECT" --verbose \
		--export-release "$EXPORT_PRESET" "$PROJECT/build/android/UnicornArcade.aab"
	validate_artifact "$PROJECT/build/android/UnicornArcade.aab" "$RELEASE_PACKAGE_NAME" "$VERSION_CODE" "${VERSION_NAME:-1.${VERSION_CODE}}"

	echo "Exporting installable debug APK as ${DEBUG_PACKAGE_NAME}..."
	write_admob_config "$debug_banner"
	set_package_name "$DEBUG_PACKAGE_NAME"
	local preset="$PROJECT/export_presets.cfg"
	set_export_format 0
	sed -i 's|^export_path=.*|export_path="build/android/UnicornArcade-debug.apk"|' "$preset"
	godot --headless --path "$PROJECT" --verbose \
		--export-debug "$EXPORT_PRESET" "$PROJECT/build/android/UnicornArcade-debug.apk"
	validate_artifact "$PROJECT/build/android/UnicornArcade-debug.apk" "$DEBUG_PACKAGE_NAME" "$VERSION_CODE" "${VERSION_NAME:-1.${VERSION_CODE}}"
	set_export_format 1
	sed -i 's|^export_path=.*|export_path="build/android/UnicornArcade.aab"|' "$preset"
	restore_export_preset
	trap - EXIT
}

main() {
	require_android_sdk
	validate_tracked_android_build_version
	install_godot
	install_godot_export_templates
	export_android
	echo "Done: $PROJECT/build/android/UnicornArcade.aab"
	echo "Done: $PROJECT/build/android/UnicornArcade-debug.apk"
}


if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
