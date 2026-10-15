#!/usr/bin/env python3
"""Prepare an isolated UI/API device build without modifying production iOS files."""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--team', required=True)
parser.add_argument('--bundle-id', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
destination = root / 'build' / 'ios-personal-team'
destination.mkdir(parents=True, exist_ok=True)
# Copy the current working tree, including uncommitted source changes. Do not
# copy generated dependencies or platform build caches into the test workspace.
subprocess.run([
    'rsync', '-a', '--exclude=.git', '--exclude=build', '--exclude=.build',
    '--exclude=.dart_tool', '--exclude=Pods', '--exclude=.symlinks',
    '--exclude=ephemeral', '--exclude=.DS_Store',
    '--exclude=Generated.xcconfig', '--exclude=flutter_export_environment.sh',
    '--exclude=.flutter-plugins-dependencies',
    *[str(root / name) for name in (
        'ios', 'lib', 'assets', 'vendor', 'native', 'test', 'pubspec.yaml',
        'pubspec.lock', 'analysis_options.yaml', 'tool',
    )], str(destination) + '/',
], check=True)
entitlements = destination / 'ios' / 'Runner' / 'PersonalTeam.entitlements'
entitlements.write_bytes(plistlib.dumps({}))
ruby = r'''
require 'xcodeproj'
project = Xcodeproj::Project.open(ARGV[0])
runner = project.targets.find { |target| target.name == 'Runner' }
raise 'Runner target missing' unless runner
runner.dependencies.select { |dep| dep.target&.name == 'XrayTunnel' }.each(&:remove_from_project)
runner.copy_files_build_phases.select { |phase| phase.name == 'Embed App Extensions' }.each(&:remove_from_project)
project.root_object.attributes.fetch('TargetAttributes', {}).fetch(runner.uuid, {})['SystemCapabilities'] = {}
[runner, project.targets.find { |target| target.name == 'RunnerTests' }].compact.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['DEVELOPMENT_TEAM'] = ARGV[1]
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Development'
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = ARGV[2] + (target == runner ? '' : '.RunnerTests')
    config.build_settings['CODE_SIGN_ENTITLEMENTS'] = target == runner ? 'Runner/PersonalTeam.entitlements' : ''
  end
end
project.save
'''
environment = dict(os.environ)
# Homebrew CocoaPods bundles xcodeproj with its own Ruby runtime.
pod = Path(subprocess.check_output(['which', 'pod'], text=True).strip())
wrapper = pod.read_text()
gem_home = re.search(r'GEM_HOME="([^"]+)"', wrapper)
if gem_home:
    environment['GEM_HOME'] = gem_home.group(1)
ruby_binary = '/opt/homebrew/opt/ruby/bin/ruby'
subprocess.run([ruby_binary, '-e', ruby,
                str(destination / 'ios' / 'Runner.xcodeproj'),
                args.team, args.bundle_id], env=environment, check=True)
# Personal Team cannot associate the production web domain with this test ID.
# Keep password/TOTP login usable and hide the unavailable native passkey flow.
passkey = destination / 'lib' / 'core' / 'auth' / 'client_passkey.dart'
source = passkey.read_text()
anchor = '    if (!_supportedPlatform) return false;'
if anchor not in source:
    raise SystemExit('Passkey availability changed; inspect before preparing.')
passkey.write_text(source.replace(anchor,
    '    if (Platform.isIOS || !_supportedPlatform) return false;', 1))
vpn = destination / 'lib/core/providers/vpn_provider.dart'
source = vpn.read_text()
anchor = '  Future<void> connect({bool automatic = false, bool replacing = false}) async {\n'
if anchor not in source:
    raise SystemExit('VPN entry point changed; inspect before preparing.')
vpn.write_text(source.replace(anchor, anchor + '''    if (Platform.isIOS) {
      ref.read(vpnErrorProvider.notifier).state =
          'VPN is unavailable in the Personal Team test build.';
      state = VpnState.error;
      return;
    }
''', 1))
info = destination / 'ios' / 'Runner' / 'Info.plist'
metadata = plistlib.loads(info.read_bytes())
metadata['CFBundleDisplayName'] = 'Oculve Test'
info.write_bytes(plistlib.dumps(metadata))
podfile = destination / 'ios/Podfile'
source = podfile.read_text()
anchor = '    flutter_additional_ios_build_settings(target)'
if anchor not in source:
    raise SystemExit('Podfile changed; inspect before preparing.')
podfile.write_text(source.replace(anchor, anchor + "\n    target.build_configurations.each do |config|\n      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'\n    end", 1))
# Binary artifacts must be inside their Swift package root. Flutter exposes the
# package through a symlink, so the plugin's sibling artifact path is invalid.
plugin_ios = destination / 'vendor/flutter_vless/ios'
shutil.copytree(plugin_ios / 'XRay.xcframework',
                plugin_ios / 'flutter_vless/XRay.xcframework', dirs_exist_ok=True)
package = plugin_ios / 'flutter_vless/Package.swift'
manifest = package.read_text()
start = manifest.index('if FileManager.default.fileExists(atPath: xrayPackageLocalAbsolutePath)')
end = manifest.index('let package = Package(', start)
manifest = (manifest[:start] +
    'xrayBinaryTarget = .binaryTarget(name: "XRay", path: "XRay.xcframework")\n\n' +
    manifest[end:])
package.write_text(manifest)
print(destination)
