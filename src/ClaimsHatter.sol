// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { HatsErrors } from "hats-protocol/Interfaces/HatsErrors.sol";

abstract contract ClaimsHatterBase {
  // Hats Protocol contract
  IHats public immutable HATS;

  constructor() {
    HATS = IHats(0x850f3384829D7bab6224D141AFeD9A559d745E3D); // v1.hatsprotocol.eth
  }

  /// @notice Internal function that mints a _hat for an explicitly eligible _wearer
  function _mint(uint256 _hatId, address _wearer) internal {
    // revert if _wearer is not explicitly eligible
    if (!_isEligible(_hatId, _wearer)) revert HatsErrors.NotEligible();
    // mint the hat to _wearer if eligible. This contract can mint as long as its the hat's admin.
    HATS.mintHat(_hatId, _wearer);
  }

  /// @notice Internal function that checks if _wearer is explicitly eligible to wear _hatId
  /// @dev Explicit eligibility can only come from a mechanistic eligitibility module, ie a contract that implements IHatsEligibility
  function _isEligible(uint256 _hatId, address _wearer) internal view returns (bool eligible) {
    // get the hat's eligibility module address
    (,,, address eligibility,,,,,) = HATS.viewHat(_hatId);
    // get _wearer's eligibility status from the eligibility module
    bool standing;
    (bool success, bytes memory returndata) =
      eligibility.staticcall(abi.encodeWithSignature("getWearerStatus(address,uint256)", _wearer, _hatId));

    /* 
    * if function call succeeds with data of length == 64, then we know the contract exists 
    * and has the getWearerStatus function (which returns two words).
    * But — since function selectors don't include return types — we still can't assume that the return data is two booleans, 
    * so we treat it as a uint so it will always safely decode without throwing.
    */
    if (success && returndata.length == 64) {
      // check the returndata manually
      (uint256 firstWord, uint256 secondWord) = abi.decode(returndata, (uint256, uint256));
      // returndata is valid
      if (firstWord < 2 && secondWord < 2) {
        standing = (secondWord == 1) ? true : false;
        // never eligible if in bad standing
        eligible = (standing && firstWord == 1) ? true : false;
      }
      // returndata is invalid
      else {
        // revert since _wearer is not explicitly eligible
        revert HatsErrors.NotHatsEligibility();
      }
    } else {
      // revert since _wearer is not explicitly eligible
      revert HatsErrors.NotHatsEligibility();
    }
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
    _mint(hat, msg.sender);
  }

  function claimFor(address _wearer) external {
    _mint(hat, _wearer);
  }
}

contract ClaimsHatterMulti is ClaimsHatterBase {
  error NotClaimable();
  // The hat ids claimable via this contract

  mapping(uint256 hatId => bool claimable) public claimableHats;

  function makeClaimable(uint256 _hatId) external {
    // caller must be an admin of _hatId to make it claimable by this contract
    if (!HATS.isAdminOfHat(msg.sender, _hatId)) revert HatsErrors.NotAdmin(msg.sender, _hatId);
    // this contract must also be an admin of _hatId to be able to mint it when claimed
    if (!HATS.isAdminOfHat(address(this), _hatId)) revert HatsErrors.NotHatWearer();
    // enable _hatId to be claimed
    claimableHats[_hatId] = true;
  }

  function claim(uint256 _hatId) external onlyClaimable(_hatId) {
    _mint(_hatId, msg.sender);
  }

  function claimFor(uint256 _hatId, address _wearer) external onlyClaimable(_hatId) {
    _mint(_hatId, _wearer);
  }

  modifier onlyClaimable(uint256 _hatId) {
    if (!claimableHats[_hatId]) revert NotClaimable();
    _;
  }
}
