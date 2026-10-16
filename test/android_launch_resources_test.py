"""Regression checks for the pre-Flutter Android starting window."""

from pathlib import Path
import unittest
import xml.etree.ElementTree as ET


RES = Path(__file__).resolve().parents[1] / "android/app/src/main/res"


class AndroidLaunchResourcesTest(unittest.TestCase):
    def test_pre_android_12_hides_the_os_themed_preview(self):
        for variant in ("values", "values-night"):
            with self.subTest(variant=variant):
                root = ET.parse(RES / variant / "styles.xml").getroot()
                launch = root.find("style[@name='LaunchTheme']")
                self.assertEqual(
                    launch.find("item[@name='android:windowDisablePreview']").text,
                    "true",
                )

    def test_android_12_does_not_show_a_second_smaller_logo(self):
        for variant, color in (("values-v31", "#FFFFFF"), ("values-night-v31", "#252525")):
            with self.subTest(variant=variant):
                root = ET.parse(RES / variant / "styles.xml").getroot()
                launch = root.find("style[@name='LaunchTheme']")
                self.assertEqual(
                    launch.find("item[@name='android:windowSplashScreenAnimatedIcon']").text,
                    "@android:color/transparent",
                )
                self.assertEqual(
                    launch.find("item[@name='android:windowSplashScreenBackground']").text,
                    color,
                )

    def test_no_starting_window_retains_the_fixed_size_artwork(self):
        for path in RES.glob("drawable*/launch_background.xml"):
            with self.subTest(path=path):
                self.assertNotIn("launch_veil", path.read_text())

    def test_both_adaptive_masks_use_the_ios_artwork(self):
        for name in ("ic_launcher", "ic_launcher_round"):
            root = ET.parse(RES / f"mipmap-anydpi-v26/{name}.xml").getroot()
            self.assertEqual(
                root.find("foreground").get("{http://schemas.android.com/apk/res/android}drawable"),
                "@drawable/ic_launcher_ios",
            )


if __name__ == "__main__":
    unittest.main()
