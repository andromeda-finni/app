/// A fur color choice offered on onboarding step 1. `id` matches
/// `cosmetic_options.id` in the backend (see db/migrations/0003_pet.sql) so
/// the value collected here can be sent to `POST /pet` as-is once the later
/// onboarding steps (and account creation) exist.
class FurColorOption {
  const FurColorOption({required this.id, required this.label, required this.swatch});

  final String id;
  final String label;
  final int swatch; // ARGB color value, kept as int to avoid importing Flutter here.
}

/// Data collected across all 4 onboarding steps. Only step 1's fields are
/// populated for now; later steps add to this as they're built.
class OnboardingData {
  OnboardingData({this.petName = '', this.furColorId});

  String petName;
  String? furColorId;

  OnboardingData copyWith({String? petName, String? furColorId}) {
    return OnboardingData(
      petName: petName ?? this.petName,
      furColorId: furColorId ?? this.furColorId,
    );
  }
}
