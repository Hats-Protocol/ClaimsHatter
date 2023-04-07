// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IHatsEligibility } from "hats-protocol/Interfaces/IHatsEligibility.sol";

/// @notice A mock Hats Protocol eligibility contract that always returns true for all hats and wearers
/// @dev Do not use this contract in production
contract AllEligibleMock is IHatsEligibility {
  /// @notice Mock eligibility function that returns true for all hats and wearers
  function getWearerStatus(address, uint256) external pure returns (bool, bool) {
    return (true, true);
  }
}
