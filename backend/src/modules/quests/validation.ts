export interface UiSpec {
  correctOptionCode?: string;
  answerValidation?: {
    kind?: string;
    expectedSequence?: string[];
    acceptedOptions?: string[];
    budget?: number;
    minimumRemaining?: number;
    itemPrices?: Record<string, number>;
    requiredGroups?: Array<{ label?: string; itemIds?: string[] }>;
  };
  [key: string]: unknown;
}

export function answerMatches(
  uiSpec: UiSpec | null,
  selectedOptionCode?: string,
): boolean {
  const validation = uiSpec?.answerValidation;
  if (validation?.kind === "ORDERED_SEQUENCE") {
    const expected = validation.expectedSequence;
    if (!expected?.length || !selectedOptionCode) return false;
    return selectedOptionCode === expected.join(",");
  }

  if (validation?.kind === "BUDGET_SELECTION") {
    const budget = validation.budget;
    const itemPrices = validation.itemPrices;
    if (
      !Number.isInteger(budget) ||
      (budget ?? 0) < 0 ||
      !itemPrices ||
      !selectedOptionCode
    ) {
      return false;
    }
    const selectedIds = selectedOptionCode.split(",").filter(Boolean);
    if (
      selectedIds.length === 0 ||
      new Set(selectedIds).size !== selectedIds.length
    ) {
      return false;
    }
    let total = 0;
    for (const itemId of selectedIds) {
      const price = itemPrices[itemId];
      if (!Number.isInteger(price) || (price ?? -1) < 0) return false;
      total += price!;
    }
    return total <= budget!;
  }

  if (validation?.kind === "REQUIRED_BUDGET_SELECTION") {
    const budget = validation.budget;
    const minimumRemaining = validation.minimumRemaining ?? 0;
    const itemPrices = validation.itemPrices;
    const requiredGroups = validation.requiredGroups;
    if (
      !Number.isInteger(budget) ||
      (budget ?? 0) < 0 ||
      !Number.isInteger(minimumRemaining) ||
      minimumRemaining < 0 ||
      minimumRemaining > (budget ?? -1) ||
      !itemPrices ||
      !requiredGroups?.length ||
      !selectedOptionCode
    ) {
      return false;
    }

    const selectedIds = selectedOptionCode.split(",").filter(Boolean);
    if (
      selectedIds.length === 0 ||
      new Set(selectedIds).size !== selectedIds.length
    ) {
      return false;
    }

    let total = 0;
    for (const itemId of selectedIds) {
      const price = itemPrices[itemId];
      if (!Number.isInteger(price) || (price ?? -1) < 0) return false;
      total += price!;
    }
    if (total > budget! - minimumRemaining) return false;

    return requiredGroups.every(
      (group) =>
        Array.isArray(group.itemIds) &&
        group.itemIds.length > 0 &&
        group.itemIds.some((itemId) => selectedIds.includes(itemId)),
    );
  }

  if (validation?.kind === "ONE_OF") {
    const accepted = validation.acceptedOptions;
    return Boolean(
      selectedOptionCode &&
        accepted?.length &&
        accepted.includes(selectedOptionCode),
    );
  }

  return (
    typeof uiSpec?.correctOptionCode === "string" &&
    uiSpec.correctOptionCode === selectedOptionCode
  );
}
