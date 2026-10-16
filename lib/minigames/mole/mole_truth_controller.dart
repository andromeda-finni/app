import 'package:flutter/foundation.dart';

import 'mole_truth_models.dart';

enum MoleTruthConfirmation { found, alreadyFound, honest, inspectFirst, closed }

class MoleTruthController extends ChangeNotifier {
  MoleTruthController(this.document);

  final MoleTruthCase document;
  final Set<String> _exposed = {};
  String? _inspectedId;
  bool _resolved = false;

  Set<String> get exposedIds => Set.unmodifiable(_exposed);
  String? get inspectedId => _inspectedId;
  bool get resolved => _resolved;
  bool get canConfront =>
      !_resolved && _exposed.length == document.tricks.length;

  void inspect(String? id) {
    if (_resolved || _inspectedId == id) return;
    if (id != null && !document.spans.any((span) => span.id == id)) return;
    _inspectedId = id;
    notifyListeners();
  }

  MoleTruthConfirmation confirm(String id) {
    if (_resolved) return MoleTruthConfirmation.closed;
    if (_exposed.contains(id)) return MoleTruthConfirmation.alreadyFound;
    if (_inspectedId != id) return MoleTruthConfirmation.inspectFirst;
    final matches = document.spans.where((span) => span.id == id);
    if (matches.isEmpty) return MoleTruthConfirmation.inspectFirst;
    if (!matches.single.isTrick) return MoleTruthConfirmation.honest;
    _exposed.add(id);
    notifyListeners();
    return MoleTruthConfirmation.found;
  }

  bool confront() {
    if (!canConfront) return false;
    _resolved = true;
    notifyListeners();
    return true;
  }
}
