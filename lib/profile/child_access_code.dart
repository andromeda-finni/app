String childAccessCodeFrom(String? opaqueId) {
  final compact = (opaqueId ?? '')
      .replaceAll(RegExp('[^a-zA-Z0-9]'), '')
      .toUpperCase();
  if (compact.length < 8) return 'GR-DEMO-0317';
  final tail = compact.substring(compact.length - 8);
  return 'GR-${tail.substring(0, 4)}-${tail.substring(4)}';
}
