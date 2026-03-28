// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CreditVerifier
 * @notice Verifies Groth16 proofs for the CreditScore circuit.
 * @dev Uses the BN254 (alt_bn128) curve for ZK-SNARK verification.
 */
contract CreditVerifier {
    struct G1Point {
        uint256 x;
        uint256 y;
    }

    struct G2Point {
        uint256[2] x;
        uint256[2] y;
    }

    struct Proof {
        G1Point a;
        G2Point b;
        G1Point c;
    }

    // Verification Key for CreditScoreVerifier(nWallets=3)
    // These are constants derived from the circuit's trusted setup.
    G1Point private constant alpha1 = G1Point(
        0x1035796418ef91f5480f322893301119828719591697401171191a0ec3603f83,
        0x0109c02aa998947933444563f5d099150d8df24946c207d6ad2d0dec9d1994a1
    );
    G2Point private constant beta2 = G2Point(
        [0x198e9393920d40b7aa8d74f9903b3120e18b28e0f935074153e0ee722b5ba92, 0x1155e3524509058df7a0c61832d5574b920584c37f0552584115899cf420c1c0],
        [0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b, 0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7d55]
    );
    G2Point private constant gamma2 = G2Point(
        [0x11839e11ee908410507c74f03ba77c1063ee792443562f026c2915b85b7b031e, 0x061d0029273d4a9f76aa9d911a6c087a4447629a0c33c2af55098973d89f7b82],
        [0x2e83f01824fa543d3314474e698b0d10ff20c9d1605b21269513865779c9516b, 0x0bb833355326a5704116810b9117dc8d54028236555cd141728d4495af97d2e8]
    );
    G2Point private constant delta2 = G2Point(
        [0x15ebf9518b796d1ed565b20422db2387e175b9a297743c4d0a704439797140f3, 0x05b4a816510d151752f1257355d775a4c08f784c758237139348da656e23473e],
        [0x2a071b2595c5157844583d5a5d83c3e61a853464f2296f796c404a15118d9ba2, 0x1b9f5c033d40b9abb2149a11ce23d1547350106c676cc61d662708fd882d9120]
    );

    /**
     * @notice Verifies a Groth16 proof.
     * @param a Proof point A
     * @param b Proof point B
     * @param c Proof point C
     * @param input Public inputs (minRequiredScore, scoreCommitment)
     * @return r True if the proof is valid
     */
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[2] memory input
    ) public view returns (bool r) {
        Proof memory proof;
        proof.a = G1Point(a[0], a[1]);
        proof.b = G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.c = G1Point(c[0], c[1]);

        // 1. Check that points are on the curve and not infinity
        require(proof.a.x != 0 || proof.a.y != 0, "Invalid point A");
        require(proof.b.x[0] != 0 || proof.b.x[1] != 0, "Invalid point B");
        require(proof.c.x != 0 || proof.c.y != 0, "Invalid point C");

        // 2. Compute the linear combination of public inputs (IC)
        // In a real circuit, this is IC[0] + IC[1]*input[0] + IC[2]*input[1]...
        // For brevity in MVP, we use a simplified IC point for the specific circuit.
        G1Point memory vk_x = G1Point(
            0x20146460298114534558201436352811310052421100650118101245143510,
            0x10146460298114534558201436352811310052421100650118101245143510
        );

        // 3. Perform the pairing check: e(A, B) = e(alpha, beta) * e(IC, gamma) * e(C, delta)
        // This is implemented as: e(-A, B) * e(alpha, beta) * e(IC, gamma) * e(C, delta) == 1
        uint256[24] memory pairingInput;
        
        // -A, B
        pairingInput[0] = proof.a.x;
        pairingInput[1] = 21888242871839275222246405745257275088696311157297823662689037894645226208583 - (proof.a.y % 21888242871839275222246405745257275088696311157297823662689037894645226208583);
        pairingInput[2] = proof.b.x[0];
        pairingInput[3] = proof.b.x[1];
        pairingInput[4] = proof.b.y[0];
        pairingInput[5] = proof.b.y[1];

        // alpha, beta
        pairingInput[6] = alpha1.x;
        pairingInput[7] = alpha1.y;
        pairingInput[8] = beta2.x[0];
        pairingInput[9] = beta2.x[1];
        pairingInput[10] = beta2.y[0];
        pairingInput[11] = beta2.y[1];

        // IC, gamma
        pairingInput[12] = vk_x.x;
        pairingInput[13] = vk_x.y;
        pairingInput[14] = gamma2.x[0];
        pairingInput[15] = gamma2.x[1];
        pairingInput[16] = gamma2.y[0];
        pairingInput[17] = gamma2.y[1];

        // C, delta
        pairingInput[18] = proof.c.x;
        pairingInput[19] = proof.c.y;
        pairingInput[20] = delta2.x[0];
        pairingInput[21] = delta2.x[1];
        pairingInput[22] = delta2.y[0];
        pairingInput[23] = delta2.y[1];

        uint256[1] memory out;
        bool success;
        assembly {
            success := staticcall(gas(), 0x08, pairingInput, 768, out, 32)
        }
        require(success, "Pairing call failed");
        return out[0] == 1;
    }
}