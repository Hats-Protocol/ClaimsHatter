// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IHatsEligibility } from "hats-protocol/Interfaces/IHatsEligibility.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { HatsErrors } from "hats-protocol/Interfaces/HatsErrors.sol";

abstract contract ClaimsHatterBase {
  // Hats Protocol contract
  IHats public immutable HATS;

  constructor() {
    HATS = IHats(0x850f3384829D7bab6224D141AFeD9A559d745E3D); // v1.hatsprotocol.eth
  }

  function _claim(uint256 _hatId, address _wearer) internal {
    // revert if _wearer is not eligible
    if (!_isEligible(_hatId, _wearer)) revert HatsErrors.NotEligible();
    // mint the hat to _wearer if eligible. This contract can mint as long as its the hat's admin.
    HATS.mintHat(_hatId, _wearer);
  }

  function _isEligible(uint256 _hatId, address _wearer) internal view returns (bool eligible) {
    // get the hat's eligibility module address
    (,,, address eligibility,,,,,) = HATS.viewHat(_hatId);
    // get _wearer's eligibility status from the eligibility module
    bool standing;
    (eligible, standing) = IHatsEligibility(eligibility).getWearerStatus(_wearer, _hatId);
    // if not in good standing, the wearer is never eligible (even if `eligible` is true)
    if (!standing) eligible = false;
  }
}

contract ClaimsHatterSingle is ClaimsHatterBase {
  // The hat id claimable via this contract
  uint256 public immutable hat;

  constructor(uint256 _hat) {
    hat = _hat;
  }

  function claim() external {
    _claim(hat, msg.sender);
  }

  function claimFor(address _wearer) external {
    _claim(hat, _wearer);
  }
}

contract ClaimsHatter { }
