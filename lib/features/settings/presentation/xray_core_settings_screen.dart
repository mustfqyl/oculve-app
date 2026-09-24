import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:oculve/core/localization/localized_text.dart';
import 'package:oculve/core/localization/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vless/flutter_vless.dart';
import 'package:oculve/core/providers/vpn_provider.dart';
import 'package:oculve/core/theme/app_theme.dart';
import 'package:oculve/core/vpn/xray_preferences.dart';
import 'package:oculve/core/widgets/app_page.dart';
import 'package:oculve/core/widgets/app_route.dart';
import 'package:oculve/features/auth/data/auth_repository.dart';
import 'android_app_routing_screen.dart';

class XrayCoreSettingsScreen extends ConsumerStatefulWidget {
  const XrayCoreSettingsScreen({super.key});

  @override
  ConsumerState<XrayCoreSettingsScreen> createState() =>
      _XrayCoreSettingsScreenState();
}

class _XrayCoreSettingsScreenState
    extends ConsumerState<XrayCoreSettingsScreen> {
  RealityFingerprint? _fingerprint;
  XrayTlsSettings? _tlsSettings;
  String? _tlsError;
  bool _savingTls = false;
  XrayXhttpSettings? _xhttpSettings;
  String? _xhttpError;
  bool _savingXhttp = false;
  XrayLogLevel? _logLevel;
  String? _logError;
  XrayDnsSettings? _dnsSettings;
  String? _dnsError;
  XrayTcpSettings? _tcpSettings;
  String? _tcpError;
  XrayPolicySettings? _policySettings;
  String? _policyError;
  bool _savingPolicy = false;
  bool _savingCustomConfig = false;
  String? _customConfigError;
  XrayFinalMaskSettings? _finalMaskSettings;
  String? _finalMaskError;
  bool _savingFinalMask = false;
  XrayVersionRequirement? _versionRequirement;
  String? _versionRequirementError;
  bool _savingVersionRequirement = false;
  XrayMuxSettings? _muxSettings;
  String? _vlessSettingsProfileId;
  XrayVlessEncryptionSettings? _vlessEncryptionDraft;
  bool _vlessEncryptionEnabled = false;
  bool _loadingVlessEncryption = false;
  bool _savingVlessEncryption = false;
  String? _vlessEncryptionError;
  String? _error;
  int _selectionRevision = 0;
  late final Future<String> _coreVersion;
  final _bypassController = TextEditingController();
  final _dnsServersController = TextEditingController();
  final _dnsHostsController = TextEditingController();
  final _dnsClientIpController = TextEditingController();
  final _tlsClientHelloController = TextEditingController();
  final _tlsServerNameController = TextEditingController();
  final _tlsVerifyNameController = TextEditingController();
  final _tlsAlpnController = TextEditingController();
  final _tlsMinVersionController = TextEditingController();
  final _tlsMaxVersionController = TextEditingController();
  final _tlsCipherSuitesController = TextEditingController();
  final _tlsCertificatePinController = TextEditingController();
  final _tlsCurvesController = TextEditingController();
  final _tlsMasterKeyLogController = TextEditingController();
  final _tlsEchConfigController = TextEditingController();
  final _tlsCertificateController = TextEditingController();
  final _xhttpHostController = TextEditingController();
  final _xhttpPathController = TextEditingController();
  final _xhttpHeadersController = TextEditingController();
  final _xhttpPaddingController = TextEditingController();
  final _xhttpMaxPostController = TextEditingController();
  final _xhttpPostIntervalController = TextEditingController();
  final _xhttpMaxConcurrencyController = TextEditingController();
  final _xhttpMaxConnectionsController = TextEditingController();
  final _xhttpReuseLimitController = TextEditingController();
  final _xhttpRequestCountController = TextEditingController();
  final _xhttpReusableSecondsController = TextEditingController();
  final _xhttpKeepAliveController = TextEditingController();
  final _xhttpDownloadController = TextEditingController();
  final _xhttpExtraController = TextEditingController();
  final _policyHandshakeController = TextEditingController();
  final _policyIdleController = TextEditingController();
  final _policyUplinkController = TextEditingController();
  final _policyDownlinkController = TextEditingController();
  final _policyBufferController = TextEditingController();
  final _customConfigController = TextEditingController(text: '{}');
  final _finalMaskController = TextEditingController(text: '{}');
  final _versionMinimumController = TextEditingController();
  final _versionMaximumController = TextEditingController();
  final _tcpInterfaceController = TextEditingController();
  final _tcpSendThroughController = TextEditingController();
  final _sniffingDomainsController = TextEditingController();
  final _sniffingIpsController = TextEditingController();
  final _vlessAuthenticationController = TextEditingController();
  final _vlessPaddingController = TextEditingController();
  bool _savingRouting = false;
  bool _savingDns = false;
  String? _routingError;
  List<XrayRoutingRule> _routingRules = const [];
  XraySniffingSettings? _sniffingSettings;
  String? _sniffingError;
  bool _savingSniffing = false;

  @override
  void initState() {
    super.initState();
    _coreVersion = _readVersion();
    XrayPreferences.bypassDomains()
        .then((domains) {
          if (mounted) _bypassController.text = domains.join('\n');
        })
        .catchError((Object error) {
          if (mounted) setState(() => _routingError = error.toString());
        });
    XrayPreferences.routingRules()
        .then((rules) {
          if (mounted) setState(() => _routingRules = rules);
        })
        .catchError((Object error) {
          if (mounted) setState(() => _routingError = error.toString());
        });
    XrayPreferences.fingerprint()
        .then((value) {
          if (mounted) setState(() => _fingerprint = value);
        })
        .catchError((Object error) {
          if (mounted) {
            setState(() {
              _fingerprint = RealityFingerprint.serverDefault;
              _error = error.toString();
            });
          }
        });
    XrayPreferences.tlsSettings().then((value) {
      if (!mounted) return;
      setState(() {
        _tlsSettings = value;
        _tlsClientHelloController.text = value.clientHelloFingerprint;
        _tlsServerNameController.text = value.serverName;
        _tlsVerifyNameController.text = value.verifyPeerCertByName;
        _tlsAlpnController.text = value.alpn;
        _tlsMinVersionController.text = value.minVersion;
        _tlsMaxVersionController.text = value.maxVersion;
        _tlsCipherSuitesController.text = value.cipherSuites;
        _tlsCertificatePinController.text = value.pinnedPeerCertSha256;
        _tlsCurvesController.text = value.curvePreferences;
        _tlsMasterKeyLogController.text = value.masterKeyLog;
        _tlsEchConfigController.text = value.echConfigList;
        _tlsCertificateController.text = value.certificatePem;
      });
    });
    XrayPreferences.xhttpSettings().then((value) {
      if (!mounted) return;
      setState(() {
        _xhttpSettings = value;
        _xhttpHostController.text = value.host;
        _xhttpPathController.text = value.path;
        _xhttpHeadersController.text = value.headersJson;
        _xhttpPaddingController.text = value.paddingBytes;
        _xhttpMaxPostController.text = value.maxEachPostBytes;
        _xhttpPostIntervalController.text = value.minimumPostIntervalMs;
        _xhttpMaxConcurrencyController.text = value.xmux.maxConcurrency;
        _xhttpMaxConnectionsController.text = value.xmux.maxConnections;
        _xhttpReuseLimitController.text = value.xmux.connectionReuseLimit;
        _xhttpRequestCountController.text = value.xmux.maxRequestCount;
        _xhttpReusableSecondsController.text = value.xmux.maxReusableSeconds;
        _xhttpKeepAliveController.text = value.xmux.keepAliveSeconds;
        _xhttpDownloadController.text = value.downloadSettingsJson;
        _xhttpExtraController.text = value.extraJson;
      });
    });
    XrayPreferences.logLevel().then((value) {
      if (mounted) setState(() => _logLevel = value);
    });
    XrayPreferences.dnsSettings().then((value) {
      if (mounted) {
        setState(() {
          _dnsSettings = value;
          _dnsServersController.text = value.servers.join('\n');
          _dnsHostsController.text = value.hosts.entries
              .map((entry) {
                final targets = entry.value is List
                    ? (entry.value as List).join(',')
                    : entry.value;
                return '${entry.key}=$targets';
              })
              .join('\n');
          _dnsClientIpController.text = value.clientIp;
        });
      }
    });
    XrayPreferences.muxSettings().then((value) {
      if (mounted) setState(() => _muxSettings = value);
    });
    XrayPreferences.tcpSettings().then((value) {
      if (mounted) {
        setState(() {
          _tcpSettings = value;
          _tcpInterfaceController.text = value.interfaceName;
          _tcpSendThroughController.text = value.sendThroughAddress;
        });
      }
    });
    XrayPreferences.policySettings().then((value) {
      if (!mounted) return;
      setState(() {
        _policySettings = value;
        _policyHandshakeController.text = '${value.handshakeSeconds}';
        _policyIdleController.text = '${value.connectionIdleSeconds}';
        _policyUplinkController.text = '${value.uplinkOnlySeconds}';
        _policyDownlinkController.text = '${value.downlinkOnlySeconds}';
        _policyBufferController.text = value.bufferSizeKb?.toString() ?? '';
      });
    });
    XrayPreferences.customConfigSource().then((value) {
      if (mounted) setState(() => _customConfigController.text = value);
    });
    XrayPreferences.versionRequirement().then((value) {
      if (!mounted) return;
      setState(() {
        _versionRequirement = value ?? const XrayVersionRequirement();
        _versionMinimumController.text = value?.minimum ?? '';
        _versionMaximumController.text = value?.maximum ?? '';
      });
    });
    XrayPreferences.finalMaskSettings().then((value) {
      if (!mounted) return;
      setState(() {
        _finalMaskSettings = value;
        _finalMaskController.text = value.json;
      });
    });
    XrayPreferences.sniffingSettings().then((value) {
      if (!mounted) return;
      setState(() {
        _sniffingSettings = value;
        _sniffingDomainsController.text = value.domainsExcluded.join('\n');
        _sniffingIpsController.text = value.ipsExcluded.join('\n');
      });
    });
  }

  @override
  void dispose() {
    _bypassController.dispose();
    _dnsServersController.dispose();
    _dnsHostsController.dispose();
    _dnsClientIpController.dispose();
    _tlsClientHelloController.dispose();
    _tlsServerNameController.dispose();
    _tlsVerifyNameController.dispose();
    _tlsAlpnController.dispose();
    _tlsMinVersionController.dispose();
    _tlsMaxVersionController.dispose();
    _tlsCipherSuitesController.dispose();
    _tlsCertificatePinController.dispose();
    _tlsCurvesController.dispose();
    _tlsMasterKeyLogController.dispose();
    _tlsEchConfigController.dispose();
    _tlsCertificateController.dispose();
    _xhttpHostController.dispose();
    _xhttpPathController.dispose();
    _xhttpHeadersController.dispose();
    _xhttpPaddingController.dispose();
    _xhttpMaxPostController.dispose();
    _xhttpPostIntervalController.dispose();
    _xhttpMaxConcurrencyController.dispose();
    _xhttpMaxConnectionsController.dispose();
    _xhttpReuseLimitController.dispose();
    _xhttpRequestCountController.dispose();
    _xhttpReusableSecondsController.dispose();
    _xhttpKeepAliveController.dispose();
    _xhttpDownloadController.dispose();
    _xhttpExtraController.dispose();
    _policyHandshakeController.dispose();
    _policyIdleController.dispose();
    _policyUplinkController.dispose();
    _policyDownlinkController.dispose();
    _policyBufferController.dispose();
    _customConfigController.dispose();
    _finalMaskController.dispose();
    _versionMinimumController.dispose();
    _versionMaximumController.dispose();
    _tcpInterfaceController.dispose();
    _tcpSendThroughController.dispose();
    _vlessAuthenticationController.dispose();
    _vlessPaddingController.dispose();
    _sniffingDomainsController.dispose();
    _sniffingIpsController.dispose();
    super.dispose();
  }

  Future<void> _loadVlessEncryption(String profileId) async {
    if (_vlessSettingsProfileId == profileId) return;
    setState(() {
      _vlessSettingsProfileId = profileId;
      _vlessEncryptionDraft = null;
      _vlessEncryptionEnabled = false;
      _loadingVlessEncryption = true;
      _vlessEncryptionError = null;
    });
    try {
      final settings = await XrayPreferences.vlessEncryptionSettingsFor(
        profileId,
      );
      if (!mounted || _vlessSettingsProfileId != profileId) return;
      setState(() {
        _vlessEncryptionDraft =
            settings ??
            const XrayVlessEncryptionSettings(serverAuthentication: '');
        _vlessEncryptionEnabled = settings != null;
        _vlessAuthenticationController.text =
            settings?.serverAuthentication ?? '';
        _vlessPaddingController.text = settings?.padding ?? '';
        _loadingVlessEncryption = false;
      });
    } catch (error) {
      if (!mounted || _vlessSettingsProfileId != profileId) return;
      setState(() {
        _loadingVlessEncryption = false;
        _vlessEncryptionError = error.toString();
      });
    }
  }

  Future<void> _saveVlessEncryption() async {
    final profileId = _vlessSettingsProfileId;
    final draft = _vlessEncryptionDraft;
    if (_savingVlessEncryption || profileId == null || draft == null) return;
    setState(() {
      _savingVlessEncryption = true;
      _vlessEncryptionError = null;
    });
    try {
      final settings = draft.copyWith(
        serverAuthentication: _vlessAuthenticationController.text.trim(),
        padding: _vlessPaddingController.text.trim(),
      );
      settings.validate();
      await XrayPreferences.setVlessEncryptionSettingsFor(profileId, settings);
      if (mounted && _vlessSettingsProfileId == profileId) {
        setState(() {
          _vlessEncryptionDraft = settings;
          _vlessEncryptionEnabled = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _vlessEncryptionError = error is FormatException
              ? error.message.toString()
              : 'Could not save VLESS Encryption settings.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingVlessEncryption = false);
    }
  }

  Future<void> _clearVlessEncryption() async {
    final profileId = _vlessSettingsProfileId;
    if (profileId == null) return;
    setState(() {
      _savingVlessEncryption = true;
      _vlessEncryptionError = null;
    });
    try {
      await XrayPreferences.clearVlessEncryptionSettingsFor(profileId);
      if (mounted && _vlessSettingsProfileId == profileId) {
        setState(() {
          _vlessEncryptionEnabled = false;
          _vlessEncryptionDraft = const XrayVlessEncryptionSettings(
            serverAuthentication: '',
          );
          _vlessAuthenticationController.clear();
          _vlessPaddingController.clear();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _vlessEncryptionError = error.toString());
    } finally {
      if (mounted) setState(() => _savingVlessEncryption = false);
    }
  }

  Future<void> _saveRouting() async {
    if (_savingRouting) return;
    setState(() {
      _savingRouting = true;
      _routingError = null;
    });
    try {
      await XrayPreferences.setBypassDomains(
        _bypassController.text.split(RegExp(r'[,\n]')),
      );
      await XrayPreferences.setRoutingRules(_routingRules);
      if (mounted) {
        final domains = await XrayPreferences.bypassDomains();
        final rules = await XrayPreferences.routingRules();
        if (mounted) {
          setState(() {
            _bypassController.text = domains.join('\n');
            _routingRules = rules;
          });
        }
      }
    } catch (error) {
      if (mounted) setState(() => _routingError = error.toString());
    } finally {
      if (mounted) setState(() => _savingRouting = false);
    }
  }

  Future<void> _saveSniffing() async {
    final current = _sniffingSettings;
    if (_savingSniffing || current == null) return;
    setState(() {
      _savingSniffing = true;
      _sniffingError = null;
    });
    try {
      final settings = current.copyWith(
        // FakeDNS is an Xray DNS resolver mode, not an independent sniffer.
        // Keep its visible control tied to the DNS card and let the config
        // builder add the fakedns destination override only when that resolver
        // is enabled.
        destOverride: current.destOverride
            .where((protocol) => protocol != 'fakedns')
            .toList(),
        domainsExcluded: XrayRoutingRule.parseDomains(
          _sniffingDomainsController.text,
        ),
        ipsExcluded: XrayRoutingRule.parseIps(_sniffingIpsController.text),
      );
      await XrayPreferences.setSniffingSettings(settings);
      if (mounted) {
        setState(() {
          _sniffingSettings = settings;
          _sniffingDomainsController.text = settings.domainsExcluded.join('\n');
          _sniffingIpsController.text = settings.ipsExcluded.join('\n');
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _sniffingError = error is FormatException
              ? error.message.toString()
              : 'Could not save Xray sniffing settings.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingSniffing = false);
    }
  }

  Future<void> _editRoutingRule({XrayRoutingRule? rule, int? index}) async {
    if (_savingRouting) return;
    final edited = await showDialog<XrayRoutingRule>(
      context: context,
      builder: (_) => _RoutingRuleDialog(rule: rule),
    );
    if (!mounted || edited == null) return;
    setState(() {
      final rules = [..._routingRules];
      if (index == null) {
        rules.add(edited);
      } else {
        rules[index] = edited;
      }
      _routingRules = rules;
      _routingError = null;
    });
  }

  void _removeRoutingRule(int index) {
    setState(() {
      _routingRules = [..._routingRules]..removeAt(index);
      _routingError = null;
    });
  }

  Future<String> _readVersion() async {
    try {
      await ref.read(vpnProvider.notifier).initialize();
      return await VlessPlatform.instance.getCoreVersion();
    } catch (_) {
      return 'Unavailable';
    }
  }

  Future<void> _save(RealityFingerprint value) async {
    try {
      await XrayPreferences.setFingerprint(value);
      if (mounted) {
        setState(() {
          _fingerprint = value;
          _error = null;
          _selectionRevision++;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _selectionRevision++;
        });
      }
    }
  }

  Future<void> _saveTlsSettings([XrayTlsSettings? updated]) async {
    final current = _tlsSettings;
    if (_savingTls || current == null) return;
    setState(() {
      _savingTls = true;
      _tlsError = null;
    });
    try {
      final settings = (updated ?? current).copyWith(
        clientHelloFingerprint: _tlsClientHelloController.text.trim(),
        serverName: _tlsServerNameController.text.trim(),
        verifyPeerCertByName: _tlsVerifyNameController.text.trim(),
        alpn: _tlsAlpnController.text.trim(),
        minVersion: _tlsMinVersionController.text.trim(),
        maxVersion: _tlsMaxVersionController.text.trim(),
        cipherSuites: _tlsCipherSuitesController.text.trim(),
        pinnedPeerCertSha256: _tlsCertificatePinController.text.trim(),
        curvePreferences: _tlsCurvesController.text.trim(),
        masterKeyLog: _tlsMasterKeyLogController.text.trim(),
        echConfigList: _tlsEchConfigController.text.trim(),
        certificatePem: _tlsCertificateController.text.trim(),
      );
      await XrayPreferences.setTlsSettings(settings);
      if (mounted) {
        setState(() {
          _tlsSettings = settings;
          _tlsError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _tlsError = error is FormatException
              ? error.message.toString()
              : 'Could not save TLS settings.';
        });
      }
    } finally {
      if (mounted) setState(() => _savingTls = false);
    }
  }

  Future<void> _saveXhttpSettings([XrayXhttpSettings? updated]) async {
    final current = _xhttpSettings;
    if (_savingXhttp || current == null) return;
    setState(() {
      _savingXhttp = true;
      _xhttpError = null;
    });
    try {
      final settings = (updated ?? current).copyWith(
        host: _xhttpHostController.text.trim(),
        path: _xhttpPathController.text.trim(),
        headersJson: _xhttpHeadersController.text.trim(),
        paddingBytes: _xhttpPaddingController.text.trim(),
        maxEachPostBytes: _xhttpMaxPostController.text.trim(),
        minimumPostIntervalMs: _xhttpPostIntervalController.text.trim(),
        xmux: current.xmux.copyWith(
          maxConcurrency: _xhttpMaxConcurrencyController.text.trim(),
          maxConnections: _xhttpMaxConnectionsController.text.trim(),
          connectionReuseLimit: _xhttpReuseLimitController.text.trim(),
          maxRequestCount: _xhttpRequestCountController.text.trim(),
          maxReusableSeconds: _xhttpReusableSecondsController.text.trim(),
          keepAliveSeconds: _xhttpKeepAliveController.text.trim(),
        ),
        downloadSettingsJson: _xhttpDownloadController.text.trim(),
        extraJson: _xhttpExtraController.text.trim(),
      );
      await XrayPreferences.setXhttpSettings(settings);
      if (mounted) setState(() => _xhttpSettings = settings);
    } catch (error) {
      if (mounted) {
        setState(() {
          _xhttpError = error is FormatException
              ? error.message.toString()
              : 'Could not save XHTTP settings.';
        });
      }
    } finally {
      if (mounted) setState(() => _savingXhttp = false);
    }
  }

  int _policyNumber(TextEditingController controller, String label) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value < 0) {
      throw FormatException('$label must be a non-negative whole number.');
    }
    return value;
  }

  Future<void> _savePolicySettings() async {
    final current = _policySettings;
    if (_savingPolicy || current == null) return;
    setState(() {
      _savingPolicy = true;
      _policyError = null;
    });
    try {
      final bufferText = _policyBufferController.text.trim();
      final settings = current.copyWith(
        handshakeSeconds: _policyNumber(
          _policyHandshakeController,
          'Handshake timeout',
        ),
        connectionIdleSeconds: _policyNumber(
          _policyIdleController,
          'Idle timeout',
        ),
        uplinkOnlySeconds: _policyNumber(
          _policyUplinkController,
          'Uplink timeout',
        ),
        downlinkOnlySeconds: _policyNumber(
          _policyDownlinkController,
          'Downlink timeout',
        ),
        bufferSizeKb: bufferText.isEmpty
            ? null
            : _policyNumber(_policyBufferController, 'Buffer size'),
        clearBufferSize: bufferText.isEmpty,
      );
      await XrayPreferences.setPolicySettings(settings);
      if (mounted) {
        setState(() {
          _policySettings = settings;
          _policyError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _policyError = error is FormatException
              ? error.message.toString()
              : 'Could not save Xray policy settings.';
        });
      }
    } finally {
      if (mounted) setState(() => _savingPolicy = false);
    }
  }

  Future<void> _saveCustomConfig() async {
    if (_savingCustomConfig) return;
    setState(() {
      _savingCustomConfig = true;
      _customConfigError = null;
    });
    try {
      await XrayPreferences.setCustomConfigSource(_customConfigController.text);
      final saved = await XrayPreferences.customConfigSource();
      if (mounted) {
        setState(() {
          _customConfigController.text = saved;
          _customConfigError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _customConfigError = error is FormatException
              ? error.message.toString()
              : 'Could not save the custom Xray configuration.';
        });
      }
    } finally {
      if (mounted) setState(() => _savingCustomConfig = false);
    }
  }

  Future<void> _saveFinalMask() async {
    if (_savingFinalMask) return;
    setState(() {
      _savingFinalMask = true;
      _finalMaskError = null;
    });
    try {
      final settings = XrayFinalMaskSettings.fromJsonText(
        _finalMaskController.text,
      );
      await XrayPreferences.setFinalMaskSettings(settings);
      final saved = await XrayPreferences.finalMaskSettings();
      if (mounted) {
        setState(() {
          _finalMaskSettings = saved;
          _finalMaskController.text = saved.json;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _finalMaskError = error is FormatException
              ? error.message.toString()
              : 'Could not save FinalMask settings.';
        });
      }
    } finally {
      if (mounted) setState(() => _savingFinalMask = false);
    }
  }

  Future<void> _saveVersionRequirement() async {
    if (_savingVersionRequirement) return;
    setState(() {
      _savingVersionRequirement = true;
      _versionRequirementError = null;
    });
    try {
      final requirement = XrayVersionRequirement(
        minimum: _versionMinimumController.text.trim(),
        maximum: _versionMaximumController.text.trim(),
      );
      requirement.validate();
      await XrayPreferences.setVersionRequirement(requirement);
      final saved = await XrayPreferences.versionRequirement();
      if (mounted) {
        setState(() {
          _versionRequirement = saved ?? const XrayVersionRequirement();
          _versionMinimumController.text = saved?.minimum ?? '';
          _versionMaximumController.text = saved?.maximum ?? '';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _versionRequirementError = error is FormatException
              ? error.message.toString()
              : 'Could not save the Xray version guard.';
        });
      }
    } finally {
      if (mounted) setState(() => _savingVersionRequirement = false);
    }
  }

  Future<void> _saveTransportSettings() async {
    await _saveTlsSettings();
    await _saveXhttpSettings();
  }

  Future<void> _saveLogLevel(XrayLogLevel value) async {
    try {
      await XrayPreferences.setLogLevel(value);
      if (mounted) {
        setState(() {
          _logLevel = value;
          _logError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _logError = error.toString());
    }
  }

  Map<String, dynamic> _parseDnsHosts(String source) {
    final hosts = <String, dynamic>{};
    for (final line in source.split('\n')) {
      final entry = line.trim();
      if (entry.isEmpty) continue;
      final separator = entry.indexOf('=');
      if (separator < 1 || separator == entry.length - 1) {
        throw const FormatException(
          'Write each hosts entry as domain=address.',
        );
      }
      final domain = entry.substring(0, separator).trim();
      final targets = entry
          .substring(separator + 1)
          .split('|')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (targets.isEmpty) {
        throw FormatException('Add a DNS target for $domain.');
      }
      hosts[domain] = targets.length == 1 ? targets.single : targets;
    }
    return hosts;
  }

  Future<void> _saveDnsSettings([XrayDnsSettings? updated]) async {
    final current = _dnsSettings;
    if (_savingDns || current == null) return;
    setState(() {
      _savingDns = true;
      _dnsError = null;
    });
    try {
      final settings = (updated ?? current).copyWith(
        servers: _dnsServersController.text
            .split('\n')
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(),
        hosts: _parseDnsHosts(_dnsHostsController.text),
        clientIp: _dnsClientIpController.text.trim(),
      );
      await XrayPreferences.setDnsSettings(settings);
      if (mounted) {
        setState(() {
          _dnsSettings = settings;
          _dnsServersController.text = settings.servers.join('\n');
          _dnsError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _dnsError = error is FormatException
              ? error.message.toString()
              : 'Could not save DNS settings.';
        });
      }
    } finally {
      if (mounted) setState(() => _savingDns = false);
    }
  }

  Future<void> _saveMux(XrayMuxSettings value) async {
    try {
      await XrayPreferences.setMuxSettings(value);
      if (mounted) setState(() => _muxSettings = value);
    } catch (error) {
      if (mounted) setState(() => _routingError = error.toString());
    }
  }

  Future<void> _saveTcp(XrayTcpSettings value) async {
    try {
      await XrayPreferences.setTcpSettings(value);
      if (mounted) {
        setState(() {
          _tcpSettings = value;
          _tcpError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _tcpError = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    final profiles = ref.watch(sessionProvider).valueOrNull?.profiles ?? [];
    final selectedId = ref.watch(selectedServerProvider);
    final selectedProfile = profiles.isEmpty
        ? null
        : profiles.firstWhere(
            (profile) => profile.id == selectedId,
            orElse: () => profiles.first,
          );
    if (selectedProfile?.proxyProtocol == 'vless' &&
        _vlessSettingsProfileId != selectedProfile!.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadVlessEncryption(selectedProfile.id);
      });
    }
    final muxIncompatibility = selectedProfile == null
        ? null
        : XrayPreferences.muxIncompatibility(selectedProfile.config);
    return AppPage(
      title: 'Xray core',
      action: IconButton(
        key: const ValueKey('save-transport-settings'),
        tooltip: context.tr('Save transport settings'),
        onPressed:
            _tlsSettings == null ||
                _xhttpSettings == null ||
                _savingTls ||
                _savingXhttp
            ? null
            : _saveTransportSettings,
        icon: _savingTls || _savingXhttp
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined, size: 19),
      ),
      child: ListView(
        key: const ValueKey('xray-core-settings-list'),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          _categoryHeader(context.tr('Protocol & identity')),
          const SizedBox(height: 8),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ClientHello fingerprint',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                Text(
                  'Applies to TLS and Reality profiles on the next connection.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                if (_fingerprint == null)
                  const Center(child: CircularProgressIndicator())
                else
                  _DropdownMenuField<RealityFingerprint>(
                    key: ValueKey(_selectionRevision),
                    title: 'Fingerprint',
                    value: _fingerprint!,
                    values: RealityFingerprint.values,
                    label: (fingerprint) => fingerprint.label,
                    onSelected: _save,
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _categoryHeader(context.tr('Protocol & identity')),
          const SizedBox(height: 8),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VLESS Encryption',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  selectedProfile?.proxyProtocol == 'vless'
                      ? 'Applies only to ${selectedProfile!.name}. Its VLESS inbound must use the matching authentication parameter and options.'
                      : 'Select a VLESS location to configure its server-specific encryption parameters.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                if (selectedProfile?.proxyProtocol != 'vless')
                  const SizedBox.shrink()
                else if (_loadingVlessEncryption ||
                    _vlessEncryptionDraft == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    key: const ValueKey('vless-encryption-enabled'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable for this location'),
                    subtitle: const Text(
                      'Uses the hybrid ML-KEM-768 + X25519 handshake.',
                    ),
                    value: _vlessEncryptionEnabled,
                    onChanged: _savingVlessEncryption
                        ? null
                        : (enabled) {
                            if (enabled) {
                              setState(() {
                                _vlessEncryptionEnabled = true;
                                _vlessEncryptionError = null;
                              });
                            } else {
                              _clearVlessEncryption();
                            }
                          },
                  ),
                  if (_vlessEncryptionEnabled) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Handshake method',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ML-KEM-768 + X25519 (Xray hybrid post-quantum handshake)',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    _MuxDropdown<XrayVlessTrafficAppearance>(
                      title: 'Traffic appearance',
                      subtitle: 'Must match the server inbound.',
                      value: _vlessEncryptionDraft!.trafficAppearance,
                      values: XrayVlessTrafficAppearance.values,
                      label: (value) => value.label,
                      onChanged: (value) => setState(() {
                        _vlessEncryptionDraft = _vlessEncryptionDraft!.copyWith(
                          trafficAppearance: value,
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    _MuxDropdown<XrayVlessResumption>(
                      title: 'Session resumption',
                      subtitle: '0-RTT is faster when the server permits it.',
                      value: _vlessEncryptionDraft!.resumption,
                      values: XrayVlessResumption.values,
                      label: (value) => value.value.toUpperCase(),
                      onChanged: (value) => setState(() {
                        _vlessEncryptionDraft = _vlessEncryptionDraft!.copyWith(
                          resumption: value,
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('vless-encryption-auth-field'),
                      controller: _vlessAuthenticationController,
                      autocorrect: false,
                      enableSuggestions: false,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: context.tr(
                          'Server authentication parameter',
                        ),
                        hintText:
                            'Paste the client parameter from xray mlkem768',
                        helperText: context.tr(
                          'This value is specific to the server. The client cannot create a matching server parameter by itself.',
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('vless-encryption-padding-field'),
                      controller: _vlessPaddingController,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: context.tr(
                          'Padding and delay pattern (optional)',
                        ),
                        hintText: '100-111-1111.75-0-111.50-0-3333',
                        helperText: context.tr(
                          'Use dot-separated probability-min-max blocks; leave empty for Xray defaults.',
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_vlessEncryptionError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _vlessEncryptionError!,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('save-vless-encryption'),
                        onPressed: _savingVlessEncryption
                            ? null
                            : _saveVlessEncryption,
                        icon: _savingVlessEncryption
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 17),
                        label: const Text('Save for this location'),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _categoryHeader(context.tr('Transport & TLS')),
          const SizedBox(height: 8),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'XHTTP transport',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  'These controls are applied only to subscription profiles using XHTTP. Save from the page header; reconnect to apply.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                if (_xhttpSettings == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  const SizedBox(height: 14),
                  _MuxDropdown<XrayXhttpMode>(
                    title: 'Mode',
                    subtitle: 'Choose how XHTTP carries upload and download.',
                    value: _xhttpSettings!.mode,
                    values: XrayXhttpMode.values,
                    label: (value) => value.label,
                    onChanged: (value) => _saveXhttpSettings(
                      _xhttpSettings!.copyWith(mode: value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('xhttp-host-field'),
                    controller: _xhttpHostController,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('HTTP host override (optional)'),
                      hintText: 'cdn.example.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('xhttp-path-field'),
                    controller: _xhttpPathController,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('Path override (optional)'),
                      hintText: '/tunnel',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    maintainState: true,
                    title: const Text(
                      'Advanced XHTTP and XMUX',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Padding, request behavior, reuse and split download',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    children: [
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('xhttp-headers-field'),
                        controller: _xhttpHeadersController,
                        autocorrect: false,
                        enableSuggestions: false,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'Custom HTTP headers (JSON object)',
                          ),
                          hintText: '{"X-Client":"Oculve"}',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('xhttp-padding-field'),
                        controller: _xhttpPaddingController,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: context.tr('Header padding bytes'),
                          hintText: '100-1000',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _MuxDropdown<XrayBooleanOverride>(
                        title: 'gRPC header disguise',
                        subtitle:
                            'Client option used by stream-up and stream-one.',
                        value: _xhttpSettings!.noGrpcHeader,
                        values: XrayBooleanOverride.values,
                        label: (value) => switch (value) {
                          XrayBooleanOverride.profileDefault =>
                            'Profile default',
                          XrayBooleanOverride.enabled => 'Suppress header',
                          XrayBooleanOverride.disabled => 'Send header',
                        },
                        onChanged: (value) => _saveXhttpSettings(
                          _xhttpSettings!.copyWith(noGrpcHeader: value),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('xhttp-max-post-field'),
                        controller: _xhttpMaxPostController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('Maximum POST body bytes'),
                          hintText: '1000000',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('xhttp-post-interval-field'),
                        controller: _xhttpPostIntervalController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('Minimum POST interval (ms)'),
                          hintText: '30',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'XMUX connection limits',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('xhttp-max-concurrency-field'),
                        controller: _xhttpMaxConcurrencyController,
                        decoration: InputDecoration(
                          labelText: context.tr('Maximum concurrent requests'),
                          hintText: '16-32',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('xhttp-max-connections-field'),
                        controller: _xhttpMaxConnectionsController,
                        decoration: InputDecoration(
                          labelText: context.tr('Maximum connections'),
                          hintText: 'Leave blank unless using this limit',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('xhttp-reuse-limit-field'),
                        controller: _xhttpReuseLimitController,
                        decoration: InputDecoration(
                          labelText: context.tr('Connection reuse limit'),
                          hintText: '0 means core default',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('xhttp-request-count-field'),
                        controller: _xhttpRequestCountController,
                        decoration: InputDecoration(
                          labelText: context.tr('Maximum HTTP request count'),
                          hintText: '600-900',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('xhttp-reusable-seconds-field'),
                        controller: _xhttpReusableSecondsController,
                        decoration: InputDecoration(
                          labelText: context.tr('Maximum reusable seconds'),
                          hintText: '1800-3000',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('xhttp-keepalive-field'),
                        controller: _xhttpKeepAliveController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'HTTP keepalive period (seconds)',
                          ),
                          hintText: '0 uses core default; -1 disables',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('xhttp-download-field'),
                        controller: _xhttpDownloadController,
                        autocorrect: false,
                        enableSuggestions: false,
                        minLines: 2,
                        maxLines: 8,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'Separate download settings (JSON)',
                          ),
                          hintText:
                              '{"address":"download.example","port":443,"network":"xhttp","security":"tls","tlsSettings":{"serverName":"download.example"},"xhttpSettings":{"path":"/tunnel"}}',
                          helperText: context.tr(
                            'The upload and download sides can use different IPs, domains, transports or security.',
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('xhttp-extra-field'),
                        controller: _xhttpExtraController,
                        autocorrect: false,
                        enableSuggestions: false,
                        minLines: 1,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'Additional client extra settings (JSON)',
                          ),
                          hintText: '{"xPaddingBytes":"100-1000"}',
                          helperText: context.tr(
                            'Client-supported XHTTP fields only. SSE response options and buffered-post limits are server-side.',
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_xhttpError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _xhttpError!,
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_xhttpError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _xhttpError!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _categoryHeader(context.tr('Transport & TLS')),
          const SizedBox(height: 8),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transport security',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  'TLS-only controls apply to TLS profiles. SNI and the ClientHello fingerprint also apply to Reality. Changes take effect after reconnecting.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                if (_tlsSettings == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('tls-server-name-field'),
                    controller: _tlsServerNameController,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('SNI / server name'),
                      hintText: 'server.example.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    maintainState: true,
                    title: const Text(
                      'Advanced TLS',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Certificate checks, ALPN, ECH, key logging and curves',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    children: [
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('tls-native-fingerprint-field'),
                        controller: _tlsClientHelloController,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'Native uTLS Hello profile (optional)',
                          ),
                          hintText: 'HelloChrome_120',
                          helperText: context.tr(
                            'Overrides the browser preset above. Use a Hello name supported by this Xray core.',
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('tls-verify-name-field'),
                        controller: _tlsVerifyNameController,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'Certificate verification name',
                          ),
                          hintText: 'example.com,backup.example.com',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DnsSwitch(
                        title: 'Allow invalid certificates',
                        subtitle:
                            'Disables certificate verification and is unsafe on public networks.',
                        value: _tlsSettings!.allowInsecure,
                        onChanged: (enabled) => _saveTlsSettings(
                          _tlsSettings!.copyWith(allowInsecure: enabled),
                        ),
                      ),
                      TextField(
                        key: const ValueKey('tls-alpn-field'),
                        controller: _tlsAlpnController,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: context.tr('ALPN'),
                          hintText: 'h2,http/1.1',
                          helperText: context.tr(
                            'Comma-separated protocol names.',
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _MuxDropdown<String>(
                        title: 'Minimum TLS version',
                        subtitle: 'Leave on Core default unless required.',
                        value: _tlsSettings!.minVersion,
                        values: const ['', '1.0', '1.1', '1.2', '1.3'],
                        label: (version) =>
                            version.isEmpty ? 'Core default' : 'TLS $version',
                        onChanged: (version) => _saveTlsSettings(
                          _tlsSettings!.copyWith(minVersion: version),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _MuxDropdown<String>(
                        title: 'Maximum TLS version',
                        subtitle: 'Leave on Core default unless required.',
                        value: _tlsSettings!.maxVersion,
                        values: const ['', '1.0', '1.1', '1.2', '1.3'],
                        label: (version) =>
                            version.isEmpty ? 'Core default' : 'TLS $version',
                        onChanged: (version) => _saveTlsSettings(
                          _tlsSettings!.copyWith(maxVersion: version),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('tls-cipher-suites-field'),
                        controller: _tlsCipherSuitesController,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: context.tr('Cipher suites (optional)'),
                          hintText: 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256',
                          helperText: context.tr(
                            'Separate Go cipher suite names with colons.',
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('tls-curves-field'),
                        controller: _tlsCurvesController,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: context.tr('Curve preferences'),
                          hintText: 'X25519,X25519MLKEM768',
                          helperText: context.tr(
                            'Supported: CurveP256, CurveP384, CurveP521, X25519 and ML-KEM hybrids.',
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('tls-certificate-pin-field'),
                        controller: _tlsCertificatePinController,
                        autocorrect: false,
                        enableSuggestions: false,
                        minLines: 1,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: context.tr('Certificate SHA-256 pin(s)'),
                          hintText:
                              '64 hex characters; multiple separated by commas',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DnsSwitch(
                        title: 'Disable system CA roots',
                        subtitle:
                            'Trust only CA certificates present in this profile or below.',
                        value: _tlsSettings!.disableSystemRoot,
                        onChanged: (enabled) => _saveTlsSettings(
                          _tlsSettings!.copyWith(disableSystemRoot: enabled),
                        ),
                      ),
                      TextField(
                        key: const ValueKey('tls-custom-ca-field'),
                        controller: _tlsCertificateController,
                        autocorrect: false,
                        enableSuggestions: false,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: context.tr('Custom CA certificate (PEM)'),
                          hintText: '-----BEGIN CERTIFICATE-----',
                          helperText: context.tr(
                            'Adding a custom CA makes Xray trust only this CA for TLS verification.',
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DnsSwitch(
                        title: 'TLS session resumption',
                        subtitle:
                            'Requires server support; this does not enable TLS 0-RTT.',
                        value: _tlsSettings!.enableSessionResumption,
                        onChanged: (enabled) => _saveTlsSettings(
                          _tlsSettings!.copyWith(
                            enableSessionResumption: enabled,
                          ),
                        ),
                      ),
                      TextField(
                        key: const ValueKey('tls-ech-field'),
                        controller: _tlsEchConfigController,
                        autocorrect: false,
                        enableSuggestions: false,
                        minLines: 1,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: context.tr('ECH config or DNS lookup URL'),
                          hintText: 'https://1.1.1.1/dns-query',
                          helperText: context.tr(
                            'Paste a static ECHConfig or use udp://, https:// or h2c://.',
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('tls-key-log-field'),
                        controller: _tlsMasterKeyLogController,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: context.tr('TLS key log file path'),
                          helperText: context.tr(
                            'For Wireshark diagnostics only. Anyone with this file can decrypt captured traffic.',
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_tlsError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _tlsError!,
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_tlsError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _tlsError!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _categoryHeader(context.tr('Network behavior')),
          const SizedBox(height: 8),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TCP connection',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  'These Xray socket settings apply to the next connection.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                if (_tcpSettings == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  const SizedBox(height: 14),
                  _MuxDropdown<TcpFastOpenMode>(
                    title: 'TCP Fast Open',
                    subtitle:
                        'Reduce a TCP handshake when the network allows it',
                    value: _tcpSettings!.fastOpenMode,
                    values: TcpFastOpenMode.values,
                    label: (mode) => switch (mode) {
                      TcpFastOpenMode.coreDefault => 'Core default',
                      TcpFastOpenMode.enabled => 'Enabled',
                      TcpFastOpenMode.disabled => 'Disabled',
                    },
                    onChanged: (mode) =>
                        _saveTcp(_tcpSettings!.copyWith(fastOpenMode: mode)),
                  ),
                  const SizedBox(height: 14),
                  _MuxDropdown<int>(
                    title: 'Keepalive idle',
                    subtitle:
                        'Seconds before an idle TCP connection is checked',
                    value: _tcpSettings!.keepAliveIdle,
                    values: const [0, 15, 30, 60, 120, 300, 600, 1800, 3600],
                    label: (seconds) =>
                        seconds == 0 ? 'Core default' : '$seconds seconds',
                    onChanged: (seconds) => _saveTcp(
                      _tcpSettings!.copyWith(keepAliveIdle: seconds),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MuxDropdown<int>(
                    title: 'Keepalive interval',
                    subtitle: 'Seconds between TCP keepalive probes',
                    value: _tcpSettings!.keepAliveInterval,
                    values: const [0, 5, 10, 15, 30, 60, 120, 300],
                    label: (seconds) =>
                        seconds == 0 ? 'Core default' : '$seconds seconds',
                    onChanged: (seconds) => _saveTcp(
                      _tcpSettings!.copyWith(keepAliveInterval: seconds),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const ValueKey('tcp-interface-field'),
                    controller: _tcpInterfaceController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) => _saveTcp(
                      _tcpSettings!.copyWith(interfaceName: value.trim()),
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('Network interface'),
                      helperText: context.tr(
                        'Optional. Empty lets Xray choose the network.',
                      ),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: context.tr('Save interface'),
                        onPressed: () => _saveTcp(
                          _tcpSettings!.copyWith(
                            interfaceName: _tcpInterfaceController.text.trim(),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('tcp-send-through-field'),
                    controller: _tcpSendThroughController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) => _saveTcp(
                      _tcpSettings!.copyWith(sendThroughAddress: value.trim()),
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('Send through local IP'),
                      helperText: context.tr(
                        'Optional source address; leave empty for automatic binding.',
                      ),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: context.tr('Save source address'),
                        onPressed: () => _saveTcp(
                          _tcpSettings!.copyWith(
                            sendThroughAddress: _tcpSendThroughController.text
                                .trim(),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MuxDropdown<XrayOutboundDomainStrategy>(
                    title: 'Proxy server DNS strategy',
                    subtitle:
                        'Controls how Xray resolves the proxy server domain.',
                    value: _tcpSettings!.domainStrategy,
                    values: XrayOutboundDomainStrategy.values,
                    label: (strategy) => switch (strategy) {
                      XrayOutboundDomainStrategy.asIs => 'System default',
                      XrayOutboundDomainStrategy.useIp => 'Use IP',
                      XrayOutboundDomainStrategy.useIPv4 => 'IPv4 only',
                      XrayOutboundDomainStrategy.useIPv6 => 'IPv6 only',
                      XrayOutboundDomainStrategy.useIPv4v6 => 'IPv4, then IPv6',
                      XrayOutboundDomainStrategy.useIPv6v4 => 'IPv6, then IPv4',
                      XrayOutboundDomainStrategy.forceIp => 'Force IP',
                      XrayOutboundDomainStrategy.forceIPv4 => 'Force IPv4',
                      XrayOutboundDomainStrategy.forceIPv6 => 'Force IPv6',
                      XrayOutboundDomainStrategy.forceIPv4v6 =>
                        'Force IPv4, then IPv6',
                      XrayOutboundDomainStrategy.forceIPv6v4 =>
                        'Force IPv6, then IPv4',
                    },
                    onChanged: (strategy) => _saveTcp(
                      _tcpSettings!.copyWith(
                        domainStrategy: strategy,
                        happyEyeballs:
                            strategy == XrayOutboundDomainStrategy.asIs
                            ? false
                            : _tcpSettings!.happyEyeballs,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MuxDropdown<XrayAddressPortStrategy>(
                    title: 'Server address discovery',
                    subtitle:
                        'Optional SRV/TXT lookup for proxy domains. Uses system DNS.',
                    value: _tcpSettings!.addressPortStrategy,
                    values: XrayAddressPortStrategy.values,
                    label: (strategy) => switch (strategy) {
                      XrayAddressPortStrategy.none => 'Disabled',
                      XrayAddressPortStrategy.srvPortOnly => 'SRV: port only',
                      XrayAddressPortStrategy.srvAddressOnly =>
                        'SRV: address only',
                      XrayAddressPortStrategy.srvPortAndAddress =>
                        'SRV: address and port',
                      XrayAddressPortStrategy.txtPortOnly => 'TXT: port only',
                      XrayAddressPortStrategy.txtAddressOnly =>
                        'TXT: address only',
                      XrayAddressPortStrategy.txtPortAndAddress =>
                        'TXT: address and port',
                    },
                    onChanged: (strategy) => _saveTcp(
                      _tcpSettings!.copyWith(addressPortStrategy: strategy),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DnsSwitch(
                    key: const ValueKey('happy-eyeballs-switch'),
                    title: 'Happy Eyeballs',
                    subtitle:
                        'Races IPv4 and IPv6 TCP addresses. Requires an IP DNS strategy.',
                    value: _tcpSettings!.happyEyeballs,
                    onChanged: (enabled) => _saveTcp(
                      _tcpSettings!.copyWith(
                        happyEyeballs: enabled,
                        domainStrategy:
                            enabled &&
                                _tcpSettings!.domainStrategy ==
                                    XrayOutboundDomainStrategy.asIs
                            ? XrayOutboundDomainStrategy.useIp
                            : _tcpSettings!.domainStrategy,
                      ),
                    ),
                  ),
                  if (_tcpSettings!.happyEyeballs) ...[
                    _MuxDropdown<int>(
                      title: 'Address race delay',
                      subtitle: 'Delay before trying the next IP family.',
                      value: _tcpSettings!.happyEyeballsDelayMs,
                      values: const [100, 200, 250, 350, 500, 750, 1000],
                      label: (milliseconds) => '$milliseconds ms',
                      onChanged: (milliseconds) => _saveTcp(
                        _tcpSettings!.copyWith(
                          happyEyeballsDelayMs: milliseconds,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DnsSwitch(
                      key: const ValueKey('happy-eyeballs-ipv6-first-switch'),
                      title: 'Prefer IPv6',
                      subtitle: 'Try IPv6 addresses before IPv4.',
                      value: _tcpSettings!.prioritizeIPv6,
                      onChanged: (enabled) => _saveTcp(
                        _tcpSettings!.copyWith(prioritizeIPv6: enabled),
                      ),
                    ),
                    _MuxDropdown<int>(
                      title: 'Address interleave',
                      subtitle: 'Mix IPv4 and IPv6 addresses while racing.',
                      value: _tcpSettings!.addressInterleave,
                      values: const [1, 2, 3, 4],
                      onChanged: (count) => _saveTcp(
                        _tcpSettings!.copyWith(addressInterleave: count),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MuxDropdown<int>(
                      title: 'Maximum concurrent attempts',
                      subtitle: 'Limit parallel TCP connection attempts.',
                      value: _tcpSettings!.maxConcurrentAddressAttempts,
                      values: const [1, 2, 4, 6, 8, 16, 32],
                      onChanged: (count) => _saveTcp(
                        _tcpSettings!.copyWith(
                          maxConcurrentAddressAttempts: count,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _MuxDropdown<int>(
                    title: 'TCP maximum segment size',
                    subtitle: 'Optional MSS for TCP packets.',
                    value: _tcpSettings!.maxSegmentBytes,
                    values: const [0, 1200, 1360, 1400, 1440, 1460],
                    label: (bytes) => bytes == 0 ? 'Core default' : '$bytes B',
                    onChanged: (bytes) => _saveTcp(
                      _tcpSettings!.copyWith(maxSegmentBytes: bytes),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MuxDropdown<int>(
                    title: 'TCP user timeout',
                    subtitle: 'How long unacknowledged data may remain.',
                    value: _tcpSettings!.userTimeoutMs,
                    values: const [0, 5000, 10000, 20000, 30000, 60000, 120000],
                    label: (milliseconds) =>
                        milliseconds == 0 ? 'Core default' : '$milliseconds ms',
                    onChanged: (milliseconds) => _saveTcp(
                      _tcpSettings!.copyWith(userTimeoutMs: milliseconds),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MuxDropdown<XrayTcpCongestionControl>(
                    title: 'TCP congestion control',
                    subtitle: 'BBR, CUBIC and Reno are applied on Linux only.',
                    value: _tcpSettings!.congestionControl,
                    values: XrayTcpCongestionControl.values,
                    label: (mode) => switch (mode) {
                      XrayTcpCongestionControl.coreDefault => 'System default',
                      XrayTcpCongestionControl.bbr => 'BBR',
                      XrayTcpCongestionControl.cubic => 'CUBIC',
                      XrayTcpCongestionControl.reno => 'Reno',
                    },
                    onChanged: (mode) => _saveTcp(
                      _tcpSettings!.copyWith(congestionControl: mode),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MuxDropdown<int>(
                    title: 'TCP receive window clamp',
                    subtitle: 'Optional maximum advertised TCP window.',
                    value: _tcpSettings!.windowClampBytes,
                    values: const [0, 65536, 131072, 262144, 524288, 1048576],
                    label: (bytes) =>
                        bytes == 0 ? 'Core default' : '${bytes ~/ 1024} KB',
                    onChanged: (bytes) => _saveTcp(
                      _tcpSettings!.copyWith(windowClampBytes: bytes),
                    ),
                  ),
                  if (Platform.isLinux)
                    _DnsSwitch(
                      key: const ValueKey('tcp-mptcp-switch'),
                      title: 'Multipath TCP',
                      subtitle: 'Linux kernel 5.6 or later.',
                      value: _tcpSettings!.multipathTcp,
                      onChanged: (enabled) => _saveTcp(
                        _tcpSettings!.copyWith(multipathTcp: enabled),
                      ),
                    ),
                  if (_tcpError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _tcpError!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _categoryHeader(context.tr('Core behavior & statistics')),
          const SizedBox(height: 8),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connection policy',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  'Xray level 0 timeouts and request buffer. Values apply after reconnecting; leave buffer empty to use the platform default.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                if (_policySettings == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('policy-handshake-field'),
                    controller: _policyHandshakeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('Handshake timeout (seconds)'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('policy-idle-field'),
                    controller: _policyIdleController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr(
                        'Connection idle timeout (seconds)',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('policy-uplink-field'),
                    controller: _policyUplinkController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('Uplink-only timeout (seconds)'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('policy-downlink-field'),
                    controller: _policyDownlinkController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('Downlink-only timeout (seconds)'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('policy-buffer-field'),
                    controller: _policyBufferController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('Request buffer (KB)'),
                      helperText: context.tr(
                        'Optional; Xray defaults depend on device architecture.',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    key: const ValueKey('policy-user-upload-switch'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Per-user upload statistics'),
                    subtitle: const Text(
                      'Requires an Xray inbound user with an email identity.',
                    ),
                    value: _policySettings!.statsUserUplink,
                    onChanged: (enabled) => setState(() {
                      _policySettings = _policySettings!.copyWith(
                        statsUserUplink: enabled,
                      );
                    }),
                  ),
                  SwitchListTile.adaptive(
                    key: const ValueKey('policy-user-download-switch'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Per-user download statistics'),
                    subtitle: const Text(
                      'Requires an Xray inbound user with an email identity.',
                    ),
                    value: _policySettings!.statsUserDownlink,
                    onChanged: (enabled) => setState(() {
                      _policySettings = _policySettings!.copyWith(
                        statsUserDownlink: enabled,
                      );
                    }),
                  ),
                  SwitchListTile.adaptive(
                    key: const ValueKey('policy-user-online-switch'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Per-user online statistics'),
                    subtitle: const Text(
                      'Counts named users active within the last 20 seconds.',
                    ),
                    value: _policySettings!.statsUserOnline,
                    onChanged: (enabled) => setState(() {
                      _policySettings = _policySettings!.copyWith(
                        statsUserOnline: enabled,
                      );
                    }),
                  ),
                  _DnsSwitch(
                    key: const ValueKey('policy-system-inbound-upload-switch'),
                    title: 'Inbound upload statistics',
                    subtitle: 'Record traffic received by local Xray inbounds.',
                    value: _policySettings!.statsInboundUplink,
                    onChanged: (enabled) => setState(() {
                      _policySettings = _policySettings!.copyWith(
                        statsInboundUplink: enabled,
                      );
                    }),
                  ),
                  _DnsSwitch(
                    key: const ValueKey(
                      'policy-system-inbound-download-switch',
                    ),
                    title: 'Inbound download statistics',
                    subtitle: 'Record traffic sent by local Xray inbounds.',
                    value: _policySettings!.statsInboundDownlink,
                    onChanged: (enabled) => setState(() {
                      _policySettings = _policySettings!.copyWith(
                        statsInboundDownlink: enabled,
                      );
                    }),
                  ),
                  _DnsSwitch(
                    key: const ValueKey('policy-system-outbound-upload-switch'),
                    title: 'Outbound upload statistics',
                    subtitle: 'Record traffic sent by Xray outbounds.',
                    value: _policySettings!.statsOutboundUplink,
                    onChanged: (enabled) => setState(() {
                      _policySettings = _policySettings!.copyWith(
                        statsOutboundUplink: enabled,
                      );
                    }),
                  ),
                  _DnsSwitch(
                    key: const ValueKey(
                      'policy-system-outbound-download-switch',
                    ),
                    title: 'Outbound download statistics',
                    subtitle: 'Record traffic received by Xray outbounds.',
                    value: _policySettings!.statsOutboundDownlink,
                    onChanged: (enabled) => setState(() {
                      _policySettings = _policySettings!.copyWith(
                        statsOutboundDownlink: enabled,
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const ValueKey('save-policy-settings'),
                      onPressed: _savingPolicy ? null : _savePolicySettings,
                      icon: _savingPolicy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 17),
                      label: Text(_savingPolicy ? 'Saving…' : 'Save policy'),
                    ),
                  ),
                  if (_policyError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _policyError!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _categoryHeader(context.tr('DNS & name resolution')),
          const SizedBox(height: 8),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DNS resolver',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                Text(
                  'Choose Xray DNS transports, address families and fallback behavior. Changes apply after reconnecting.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_dnsSettings == null)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  TextField(
                    key: const ValueKey('dns-servers-field'),
                    controller: _dnsServersController,
                    autocorrect: false,
                    enableSuggestions: false,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: context.tr('DNS servers'),
                      hintText:
                          '1.1.1.1\nhttps://dns.google/dns-query\n{"address":"9.9.9.9","domains":["geosite:example"]}',
                      helperText: context.tr(
                        'One endpoint or Xray DNS server JSON object per line. Supports UDP, TCP, DoH, DoQ and localhost. +local bypasses proxy routing; h2c is unencrypted.',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MuxDropdown<DnsQueryStrategy>(
                    title: 'Address family',
                    subtitle: 'Controls whether Xray resolves IPv4 and IPv6.',
                    value: _dnsSettings!.queryStrategy,
                    values: DnsQueryStrategy.values,
                    label: (strategy) => strategy.configValue,
                    onChanged: (strategy) => _saveDnsSettings(
                      _dnsSettings!.copyWith(queryStrategy: strategy),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('dns-hosts-field'),
                    controller: _dnsHostsController,
                    autocorrect: false,
                    enableSuggestions: false,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.tr('Custom hosts'),
                      hintText: 'example.com=93.184.216.34',
                      helperText: context.tr(
                        'One mapping per line (for example domain:example.com=93.184.216.34). Separate multiple targets with |.',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('dns-client-ip-field'),
                    controller: _dnsClientIpController,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: context.tr('EDNS client subnet (optional)'),
                      hintText: 'Leave empty for privacy',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _savingDns ? null : _saveDnsSettings,
                      icon: _savingDns
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 17),
                      label: Text(_savingDns ? 'Saving…' : 'Save DNS'),
                    ),
                  ),
                  const Divider(height: 14),
                  _DnsSwitch(
                    title: 'Parallel DNS queries',
                    subtitle: 'Race multiple configured resolvers.',
                    value: _dnsSettings!.enableParallelQuery,
                    onChanged: (enabled) => _saveDnsSettings(
                      _dnsSettings!.copyWith(enableParallelQuery: enabled),
                    ),
                  ),
                  _DnsSwitch(
                    title: 'Disable fallback',
                    subtitle: 'Do not try another resolver after a failure.',
                    value: _dnsSettings!.disableFallback,
                    onChanged: (enabled) => _saveDnsSettings(
                      _dnsSettings!.copyWith(disableFallback: enabled),
                    ),
                  ),
                  _DnsSwitch(
                    title: 'Disable fallback on domain match',
                    subtitle:
                        'Keep matching domains on their selected resolver.',
                    value: _dnsSettings!.disableFallbackIfMatch,
                    onChanged: (enabled) => _saveDnsSettings(
                      _dnsSettings!.copyWith(disableFallbackIfMatch: enabled),
                    ),
                  ),
                  _DnsSwitch(
                    title: 'Disable DNS cache',
                    subtitle:
                        'Resolve through the configured servers each time.',
                    value: _dnsSettings!.disableCache,
                    onChanged: (enabled) => _saveDnsSettings(
                      _dnsSettings!.copyWith(disableCache: enabled),
                    ),
                  ),
                  _DnsSwitch(
                    title: 'Serve stale DNS answers',
                    subtitle: 'Return cached answers while refreshing them.',
                    value: _dnsSettings!.serveStale,
                    onChanged: (enabled) => _saveDnsSettings(
                      _dnsSettings!.copyWith(serveStale: enabled),
                    ),
                  ),
                  if (_dnsSettings!.serveStale)
                    _MuxDropdown<int>(
                      title: 'Stale answer lifetime',
                      subtitle: 'Seconds after the cached DNS record expires.',
                      value: _dnsSettings!.serveExpiredTtl,
                      values: const [0, 60, 300, 900, 3600, 86400],
                      label: (seconds) =>
                          seconds == 0 ? 'No extra limit' : '$seconds seconds',
                      onChanged: (seconds) => _saveDnsSettings(
                        _dnsSettings!.copyWith(serveExpiredTtl: seconds),
                      ),
                    ),
                  _DnsSwitch(
                    title: 'Use system hosts file',
                    subtitle: 'Add device hosts mappings to Xray DNS.',
                    value: _dnsSettings!.useSystemHosts,
                    onChanged: (enabled) => _saveDnsSettings(
                      _dnsSettings!.copyWith(useSystemHosts: enabled),
                    ),
                  ),
                  _DnsSwitch(
                    title: 'FakeDNS',
                    subtitle:
                        'Give domains synthetic IPs so Xray can recover their names.',
                    value: _dnsSettings!.fakeDns,
                    onChanged: (enabled) => _saveDnsSettings(
                      _dnsSettings!.copyWith(fakeDns: enabled),
                    ),
                  ),
                  if (_dnsSettings!.fakeDns) ...[
                    const SizedBox(height: 6),
                    Text(
                      'FakeDNS is active in Xray. After disconnecting, cached synthetic addresses can briefly remain on the device.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ],
                if (_dnsError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _dnsError!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _categoryHeader(context.tr('Connection optimization')),
          const SizedBox(height: 8),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mux and XUDP',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  'Controls how Xray reuses TCP connections and carries UDP. Changes apply after reconnecting.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                if (_muxSettings == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Mux'),
                    subtitle: Text(
                      muxIncompatibility ?? 'Multiplex TCP connections',
                    ),
                    value: _muxSettings!.enabled,
                    onChanged:
                        muxIncompatibility != null && !_muxSettings!.enabled
                        ? null
                        : (enabled) => _saveMux(
                            _muxSettings!.copyWith(enabled: enabled),
                          ),
                  ),
                  if (_muxSettings!.enabled) ...[
                    const SizedBox(height: 8),
                    _MuxDropdown<int>(
                      title: 'TCP concurrency',
                      subtitle: 'Maximum concurrent streams on one connection',
                      value: _muxSettings!.concurrency,
                      values: const [1, 2, 4, 8, 16, 32, 64, 128],
                      onChanged: (value) =>
                          _saveMux(_muxSettings!.copyWith(concurrency: value)),
                    ),
                    const SizedBox(height: 12),
                    _MuxDropdown<int>(
                      title: 'XUDP concurrency',
                      subtitle: 'UDP streams carried by XUDP',
                      value: _muxSettings!.xudpConcurrency,
                      values: const [1, 4, 8, 16, 32, 64, 128, 256, 512, 1024],
                      onChanged: (value) => _saveMux(
                        _muxSettings!.copyWith(xudpConcurrency: value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MuxDropdown<Udp443Behavior>(
                      title: 'UDP/443 behavior',
                      subtitle: 'Choose how QUIC traffic uses XUDP',
                      value: _muxSettings!.udp443Behavior,
                      values: Udp443Behavior.values,
                      label: (value) => value.name,
                      onChanged: (value) => _saveMux(
                        _muxSettings!.copyWith(udp443Behavior: value),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _categoryHeader(context.tr('Routing & privacy')),
          const SizedBox(height: 8),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: Platform.isAndroid
                  ? () => Navigator.of(
                      context,
                    ).push(appRoute(const AndroidAppRoutingScreen()))
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  const Icon(Icons.apps_outlined, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Apps outside the VPN',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          Platform.isAndroid
                              ? 'Choose Android apps that use your regular connection.'
                              : 'App-based routing is supported on Android. Site rules work on this device.',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Platform.isAndroid
                        ? Icons.chevron_right
                        : Icons.lock_outline,
                    size: 19,
                    color: muted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sites outside the VPN',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                Text(
                  'Add one domain per line. Traffic to these sites uses your regular connection after the next VPN reconnect.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('bypass-domain-field'),
                  controller: _bypassController,
                  minLines: 2,
                  maxLines: 4,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: 'example.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Advanced routing rules',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('add-xray-routing-rule'),
                      onPressed: _savingRouting
                          ? null
                          : () => _editRoutingRule(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add rule'),
                    ),
                  ],
                ),
                if (_routingRules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      'Match domains, addresses, ports, processes, or HTTP traffic and send it through proxy, direct, or block.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                for (final entry in _routingRules.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark
                              ? .45
                              : .72,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: .35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _savingRouting
                                  ? null
                                  : () => _editRoutingRule(
                                      rule: entry.$2,
                                      index: entry.$1,
                                    ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.$2.action.name.toUpperCase()}  ·  ${_routingRuleSummary(entry.$2)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _routingRuleMatchers(entry.$2),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: context.tr('Delete rule'),
                            onPressed: _savingRouting
                                ? null
                                : () => _removeRoutingRule(entry.$1),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_routingError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _routingError!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const ValueKey('save-bypass-domains'),
                    onPressed: _savingRouting ? null : _saveRouting,
                    child: Text(_savingRouting ? 'Saving…' : 'Save routing'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _categoryHeader(context.tr('Traffic inspection')),
          const SizedBox(height: 8),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Traffic sniffing',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  'Detect destination names in tunneled traffic for Xray routing. Reconnect to apply.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                if (_sniffingSettings == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    key: const ValueKey('xray-sniffing-enabled'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable sniffing'),
                    subtitle: const Text('Inspect traffic for route matching.'),
                    value: _sniffingSettings!.enabled,
                    onChanged: (enabled) => setState(() {
                      _sniffingSettings = _sniffingSettings!.copyWith(
                        enabled: enabled,
                      );
                    }),
                  ),
                  Text(
                    'Protocols',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final protocol in const [
                        'http',
                        'tls',
                        'quic',
                        'fakedns',
                      ])
                        FilterChip(
                          key: ValueKey('xray-sniffing-$protocol'),
                          label: Text(protocol.toUpperCase()),
                          selected: protocol == 'fakedns'
                              ? _dnsSettings?.fakeDns == true
                              : _sniffingSettings!.destOverride.contains(
                                  protocol,
                                ),
                          onSelected: protocol == 'fakedns'
                              ? _dnsSettings == null
                                    ? null
                                    : (selected) => _saveDnsSettings(
                                        _dnsSettings!.copyWith(
                                          fakeDns: selected,
                                        ),
                                      )
                              : (selected) => setState(() {
                                  final overrides = [
                                    ..._sniffingSettings!.destOverride,
                                  ];
                                  if (selected) {
                                    overrides.add(protocol);
                                  } else {
                                    overrides.remove(protocol);
                                  }
                                  _sniffingSettings = _sniffingSettings!
                                      .copyWith(destOverride: overrides);
                                }),
                        ),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    key: const ValueKey('xray-sniffing-route-only'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Route-only'),
                    subtitle: const Text(
                      'Use the detected domain for rules; keep the original IP as the connection target.',
                    ),
                    value: _sniffingSettings!.routeOnly,
                    onChanged: (enabled) => setState(() {
                      _sniffingSettings = _sniffingSettings!.copyWith(
                        routeOnly: enabled,
                      );
                    }),
                  ),
                  SwitchListTile.adaptive(
                    key: const ValueKey('xray-sniffing-metadata-only'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Metadata-only'),
                    subtitle: const Text(
                      'Avoid reading application payloads. HTTP, TLS and QUIC content sniffers are disabled.',
                    ),
                    value: _sniffingSettings!.metadataOnly,
                    onChanged: (enabled) => setState(() {
                      _sniffingSettings = _sniffingSettings!.copyWith(
                        metadataOnly: enabled,
                      );
                    }),
                  ),
                  if (_dnsSettings?.fakeDns == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'FakeDNS requires sniffing; Xray keeps FakeDNS recovery enabled while it is active.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                  TextField(
                    key: const ValueKey('xray-sniffing-excluded-domains'),
                    controller: _sniffingDomainsController,
                    minLines: 1,
                    maxLines: 3,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('Excluded domains'),
                      hintText: 'courier.push.apple.com\nfull:service.example',
                      helperText: context.tr(
                        'One Xray domain matcher per line.',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('xray-sniffing-excluded-ips'),
                    controller: _sniffingIpsController,
                    minLines: 1,
                    maxLines: 3,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('Excluded IPs'),
                      hintText: '192.168.1.1\n2001:db8::/32',
                      helperText: context.tr(
                        'One IP, CIDR or geoip matcher per line.',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_sniffingError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _sniffingError!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('save-xray-sniffing'),
                      onPressed: _savingSniffing ? null : _saveSniffing,
                      child: Text(
                        _savingSniffing ? 'Saving…' : 'Save sniffing',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.memory_outlined, size: 19),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Installed Xray core',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                FutureBuilder<String>(
                  future: _coreVersion,
                  builder: (context, snapshot) => Text(
                    snapshot.data ?? 'Checking…',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _categoryHeader(context.tr('Advanced core options')),
          const SizedBox(height: 8),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Core version guard',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  'Xray itself blocks startup outside these optional version bounds. Leave both blank to clear the guard; reconnect to apply.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                if (_versionRequirement == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('xray-version-minimum'),
                          controller: _versionMinimumController,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: context.tr('Minimum version'),
                            hintText: '26.9.9',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('xray-version-maximum'),
                          controller: _versionMaximumController,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: context.tr('Maximum version'),
                            hintText: '26.9.9',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_versionRequirementError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _versionRequirementError!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const ValueKey('save-xray-version-guard'),
                      onPressed: _savingVersionRequirement
                          ? null
                          : _saveVersionRequirement,
                      icon: _savingVersionRequirement
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 17),
                      label: Text(
                        _savingVersionRequirement ? 'Saving…' : 'Save guard',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FinalMask',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  'Configure Xray TCP and UDP masks or QUIC tuning for the selected proxy. The core validates mask-specific options when you connect.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_finalMaskSettings == null)
                  const Center(child: CircularProgressIndicator())
                else
                  TextField(
                    key: const ValueKey('xray-finalmask-field'),
                    controller: _finalMaskController,
                    minLines: 4,
                    maxLines: 10,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('FinalMask object'),
                      hintText:
                          '{"tcp":[{"type":"fragment","settings":{"packets":"tlshello","lengths":["100-200"]}}]}',
                      helperText: context.tr(
                        'Use Xray FinalMask JSON: tcp, udp, and/or quicParams. Leave {} to remove app-level overrides.',
                      ),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (_finalMaskError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _finalMaskError!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const ValueKey('save-xray-finalmask'),
                    onPressed: _savingFinalMask || _finalMaskSettings == null
                        ? null
                        : _saveFinalMask,
                    icon: _savingFinalMask
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 17),
                    label: Text(
                      _savingFinalMask ? 'Saving…' : 'Save FinalMask',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Custom Xray JSON',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  'Merge advanced Xray options into every imported server. Object fields merge recursively; arrays replace the matching field. Reconnect to apply. Invalid core options prevent connection.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('xray-custom-config-field'),
                  controller: _customConfigController,
                  minLines: 5,
                  maxLines: 14,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: context.tr('Xray config object'),
                    hintText: '{"routing":{"domainStrategy":"IPIfNonMatch"}}',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_customConfigError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _customConfigError!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const ValueKey('save-custom-xray-config'),
                    onPressed: _savingCustomConfig ? null : _saveCustomConfig,
                    icon: _savingCustomConfig
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 17),
                    label: Text(_savingCustomConfig ? 'Saving…' : 'Save JSON'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FrostedCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xray logs',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  'Choose which sanitized Xray diagnostics are captured. Raw connection details and file logs stay disabled.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_logLevel == null)
                  const Center(child: CircularProgressIndicator())
                else
                  _DropdownMenuField<XrayLogLevel>(
                    title: 'Log level',
                    value: _logLevel!,
                    values: XrayLogLevel.values,
                    label: (level) => level.label,
                    onSelected: _saveLogLevel,
                  ),
                if (_logError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _logError!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

Widget _categoryHeader(String title) => Builder(
  builder: (context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    return Padding(
      padding: const EdgeInsets.only(left: 3, top: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: muted,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  },
);

String _routingRuleSummary(XrayRoutingRule rule) {
  final parts = <String>[
    if (rule.domains.isNotEmpty) '${rule.domains.length} domains',
    if (rule.ips.isNotEmpty) '${rule.ips.length} IP ranges',
    if (rule.ports.isNotEmpty) '${rule.ports.length} ports',
    if (rule.sourceIps.isNotEmpty) '${rule.sourceIps.length} source IPs',
    if (rule.localIps.isNotEmpty) '${rule.localIps.length} local IPs',
    if (rule.sourcePorts.isNotEmpty) '${rule.sourcePorts.length} source ports',
    if (rule.localPorts.isNotEmpty) '${rule.localPorts.length} local ports',
    if (rule.networks.isNotEmpty) rule.networks.join('/').toUpperCase(),
    if (rule.protocols.isNotEmpty) rule.protocols.join('/').toUpperCase(),
    if (rule.attributes.isNotEmpty) '${rule.attributes.length} HTTP attrs',
    if (rule.processes.isNotEmpty) '${rule.processes.length} processes',
    if (rule.webhook != null) 'webhook',
  ];
  return parts.join(' · ');
}

String _routingRuleMatchers(XrayRoutingRule rule) => [
  ...rule.domains,
  ...rule.ips,
  if (rule.ports.isNotEmpty) 'port ${rule.ports.join(', ')}',
  if (rule.sourcePorts.isNotEmpty) 'sourcePort ${rule.sourcePorts.join(', ')}',
  if (rule.localPorts.isNotEmpty) 'localPort ${rule.localPorts.join(', ')}',
  if (rule.networks.isNotEmpty) 'network ${rule.networks.join(', ')}',
  if (rule.sourceIps.isNotEmpty) 'sourceIP ${rule.sourceIps.join(', ')}',
  if (rule.localIps.isNotEmpty) 'localIP ${rule.localIps.join(', ')}',
  if (rule.inboundTags.isNotEmpty) 'inbound ${rule.inboundTags.join(', ')}',
  if (rule.users.isNotEmpty) 'user ${rule.users.join(', ')}',
  if (rule.protocols.isNotEmpty) 'protocol ${rule.protocols.join(', ')}',
  ...rule.attributes.entries.map((entry) => '${entry.key}=${entry.value}'),
  ...rule.processes.map((process) => 'process $process'),
  if (rule.ruleTag.trim().isNotEmpty) 'rule ${rule.ruleTag}',
].join('  ·  ');

class _RoutingRuleDialog extends StatefulWidget {
  const _RoutingRuleDialog({this.rule});

  final XrayRoutingRule? rule;

  @override
  State<_RoutingRuleDialog> createState() => _RoutingRuleDialogState();
}

class _RoutingRuleDialogState extends State<_RoutingRuleDialog> {
  late final TextEditingController _domains;
  late final TextEditingController _ips;
  late final TextEditingController _ports;
  late final TextEditingController _sourcePorts;
  late final TextEditingController _localPorts;
  late final TextEditingController _sourceIps;
  late final TextEditingController _localIps;
  late final TextEditingController _inboundTags;
  late final TextEditingController _users;
  late final TextEditingController _attributes;
  late final TextEditingController _processes;
  late final TextEditingController _ruleTag;
  late final TextEditingController _webhookUrl;
  late final TextEditingController _webhookDeduplication;
  late final TextEditingController _webhookHeaders;
  late XrayRoutingAction _action;
  late Set<String> _networks;
  late Set<String> _protocols;
  String? _error;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _domains = TextEditingController(text: rule?.domains.join('\n') ?? '');
    _ips = TextEditingController(text: rule?.ips.join('\n') ?? '');
    _ports = TextEditingController(text: rule?.ports.join(', ') ?? '');
    _sourcePorts = TextEditingController(
      text: rule?.sourcePorts.join(', ') ?? '',
    );
    _localPorts = TextEditingController(
      text: rule?.localPorts.join(', ') ?? '',
    );
    _sourceIps = TextEditingController(text: rule?.sourceIps.join('\n') ?? '');
    _localIps = TextEditingController(text: rule?.localIps.join('\n') ?? '');
    _inboundTags = TextEditingController(
      text: rule?.inboundTags.join('\n') ?? '',
    );
    _users = TextEditingController(text: rule?.users.join('\n') ?? '');
    _attributes = TextEditingController(
      text:
          rule?.attributes.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join('\n') ??
          '',
    );
    _processes = TextEditingController(text: rule?.processes.join('\n') ?? '');
    _ruleTag = TextEditingController(text: rule?.ruleTag ?? '');
    _webhookUrl = TextEditingController(text: rule?.webhook?.url ?? '');
    _webhookDeduplication = TextEditingController(
      text: rule?.webhook?.deduplicationSeconds.toString() ?? '300',
    );
    _webhookHeaders = TextEditingController(
      text: const JsonEncoder.withIndent(
        '  ',
      ).convert(rule?.webhook?.headers ?? const <String, String>{}),
    );
    _action = rule?.action ?? XrayRoutingAction.direct;
    _networks = rule?.networks.toSet() ?? <String>{};
    _protocols = rule?.protocols.toSet() ?? <String>{};
  }

  @override
  void dispose() {
    _domains.dispose();
    _ips.dispose();
    _ports.dispose();
    _sourcePorts.dispose();
    _localPorts.dispose();
    _sourceIps.dispose();
    _localIps.dispose();
    _inboundTags.dispose();
    _users.dispose();
    _attributes.dispose();
    _processes.dispose();
    _ruleTag.dispose();
    _webhookUrl.dispose();
    _webhookDeduplication.dispose();
    _webhookHeaders.dispose();
    super.dispose();
  }

  void _save() {
    try {
      final webhookUrl = _webhookUrl.text.trim();
      final rule = XrayRoutingRule(
        action: _action,
        domains: XrayRoutingRule.parseDomains(_domains.text),
        ips: XrayRoutingRule.parseIps(_ips.text),
        ports: XrayRoutingRule.parsePorts(_ports.text),
        sourcePorts: XrayRoutingRule.parsePorts(_sourcePorts.text),
        localPorts: XrayRoutingRule.parsePorts(_localPorts.text),
        networks: _networks.toList()..sort(),
        sourceIps: XrayRoutingRule.parseIps(_sourceIps.text),
        localIps: XrayRoutingRule.parseIps(_localIps.text),
        inboundTags: XrayRoutingRule.parseValues(_inboundTags.text),
        users: XrayRoutingRule.parseValues(_users.text),
        protocols: _protocols.toList()..sort(),
        attributes: XrayRoutingRule.parseAttributes(_attributes.text),
        processes: XrayRoutingRule.parseValues(_processes.text),
        ruleTag: _ruleTag.text.trim(),
        webhook: webhookUrl.isEmpty
            ? null
            : XrayRoutingWebhook.fromEditor(
                url: webhookUrl,
                deduplicationSeconds: _webhookDeduplication.text,
                headersJson: _webhookHeaders.text,
              ),
      );
      rule.validate();
      Navigator.of(context).pop(rule);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    return AlertDialog(
      title: Text(
        widget.rule == null ? 'Add routing rule' : 'Edit routing rule',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<XrayRoutingAction>(
                key: const ValueKey('xray-route-action'),
                initialValue: _action,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('Route traffic to'),
                ),
                items: const [
                  DropdownMenuItem(
                    value: XrayRoutingAction.proxy,
                    child: Text('VPN proxy'),
                  ),
                  DropdownMenuItem(
                    value: XrayRoutingAction.direct,
                    child: Text('Direct connection'),
                  ),
                  DropdownMenuItem(
                    value: XrayRoutingAction.block,
                    child: Text('Block'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _action = value);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('xray-route-domains'),
                controller: _domains,
                minLines: 1,
                maxLines: 3,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: context.tr('Domains'),
                  hintText: 'example.com\nfull:login.example.com',
                  helperText: context.tr(
                    'One per line. Also supports geosite: and keyword:.',
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('xray-route-ips'),
                controller: _ips,
                minLines: 1,
                maxLines: 3,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: context.tr('IP / CIDR'),
                  hintText: '192.168.1.0/24\ngeoip:private',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('xray-route-ports'),
                controller: _ports,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: context.tr('Destination ports'),
                  hintText: '443, 8000-8100',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Text('Network', style: TextStyle(color: muted, fontSize: 12)),
              Wrap(
                spacing: 8,
                children: [
                  for (final network in const ['tcp', 'udp'])
                    FilterChip(
                      label: Text(network.toUpperCase()),
                      selected: _networks.contains(network),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _networks.add(network);
                        } else {
                          _networks.remove(network);
                        }
                      }),
                    ),
                ],
              ),
              Text(
                'Leave both off to match TCP and UDP.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
              ExpansionTile(
                key: const ValueKey('xray-route-advanced-matchers'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Advanced matchers'),
                children: [
                  TextField(
                    key: const ValueKey('xray-route-source-ports'),
                    controller: _sourcePorts,
                    decoration: InputDecoration(
                      labelText: context.tr('Source ports'),
                      hintText: '53, 1000-2000',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('xray-route-local-ports'),
                    controller: _localPorts,
                    decoration: InputDecoration(
                      labelText: context.tr('Local inbound ports'),
                      hintText: '1080, 8000-8100',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('xray-route-source-ips'),
                    controller: _sourceIps,
                    minLines: 1,
                    maxLines: 3,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('Source IP / CIDR'),
                      hintText: '192.168.1.0/24',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('xray-route-local-ips'),
                    controller: _localIps,
                    minLines: 1,
                    maxLines: 3,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('Local inbound IP / CIDR'),
                      hintText: '127.0.0.1\ngeoip:private',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('xray-route-inbound-tags'),
                    controller: _inboundTags,
                    minLines: 1,
                    maxLines: 3,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('Inbound tags'),
                      hintText: 'tun-in',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('xray-route-users'),
                    controller: _users,
                    minLines: 1,
                    maxLines: 3,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('User / email'),
                      hintText: 'client@example.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('xray-route-processes'),
                    controller: _processes,
                    minLines: 1,
                    maxLines: 3,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('Process name / path'),
                      hintText: 'browser\nC:/Apps/app.exe',
                      helperText: context.tr(
                        'Supported by Xray on Windows and Linux.',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sniffed protocol',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final protocol in const [
                        'http',
                        'tls',
                        'quic',
                        'bittorrent',
                      ])
                        FilterChip(
                          label: Text(protocol.toUpperCase()),
                          selected: _protocols.contains(protocol),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _protocols.add(protocol);
                            } else {
                              _protocols.remove(protocol);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('xray-route-http-attributes'),
                    controller: _attributes,
                    minLines: 1,
                    maxLines: 4,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('HTTP headers / method / path'),
                      hintText: ':method=GET\n:path=/api\naccept=text/html',
                      helperText: context.tr(
                        'Values are regular expressions. Requires traffic sniffing.',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('xray-route-rule-tag'),
                    controller: _ruleTag,
                    maxLength: 128,
                    decoration: InputDecoration(
                      labelText: context.tr('Rule name (optional)'),
                      hintText: 'Direct local API',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Webhook on match (optional)',
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('xray-route-webhook-url'),
                    controller: _webhookUrl,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('Webhook URL'),
                      hintText: 'https://hooks.example.com/route',
                      helperText: context.tr(
                        'Xray sends matching connection details to this address.',
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('xray-route-webhook-deduplication'),
                    controller: _webhookDeduplication,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.tr('Duplicate suppression (seconds)'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('xray-route-webhook-headers'),
                    controller: _webhookHeaders,
                    minLines: 2,
                    maxLines: 5,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: context.tr('Webhook headers (JSON object)'),
                      hintText: '{"X-API-Key": "…"}',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Done')),
      ],
    );
  }
}

class _MuxDropdown<T> extends StatelessWidget {
  const _MuxDropdown({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.values,
    required this.onChanged,
    this.label,
  });

  final String title;
  final String subtitle;
  final T value;
  final List<T> values;
  final ValueChanged<T> onChanged;
  final String Function(T value)? label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: dark
                ? AppTheme.foregroundMuted
                : AppTheme.lightForegroundMuted,
          ),
        ),
        const SizedBox(height: 7),
        _DropdownMenuField<T>(
          title: title,
          value: value,
          values: values,
          label: label ?? (item) => item.toString(),
          onSelected: onChanged,
        ),
      ],
    );
  }
}

/// Xray settings use the same rounded, frosted popup treatment as the server
/// sorter instead of platform-default dropdown sheets.
class _DropdownMenuField<T> extends StatelessWidget {
  const _DropdownMenuField({
    super.key,
    required this.title,
    required this.value,
    required this.values,
    required this.label,
    required this.onSelected,
  });

  final String title;
  final T value;
  final List<T> values;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? AppTheme.foreground : AppTheme.lightForeground;
    final muted = dark
        ? AppTheme.foregroundMuted
        : AppTheme.lightForegroundMuted;
    final border = dark ? AppTheme.cardBorder : AppTheme.lightCardBorder;
    final menuBackground = dark ? const Color(0xFF15191F) : Colors.white;
    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 24;
        final itemWidth = (menuWidth - 12).clamp(0.0, menuWidth);
        return MenuAnchor(
          key: ValueKey('xray-dropdown-$title'),
          alignmentOffset: const Offset(0, 4),
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(menuBackground),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shadowColor: WidgetStatePropertyAll(
              Colors.black.withValues(alpha: .35),
            ),
            elevation: const WidgetStatePropertyAll(16),
            padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
            minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
            maximumSize: WidgetStatePropertyAll(Size(menuWidth, 360)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: border),
              ),
            ),
          ),
          menuChildren: [
            for (final option in values)
              SizedBox(
                width: itemWidth,
                height: 44,
                child: MenuItemButton(
                  onPressed: () => onSelected(option),
                  style: ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(foreground),
                    backgroundColor: WidgetStatePropertyAll(
                      option == value
                          ? AppTheme.successColor.withValues(alpha: .10)
                          : Colors.transparent,
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 10),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label(option),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (option == value) ...[
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: AppTheme.successColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
          builder: (context, controller, _) => Semantics(
            button: true,
            label: '$title: ${label(value)}',
            expanded: controller.isOpen,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: .035)
                      : Colors.black.withValues(alpha: .025),
                  border: Border.all(
                    color: controller.isOpen
                        ? AppTheme.successColor.withValues(alpha: .45)
                        : border,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: foreground, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: controller.isOpen ? .5 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 19,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DnsSwitch extends StatelessWidget {
  const _DnsSwitch({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  }) : _switchKey = key;

  final Key? _switchKey;

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      key: _switchKey,
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}
