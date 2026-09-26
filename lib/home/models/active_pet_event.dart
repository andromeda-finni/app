class ActivePetEvent {
  const ActivePetEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.amountDue,
  });

  final String id;
  final String title;
  final String description;
  final int amountDue;

  factory ActivePetEvent.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final description = json['description'];
    final amount = json['amount_due'];
    if (id is! String ||
        title is! String ||
        description is! String ||
        amount is! num ||
        amount != amount.toInt() ||
        amount <= 0) {
      throw const FormatException('Invalid active pet event');
    }
    return ActivePetEvent(
      id: id,
      title: title,
      description: description,
      amountDue: amount.toInt(),
    );
  }
}
