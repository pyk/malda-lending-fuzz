// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

contract Risc0VerifierMock {
    struct Receipt {
        bytes seal;
        bytes32 claimDigest;
    }

    bool public shouldRevert;

    function setStatus(bool _failure) external {
        shouldRevert = _failure;
    }

    function verify(bytes calldata, bytes32, bytes32) external view {
        if (shouldRevert) {
            revert("Failure");
        }
    }

    function verifyIntegrity(Receipt calldata) external view {
        if (shouldRevert) {
            revert("Failure");
        }
    }
}
