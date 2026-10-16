import 'package:flutter/foundation.dart';

enum MoleTruthKind {
  extraCharge,
  condition,
  substitution,
  arithmetic,
  obligation,
}

enum MoleTruthDocumentKind { receipt, advertisement, contract, productLabel }

String moleCoinAmount(int amount) {
  final hundreds = amount.abs() % 100;
  final units = amount.abs() % 10;
  final word = hundreds >= 11 && hundreds <= 14
      ? 'монет'
      : units == 1
      ? 'монета'
      : units >= 2 && units <= 4
      ? 'монеты'
      : 'монет';
  return '$amount $word';
}

/// IDs describe content, never screen coordinates. A layout owns its hit boxes.
@immutable
class MoleTruthSpan {
  const MoleTruthSpan({
    required this.id,
    required this.printed,
    this.truth,
    this.explanation,
    this.kind,
    this.value,
    this.truthValue,
  });

  final String id;
  final String printed;
  final String? truth;
  final String? explanation;
  final MoleTruthKind? kind;
  final String? value;
  final String? truthValue;
  bool get isTrick =>
      (truth != null && truth != printed) ||
      (truthValue != null && truthValue != value);
  String get printedDescription => value == null ? printed : '$printed, $value';
  String get truthDescription =>
      '${truth ?? printed}${truthValue == null && value == null ? '' : ', ${truthValue ?? value}'}';
}

@immutable
class MoleTruthLine {
  const MoleTruthLine(this.spans);
  final List<MoleTruthSpan> spans;
}

@immutable
class MoleTruthCase {
  const MoleTruthCase({
    required this.id,
    required this.stepNo,
    required this.title,
    required this.documentTitle,
    required this.agreement,
    required this.lines,
    required this.billedTotal,
    required this.fairTotal,
    required this.serverAnswerCode,
    required this.verdictLabel,
    required this.sellerReply,
    required this.lesson,
    required this.hint,
    this.intro = '',
    this.purchaseAssets = const [],
    this.documentKind = MoleTruthDocumentKind.receipt,
  });

  final String id;
  final int stepNo;
  final String title;
  final String documentTitle;

  /// Independent evidence: what the buyer actually agreed to.
  final String agreement;
  final List<MoleTruthLine> lines;
  final int billedTotal;
  final int fairTotal;

  /// Preserves the existing five-step server validation, including the
  /// intermediate sum of 19 on step four (the corrected bill is 17).
  final String serverAnswerCode;
  final String verdictLabel;
  final String sellerReply;
  final String lesson;
  final String hint;
  final String intro;
  final List<String> purchaseAssets;
  final MoleTruthDocumentKind documentKind;

  Iterable<MoleTruthSpan> get spans => lines.expand((line) => line.spans);
  Iterable<MoleTruthSpan> get tricks => spans.where((span) => span.isTrick);
}
