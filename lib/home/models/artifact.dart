class Artifact {
  const Artifact({
    required this.inventoryId,
    required this.itemId,
    required this.name,
    required this.equipped,
  });

  final String inventoryId;
  final String itemId;
  final String name;
  final bool equipped;

  factory Artifact.fromJson(Map<String, dynamic> json) {
    final inventoryId = json['id'];
    final itemId = json['item_id'];
    final name = json['name'];
    if (inventoryId is! String || itemId is! String || name is! String) {
      throw const FormatException('artifact is incomplete');
    }
    return Artifact(
      inventoryId: inventoryId,
      itemId: itemId,
      name: name,
      equipped: json['equipped'] == true,
    );
  }
}
