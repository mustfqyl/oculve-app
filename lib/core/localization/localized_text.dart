import 'package:flutter/material.dart' as material;

import 'app_strings.dart';

/// A drop-in Text widget that translates reviewed interface phrases while
/// preserving dynamic values such as server names and account data.
class Text extends material.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final material.InlineSpan? textSpan;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final material.TextWidthBasis? textWidthBasis;
  final material.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;

  @override
  material.Widget build(material.BuildContext context) {
    final language = material.Localizations.localeOf(context).languageCode;
    final label = semanticsLabel == null
        ? null
        : AppStrings.translate(semanticsLabel!, language);
    if (textSpan != null) {
      return material.Text.rich(
        textSpan!,
        key: key,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: label,
        semanticsIdentifier: semanticsIdentifier,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return material.Text(
      AppStrings.translate(data!, language),
      key: key,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: label,
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

/// Keeps short labels on one line and scales them only when their container is
/// narrower than the translated phrase. Paragraphs should continue using
/// [Text] so they can reflow naturally instead of shrinking.
class CompactLabel extends material.StatelessWidget {
  const CompactLabel(
    this.data, {
    super.key,
    this.style,
    this.textAlign = material.TextAlign.center,
    this.alignment = material.Alignment.center,
    this.semanticsLabel,
  });

  final String data;
  final material.TextStyle? style;
  final material.TextAlign textAlign;
  final material.Alignment alignment;
  final String? semanticsLabel;

  @override
  material.Widget build(material.BuildContext context) => material.FittedBox(
    fit: material.BoxFit.scaleDown,
    alignment: alignment,
    child: Text(
      data,
      style: style,
      textAlign: textAlign,
      softWrap: false,
      maxLines: 1,
      semanticsLabel: semanticsLabel,
    ),
  );
}
