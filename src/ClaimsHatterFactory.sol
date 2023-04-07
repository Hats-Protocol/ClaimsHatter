// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import { ClaimsHatter } from "src/ClaimsHatter.sol";
import { LibClone } from "solady/utils/LibClone.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";

contract ClaimsHatterFactory {
  /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
  //////////////////////////////////////////////////////////////*/

  /// @notice Emitted if attempting to deploy a ClaimsHatter for a hat `hatId` that already has a ClaimsHatter deployment
  error ClaimsHatterFactory_AlreadyDeployed(uint256 hatId);

  /*//////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /// @notice Emitted when a ClaimsHatter for `hatId` is deployed to address `instance`
  event ClaimsHatterDeployed(uint256 hatId, address instance);

  /*//////////////////////////////////////////////////////////////
                            CONSTANTS
  //////////////////////////////////////////////////////////////*/

  /// @notice The address of the ClaimsHatter implementation
  ClaimsHatter public immutable IMPLEMENTATION;
  /// @notice The address of Hats Protocol
  IHats public immutable HATS;
  /// @notice The version of this ClaimsHatterFactory
  string public version;

  /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /**
   * @param _implementation The address of the ClaimsHatter implementation
   * @param _hats The address of Hats Protocol
   */
  constructor(ClaimsHatter _implementation, IHats _hats, string memory _version) {
    IMPLEMENTATION = _implementation;
    HATS = _hats;
    version = _version;
  }

  /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Deploys a new ClaimsHatter instance for a given `_hatId` to a deterministic address, if not already deployed
   * @dev Anyone can deploy a ClaimsHatter instance for a hat.
   *  To make a hat claimable, the ClaimsHatter instance must wear an admin hat of `_hatId`, which only an admin of `_hatId` can do.
   * @param _hatId The hat for which to deploy a ClaimsHatter
   * @return _instance The address of the deployed ClaimsHatter instance
   */
  function createClaimsHatter(uint256 _hatId) public returns (ClaimsHatter _instance) {
    // check if ClaimsHatter has already been deployed for _hatId
    if (deployed(_hatId)) revert ClaimsHatterFactory_AlreadyDeployed(_hatId);
    // deploy the clone to a deterministic address, and log the deployment
    _instance = _createClaimsHatter(_hatId);
  }

  /**
   * @notice Predicts the address of a ClaimsHatter instance for a given hat
   * @param _hatId The hat for which to predict the ClaimsHatter instance address
   * @return The predicted address of the deployed instance
   */
  function getClaimsHatterAddress(uint256 _hatId) public view returns (address) {
    // prepare the unique inputs
    bytes memory args = _encodeArgs(_hatId);
    bytes32 _salt = _calculateSalt(args);
    // predict the address
    return _getClaimsHatterAddress(args, _salt);
  }

  /**
   * @notice Checks if a ClaimsHatter instance has already been deployed for a given hat
   * @param _hatId The hat for which to check for an existing instance
   * @return True if an instance has already been deployed for the given hat
   */
  function deployed(uint256 _hatId) public view returns (bool) {
    bytes memory args = _encodeArgs(_hatId);
    // predict the address
    address instance = _getClaimsHatterAddress(args, _calculateSalt(args));
    // check for contract code at the predicted address
    return instance.code.length > 0;
  }

  /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Deployes a new ClaimsHatter contract for a given hat, to a deterministic address
   * @param _hatId The hat for which to deploy a ClaimsHatter
   * @return _instance The address of the deployed ClaimsHatter
   */
  function _createClaimsHatter(uint256 _hatId) internal returns (ClaimsHatter _instance) {
    // encode the Hats contract adddress and _hatId to pass as immutable args when deploying the clone
    bytes memory args = _encodeArgs(_hatId);
    // calculate the determinstic address salt as the hash of the _hatId and the Hats Protocol address
    bytes32 _salt = _calculateSalt(args);
    // deploy the clone to the deterministic address
    _instance = ClaimsHatter(LibClone.cloneDeterministic(address(IMPLEMENTATION), args, _salt));
    // log the deployment
    emit ClaimsHatterDeployed(_hatId, address(_instance));
  }

  /**
   * @notice Predicts the address of a ClaimsHatter contract given the encoded arguments and salt
   * @param _arg The encoded arguments to pass to the clone as immutable storage
   * @param _salt The salt to use when deploying the clone
   * @return The predicted address of the deployed ClaimsHatter
   */
  function _getClaimsHatterAddress(bytes memory _arg, bytes32 _salt) internal view returns (address) {
    return LibClone.predictDeterministicAddress(address(IMPLEMENTATION), _arg, _salt, address(this));
  }

  /**
   * @notice Encodes the arguments to pass to the clone as immutable storage. The arguments are:
   *  - The address of this factory
   *  - The address of the Hats Protocol contract, `HATS`
   *  - The`_hatId`
   * @param _hatId The hat for which to deploy a ClaimsHatter
   * @return The encoded arguments
   */
  function _encodeArgs(uint256 _hatId) internal view returns (bytes memory) {
    return abi.encodePacked(address(this), HATS, _hatId);
  }

  /**
   * @notice Calculates the salt to use when deploying the clone. The (packed) inputs are:
   *  - The address of the Hats Protocol contract, `HATS` (passed as part of `_args`)
   *  - The`_hatId` (passed as part of `_args`)
   *  - The chain ID of the current network, to avoid confusion across networks since the same hat trees
   *    on different networks may have different wearers/admins
   * @dev
   * @param _args The encoded arguments to pass to the clone as immutable storage
   * @return The salt to use when deploying the clone
   */
  function _calculateSalt(bytes memory _args) internal view returns (bytes32) {
    return keccak256(abi.encodePacked(_args, block.chainid));
  }
}
