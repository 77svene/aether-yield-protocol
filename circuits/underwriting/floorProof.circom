pragma circom 2.1.4;

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/eddsaposeidon.circom";

/**
 * @title FloorPriceVerifier
 * @notice Verifies that an NFT floor price is above a threshold using a signed oracle message.
 * Prevents: Replay attacks (timestamp), Data fabrication (EdDSA), and Overflow (Range checks).
 */
template FloorPriceVerifier() {
    // Public Inputs
    signal input minRequiredPrice;
    signal input oraclePubKeyX;
    signal input oraclePubKeyY;
    signal input currentTimestamp;
    signal input maxDelay; // Max allowed age of the price data

    // Private Inputs (The Oracle's Message)
    signal input actualPrice;
    signal input assetId;
    signal input timestamp;
    signal input sigR8x;
    signal input sigR8y;
    signal input sigS;

    // 1. Range Checks: Ensure prices are within 252-bit prime field limits to prevent overflow
    component rpActual = LessThan(252);
    rpActual.in[0] <== actualPrice;
    rpActual.in[1] <== 1 * 10**30; // Reasonable cap for a price
    rpActual.out === 1;

    // 2. Verify Data Freshness: currentTimestamp - timestamp <= maxDelay
    // Equivalent to: timestamp <= currentTimestamp AND currentTimestamp <= timestamp + maxDelay
    component ageCheck1 = LessEqThan(252);
    ageCheck1.in[0] <== timestamp;
    ageCheck1.in[1] <== currentTimestamp;
    ageCheck1.out === 1;

    component ageCheck2 = LessEqThan(252);
    ageCheck2.in[0] <== currentTimestamp;
    ageCheck2.in[1] <== timestamp + maxDelay;
    ageCheck2.out === 1;

    // 3. Verify Oracle Signature (EdDSA Poseidon)
    // Message = Poseidon(assetId, actualPrice, timestamp)
    component msgHasher = Poseidon(3);
    msgHasher.inputs[0] <== assetId;
    msgHasher.inputs[1] <== actualPrice;
    msgHasher.inputs[2] <== timestamp;

    component verifier = EdDSAPoseidonVerifier();
    verifier.enabled <== 1;
    verifier.Ax <== oraclePubKeyX;
    verifier.Ay <== oraclePubKeyY;
    verifier.R8x <== sigR8x;
    verifier.R8y <== sigR8y;
    verifier.S <== sigS;
    verifier.M <== msgHasher.out;

    // 4. Business Logic: actualPrice >= minRequiredPrice
    component gte = GreaterEqThan(252);
    gte.in[0] <== actualPrice;
    gte.in[1] <== minRequiredPrice;
    gte.out === 1;
}

component main {public [minRequiredPrice, oraclePubKeyX, oraclePubKeyY, currentTimestamp, maxDelay]} = FloorPriceVerifier();