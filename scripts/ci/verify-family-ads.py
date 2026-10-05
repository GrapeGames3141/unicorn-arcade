#!/usr/bin/env python3
"""Check the pinned compiled backend and the Godot/native banner contract."""
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

root = Path(sys.argv[1])
assert '"v4.3.1"' in (root / 'package.gd').read_text(), 'Wrong native backend version'
descriptor = (root / 'ads/poing_godot_admob_ads.gd').read_text()
assert 'com.google.android.gms:play-services-ads:24.9.0' in descriptor, 'Wrong SDK dependency'
assert 'ads-mobile-sdk' not in descriptor, 'Next-Gen dependency forbidden'
for variant in ('debug', 'release'):
    with zipfile.ZipFile(root / f'ads/libs/poing-godot-admob-ads-{variant}.aar') as aar:
        classes = aar.read('classes.jar')
    with zipfile.ZipFile(io.BytesIO(classes)) as jar:
        all_classes = b''.join(jar.read(n) for n in jar.namelist() if n.endswith('.class'))
        assert b'com/google/android/libraries/ads/mobile/sdk' not in all_classes, 'Next-Gen native code forbidden'
    with tempfile.TemporaryDirectory(prefix='unicorn-family-ads-') as temp:
        path = Path(temp) / 'classes.jar'
        path.write_bytes(classes)
        def inspect(name):
            return subprocess.check_output(['javap', '-c', '-p', '-classpath', str(path),
                'com.poingstudios.godot.admob.ads.' + name], text=True)
        mobile = inspect('PoingGodotAdMob')
        for call in ('setMaxAdContentRating', 'setTagForChildDirectedTreatment',
                     'setTagForUnderAgeOfConsent', 'MobileAds.setRequestConfiguration', 'MobileAds.initialize'):
            assert call in mobile, f'Missing legacy native targeting call: {call}'
        assert 'InitializationConfig' not in mobile, 'Unexpected Next-Gen initialization'
        banner = inspect('PoingGodotAdMobAdView')
        for signature in ('create(org.godotengine.godot.Dictionary)',
                          'load_ad(int, org.godotengine.godot.Dictionary, java.lang.String[])',
                          'get_height_in_pixels(int)', 'show(int)', 'destroy(int)'):
            assert signature in banner, f'Banner wrapper mismatch: {signature}'
        size = inspect('PoingGodotAdMobAdSize')
        assert 'getCurrentOrientationAnchoredAdaptiveBannerAdSize(int)' in size
    print(f'CHILD_ADS_NATIVE_OK {variant}: v4.3.1; legacy targeting and banner JNI contract verified')
