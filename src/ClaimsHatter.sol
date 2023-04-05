// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { Clone } from "solady/utils/Clone.sol";

/// @title ClaimsHatter
/// @author Haberdasher Labs
/// @notice Enables explicitly eligible wearers to self-mint (claim) a Hats Protocol hat
/// @dev To function properly, this contract must wear an admin hat of the hat to be claimed
contract ClaimsHatter is Clone {
  /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
  //////////////////////////////////////////////////////////////*/

  /// @notice Emmitted when attempting to claim for another wearer a hat for which claiming for others is not enabled
  error ClaimsHatter_NotClaimableFor();
  /// @notice Emitted when attempting to call an admin-only function from a non-admin
  error ClaimsHatter_NotHatAdmin();
  /// @notice Emitted when attempting to claim a hat by or for a wearer who is not explicitly eligible
  error ClaimsHatter_NotExplicitlyEligible();

  /*//////////////////////////////////////////////////////////////
                                EVENTS
  //////////////////////////////////////////////////////////////*/

  /// @notice Emitted when "claimability for" is enabled or disabled
  event ClaimingForChanged(uint256 _hatId, bool _claimableFor);

  /*//////////////////////////////////////////////////////////////
                              CONSTANTS
  //////////////////////////////////////////////////////////////*/

  /**
   * This contract is a clone with immutable args, which means that it is deployed with a set of
   * immutable storage variables (ie constants). Accessing these constants is cheaper than accessing 
   * regular storage variables (such as those set on initialization of a typical EIP-1167 clone),
   * but requires a slightly different approach since they are read from calldata instead of storage.
   *  
   * Below is a table of constants and their location.
   *
   * For more, see here: https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args
   *
   * --------------------------------------------------------------------+
   * CLONE IMMUTABLE "STORAGE"                                           |
   * --------------------------------------------------------------------|
   * Offset  | Constant | Type    | Length  |                            |
   * --------------------------------------------------------------------|
   * 0       | FACTORY  | address | 20      |                            |
   * 20      | HATS     | address | 20      |                            |
   * 40      | hat      | uint256 | 32      |                            |
   * --------------------------------------------------------------------+
   */

  /// @notice The address of the ClaimsHatterFactory that deployed this contract
  function FACTORY() public pure returns (address) {
    return _getArgAddress(0);
  }

  /// @notice Hats Protocol address
  function HATS() public pure returns (IHats) {
    return IHats(_getArgAddress(20));
  }

  /// @notice The hat claimable via this contract
  function hat() public pure returns (uint256) {
    return _getArgUint256(40);
  }

  /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
  //////////////////////////////////////////////////////////////*/

  /// @notice Whether this hat is claimable on behalf of an explicitly eligible wearer
  bool internal _claimableFor;

  /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Make the hat "claimable for" an explicitly eligible wearer, by anybody
   * @dev The caller must be an admin of the hat, this contract must also be an admin of the hat,
   *  and the hat must already be claimable.
   *  If this contract is NOT an admin of the hat, it will not be able to mint it when claimed.
   *  To make this contract an admin of the hat, mint it an admin hat.
   */
  function enableClaimingFor() external onlyAdminOrFactory {
    // enable anybody to claim _hatId for an explicitly eligible wearer
    _claimableFor = true;
    // log the change
    emit ClaimingForChanged(hat(), true);
  }

  /**
   * @notice Make the hat unclaimable on behalf of an explicitly eligible wearer
   * @dev The caller must be an admin of the hat
   */
  function disableClaimingFor() external onlyAdmin {
    // disable anybody from claiming _hatId for an explicitly eligible wearer
    _claimableFor = false;
    // log the change
    emit ClaimingForChanged(hat(), false);
  }

  /*//////////////////////////////////////////////////////////////
                          CLAIMING FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Claim the hat
   * @dev The caller must be explicitly eligible to wear the hat, and the hat must be claimable.
   *  This contract must also wear an admin hat of the claimed hat, or the claim will fail.
   */
  function claimHat() external {
    _mint(msg.sender);
  }

  /**
   * @notice Claim the hat for an explicitly eligible wearer
   * @dev claimingFor must be allowed. This contract must also wear an admin hat of the claimed hat, or the claim will fail.
   * @param _wearer The address on whose behalf to claim the hat
   */
  function claimHatFor(address _wearer) external {
    if (!_claimableFor) revert ClaimsHatter_NotClaimableFor();
    _mint(_wearer);
  }

  /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Internal function that mints a _hat for an explicitly eligible _wearer
   * @param _wearer The address of the would-be wearer
   */
  function _mint(address _wearer) internal {
    // revert if _wearer is not explicitly eligible
    if (!_isExplicitlyEligible(_wearer)) revert ClaimsHatter_NotExplicitlyEligible();
    // mint the hat to _wearer if eligible. This contract can mint as long as its the hat's admin.
    HATS().mintHat(hat(), _wearer);
  }

  /**
   * @notice Checks if _wearer is explicitly eligible to wear the hat.
   * @dev Explicit eligibility can only come from a mechanistic eligitibility module, ie a contract that implements IHatsEligibility
   * @param _wearer The address of the would-be wearer to check for eligibility
   */
  function _isExplicitlyEligible(address _wearer) internal view returns (bool eligible) {
    // get the hat's eligibility module address
    address eligibility = HATS().getHatEligibilityModule(hat());
    // get _wearer's eligibility status from the eligibility module
    bool standing;
    (bool success, bytes memory returndata) =
      eligibility.staticcall(abi.encodeWithSignature("getWearerStatus(address,uint256)", _wearer, hat()));

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

  /// @notice Whether the hat is claimable
  /// @dev Requires that this contract wears an admin hat
  function claimable() public view returns (bool) {
    return (hatExists() && wearsAdmin());
  }

  /// @notice Whether the hat is claimable on behalf of an explicitly eligible wearer
  /// @dev Requires that this contract wears an admin hat
  function claimableFor() public view returns (bool) {
    return (_claimableFor && hatExists() && wearsAdmin());
  }

  /// @notice Whether this contract wears an admin hat of the hat to claim
  function wearsAdmin() public view returns (bool) {
    return HATS().isAdminOfHat(address(this), hat());
  }

  /// @notice Whether the hat to claim exists
  function hatExists() public view returns (bool) {
    return HATS().getHatMaxSupply(hat()) > 0;
  }

  /*//////////////////////////////////////////////////////////////
                            MODIFIERS
  //////////////////////////////////////////////////////////////*/

  /// @notice Ensure caller is either an admin of the hat, or the factory that deployed this contract
  /// @dev If the factory is the caller, the caller of *that* function must have been an admin of the hat
  modifier onlyAdminOrFactory() {
    if (!HATS().isAdminOfHat(msg.sender, hat()) && msg.sender != FACTORY()) {
      // Only admins can call via the factory, so this error is always relevant
      revert ClaimsHatter_NotHatAdmin();
    }
    _;
  }

  /// @notice Ensure caller is an admin of the hat
  modifier onlyAdmin() {
    if (!HATS().isAdminOfHat(msg.sender, hat())) revert ClaimsHatter_NotHatAdmin();
    _;
  }
}
