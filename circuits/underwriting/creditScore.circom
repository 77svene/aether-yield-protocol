pragma circom 2.1.4;

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";

/**
 * @title CreditScoreVerifier
 * @notice Verifies that a user's aggregated credit score meets a minimum threshold.
 * The score is derived from a private set of wallet balances/histories, 
 * committed to by a trusted Credit Bureau service.
 */
template CreditScoreVerifier(nWallets) {
    // Public Inputs
    signal input minRequiredScore;
    signal input scoreCommitment; // Poseidon(score, salt)
    
    // Private Inputs
    signal input actualScore;
    signal input salt;
    signal input walletBalances[nWallets]; // Individual scores/balances per wallet

    // 1. Verify the score matches the sum of wallet balances
    // This ensures the user isn't just picking a random high number.
    var sum = 0;
    for (var i = 0; i < nWallets; i++) {
        // Ensure no negative balances (though uint in circom, good practice)
        component posCheck = GreaterEqThan(252);
        posCheck.in[0] <== walletBalances[i];
        posCheck.in[1] <== 0;
        posCheck.out === 1;
        
        sum += walletBalances[i];
    }
    actualScore === sum;

    // 2. Verify the commitment matches the actual score and salt
    // This prevents the user from claiming a sum that wasn't signed/attested by the bureau.
    component hasher = Poseidon(2);
    hasher.inputs[0] <== actualScore;
    hasher.inputs[1] <== salt;
    hasher.out === scoreCommitment;

    // 3. Threshold Check: actualScore >= minRequiredScore
    component thresholdCheck = GreaterEqThan(252);
    thresholdCheck.in[0] <== actualScore;
    thresholdCheck.in[1] <== minRequiredScore;
    thresholdCheck.out === 1;

    // 4. Range Check: Ensure score doesn't overflow field
    component rangeCheck = LessThan(252);
    rangeCheck.in[0] <== actualScore;
    rangeCheck.in[1] <== 1 * 10**18; // Cap at 1 quintillion units
    rangeCheck.out === 1;
}

component main { public [minRequiredScore, scoreCommitment] } = CreditScoreVerifier(3);