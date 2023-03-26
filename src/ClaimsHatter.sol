// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { HatsErrors } from "hats-protocol/Interfaces/HatsErrors.sol";

/* 
- TODO tests
*/

/// @title ClaimsHatter
/// @notice Contract that enables explicitly eligible wearers to self-mint (claim) hats
/// @dev To function properly, this contract must wear an admin of the hat(s) to be claimed
contract ClaimsHatter {
  /// @notice Emmitted when attempting to claim a hat that is not claimable
  error NotClaimable();
  /// @notice Emmitted when attempting to claim for another wearer a hat for which claiming for others is not enabled
  error NotClaimableFor();

  /// @notice Claimability configuration for a hat
  struct ClaimabilityData {
    bool claimable; // claimable by an explicitly eligible wearer
    bool claimableFor; // claimable by anybody for an explicitly eligible wearer
  }

  /// @notice The hat ids claimable via this contract
  mapping(uint256 hatId => ClaimabilityData claimability) public claimableHats;
  /// @notice Hats Protocol interface
  IHats public immutable HATS;

  constructor() {
    HATS = IHats(0x850f3384829D7bab6224D141AFeD9A559d745E3D); // v1.hatsprotocol.eth
  }

  /*//////////////////////////////////////////////////////////////
                    EXTERNAL & PUBLIC FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Make a hat claimable by (and optionally for) an explicitly eligible wearer
   * @dev The caller must be an admin of the hat, and this contract must also be an admin of the hat.
   *  If this contract is NOT an admin of the hat, it will not be able to mint it when claimed.
   *  To make this contract an admin of the hat, mint it an admin hat.
   * @param _hatId The id of the hat to make claimable
   * @param _claimableFor Whether to enable anybody to claim the hat for an explicitly eligible wearer
   */
  function makeClaimable(uint256 _hatId, bool _claimableFor) external {
    // caller must be an admin of _hatId to make it claimable by this contract
    if (!HATS.isAdminOfHat(msg.sender, _hatId)) revert HatsErrors.NotAdmin(msg.sender, _hatId);
    // this contract must also be an admin of _hatId to be able to mint it when claimed
    if (!HATS.isAdminOfHat(address(this), _hatId)) revert HatsErrors.NotHatWearer();
    // enable _hatId to be claimed
    claimableHats[_hatId].claimable = true;
    // if desired, enable anybody to claim _hatId for an explicitly eligible wearer
    if (_claimableFor) claimableHats[_hatId].claimableFor = true;
  }

  /**
   * @notice Make a hat "claimable for" an explicitly eligible wearer, by anybody
   * @dev The caller must be an admin of the hat, this contract must also be an admin of the hat,
   *  and the hat must already be claimable.
   *  If this contract is NOT an admin of the hat, it will not be able to mint it when claimed.
   *  To make this contract an admin of the hat, mint it an admin hat.
   * @param _hatId The id of the hat to enable "claiming for"
   */
  function makeClaimableFor(uint256 _hatId) external {
    // caller must be an admin of _hatId to make it claimable by this contract
    if (!HATS.isAdminOfHat(msg.sender, _hatId)) revert HatsErrors.NotAdmin(msg.sender, _hatId);
    // this contract must also be an admin of _hatId to be able to mint it when claimed
    if (!HATS.isAdminOfHat(address(this), _hatId)) revert HatsErrors.NotHatWearer();
    // _hatId must already be claimable, which includes this contract being an admin of it
    if (!isClaimable(_hatId)) revert NotClaimable();
    // enable anybody to claim _hatId for an explicitly eligible wearer
    claimableHats[_hatId].claimableFor = true;
  }

  /**
   * @notice Claim a hat
   * @dev The caller must be explicitly eligible to wear the hat, and the hat must be claimable.
   *  This contract must also be an admin of the hat, or the mint will fail.
   * @param _hatId The id of the hat to claim
   */
  function claim(uint256 _hatId) external {
    if (!isClaimable(_hatId)) revert NotClaimable();
    _mint(_hatId, msg.sender);
  }

  /**
   * @notice Claim a hat for an explicitly eligible wearer
   * @dev The hat must be claimable. This contract must also be an admin of the hat, or the mint will fail.
   * @param _hatId The id of the hat to claim
   * @param _wearer The address of the would-be wearer
   */
  function claimFor(uint256 _hatId, address _wearer) external {
    if (!isClaimableFor(_hatId)) revert NotClaimableFor();
    _mint(_hatId, _wearer);
  }

  /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @notice Internal function that mints a _hat for an explicitly eligible _wearer
  /// @param _hatId The id of the hat to mint
  /// @param _wearer The address of the would-be wearer
  function _mint(uint256 _hatId, address _wearer) internal {
    // revert if _wearer is not explicitly eligible
    if (!_isEligible(_hatId, _wearer)) revert HatsErrors.NotEligible();
    // mint the hat to _wearer if eligible. This contract can mint as long as its the hat's admin.
    HATS.mintHat(_hatId, _wearer);
  }

  // TODO do we need all this extra validation logic? Maybe calling the eligibility module directly is sufficient.
  /// @notice Internal function that checks if _wearer is explicitly eligible to wear _hatId
  /// @dev Explicit eligibility can only come from a mechanistic eligitibility module, ie a contract that implements IHatsEligibility
  /// @param _hatId The id of the hat to check
  /// @param _wearer The address of the would-be wearer to check for eligibility
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
        // false since _wearer is not explicitly eligible
        eligible = false;
      }
    } else {
      // false since _wearer is not explicitly eligible
      eligible = false;
    }
  }

  /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @notice View function that checks if a hat is claimable
  /// @param _hatId The id of the hat to check
  /// @return claimable True if the hat is claimable
  function isClaimable(uint256 _hatId) public view returns (bool claimable) {
    claimable = claimableHats[_hatId].claimable;
  }

  /// @notice View function that checks if a hat is claimable for an explicitly eligible wearer
  /// @param _hatId The id of the hat to check
  /// @return claimableFor True if the hat is "claimable for"
  function isClaimableFor(uint256 _hatId) public view returns (bool claimableFor) {
    claimableFor = claimableHats[_hatId].claimableFor;
  }
}
