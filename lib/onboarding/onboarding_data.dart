/// A fur color choice offered on onboarding step 1. `id` matches
/// `cosmetic_options.id` in the backend (see db/migrations/0003_pet.sql) so
/// the value collected here can be sent to `PUT /pet` as-is.
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

  /// The cat drawn in this fur, shown in the main scene as soon as this option
  /// is picked. The selector itself intentionally stays a flat colour swatch.
  final String catAsset;
}

/// Shown on step 1 until a fur colour has been chosen. This is the exact same
/// artwork as the grey option, so choosing grey causes no visual jump. The
/// option itself still remains unselected until the child taps it.
const kBaseCatAsset = 'assets/Cat/Red_collar/base/striped.png';

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
    this.candyAmount = 0,
    this.otherAmount = 0,
    this.piggyAmount = 0,
    this.budgetPracticed = false,
  });

  String petName;
  String? furColorId;

  // Step 3: tutorial budget split. Always sums to kTutorialBudgetTotal.
  int candyAmount; // WANT
  int otherAmount; // NEED
  int piggyAmount; // SAVINGS
  bool budgetPracticed;

  int get allocated => candyAmount + otherAmount + piggyAmount;
  int get unallocated => kTutorialBudgetTotal - allocated;

  OnboardingData copyWith({
    String? petName,
    String? furColorId,
    int? candyAmount,
    int? otherAmount,
    int? piggyAmount,
    bool? budgetPracticed,
  }) {
    return OnboardingData(
      petName: petName ?? this.petName,
      furColorId: furColorId ?? this.furColorId,
      candyAmount: candyAmount ?? this.candyAmount,
      otherAmount: otherAmount ?? this.otherAmount,
      piggyAmount: piggyAmount ?? this.piggyAmount,
      budgetPracticed: budgetPracticed ?? this.budgetPracticed,
    );
  }
}

class OnboardingResumeState {
  const OnboardingResumeState({
    required this.currentStep,
    required this.completed,
    required this.data,
  });

  factory OnboardingResumeState.fresh() => OnboardingResumeState(
    currentStep: 1,
    completed: false,
    data: OnboardingData(),
  );

  factory OnboardingResumeState.fromJson(Map<String, dynamic> json) {
    final currentStep = json['currentStep'];
    final completed = json['completed'];
    if (currentStep is! int ||
        currentStep < 1 ||
        currentStep > 4 ||
        completed is! bool) {
      throw const FormatException('Invalid onboarding status response');
    }

    final rawPet = json['pet'];
    var data = OnboardingData();
    if (rawPet != null) {
      if (rawPet is! Map<String, dynamic> ||
          rawPet['petName'] is! String ||
          rawPet['furOptionId'] is! String) {
        throw const FormatException('Invalid onboarding pet response');
      }
      data = data.copyWith(
        petName: rawPet['petName'] as String,
        furColorId: rawPet['furOptionId'] as String,
      );
    }

    return OnboardingResumeState(
      currentStep: currentStep,
      completed: completed,
      data: data,
    );
  }

  final int currentStep;
  final bool completed;
  final OnboardingData data;
}
