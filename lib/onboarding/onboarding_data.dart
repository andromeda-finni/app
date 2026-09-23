/// A fur color choice offered on onboarding step 1. `id` matches
/// `cosmetic_options.id` in the backend (see db/migrations/0003_pet.sql) so
/// the value collected here can be sent to `POST /pet` as-is once the later
/// onboarding steps (and account creation) exist.
class FurColorOption {
  const FurColorOption({
    required this.id,
    required this.label,
    required this.swatch,
    required this.catAsset,
  });

  final String id;
  final String label;
  final int
  swatch; // ARGB color value, kept as int to avoid importing Flutter here.

  /// The cat drawn in this fur, shown on step 1 as soon as this option is
  /// picked and cropped into the option's own swatch.
  final String catAsset;
}

/// Total coins the tutorial budget on step 3 distributes between the three
/// categories. Maps to budget_plans.need_amount/want_amount/savings_amount
/// in the backend (see db/migrations/0007_periods.sql) once wired up —
/// candy = WANT, other things = NEED, piggy bank = SAVINGS.
const kTutorialBudgetTotal = 10;

/// Data collected across all 4 onboarding steps.
class OnboardingData {
  OnboardingData({
    this.petName = '',
    this.furColorId,
    this.candyAmount = 4,
    this.otherAmount = 2,
    this.piggyAmount = 4,
  });

  String petName;
  String? furColorId;

  // Step 3: tutorial budget split. Always sums to kTutorialBudgetTotal.
  int candyAmount; // WANT
  int otherAmount; // NEED
  int piggyAmount; // SAVINGS

  int get allocated => candyAmount + otherAmount + piggyAmount;
  int get unallocated => kTutorialBudgetTotal - allocated;

  OnboardingData copyWith({
    String? petName,
    String? furColorId,
    int? candyAmount,
    int? otherAmount,
    int? piggyAmount,
  }) {
    return OnboardingData(
      petName: petName ?? this.petName,
      furColorId: furColorId ?? this.furColorId,
      candyAmount: candyAmount ?? this.candyAmount,
      otherAmount: otherAmount ?? this.otherAmount,
      piggyAmount: piggyAmount ?? this.piggyAmount,
    );
  }
}
