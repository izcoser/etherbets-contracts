/**
 * Generate all combinations of an array.
 * @param {Array} sourceArray - Array of input elements.
 * @param {number} comboLength - Desired length of combinations.
 * @return {Array} Array of combination arrays.
 */
generateCombinations = function(sourceArray, comboLength) {
    const sourceLength = sourceArray.length;
    if (comboLength > sourceLength) return [];

    const combos = []; // Stores valid combinations as they are generated.

    // Accepts a partial combination, an index into sourceArray, 
    // and the number of elements required to be added to create a full-length combination.
    // Called recursively to build combinations, adding subsequent elements at each call depth.
    const makeNextCombos = (workingCombo, currentIndex, remainingCount) => {
        const oneAwayFromComboLength = remainingCount == 1;

        // For each element that remaines to be added to the working combination.
        for (let sourceIndex = currentIndex; sourceIndex < sourceLength; sourceIndex++) {
            // Get next (possibly partial) combination.
            const next = [...workingCombo, sourceArray[sourceIndex]];

            if (oneAwayFromComboLength) {
                // Combo of right length found, save it.
                combos.push(next);
            }
            else {
                // Otherwise go deeper to add more elements to the current partial combination.
                makeNextCombos(next, sourceIndex + 1, remainingCount - 1);
            }
        }
    }

    makeNextCombos([], 0, comboLength);
    return combos;
}

module.exports = generateCombinations;
