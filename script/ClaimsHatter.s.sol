// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { ClaimsHatter } from "src/ClaimsHatter.sol";
import { HatsModuleFactory, deployModuleInstance } from "lib/hats-module/src/utils/DeployFunctions.sol";

contract Deploy is Script {
  ClaimsHatter implementation;
  bytes32 internal constant SALT = bytes32(abi.encode(0x4a75)); // ~ H(4) A(a) T(7) S(5)

  // variables with defaul values
  string public version = "0.6.0"; // increment with each deploy
  bool verbose = true;

  /// @notice Overrides default values
  function prepare(string memory _version, bool _verbose) public {
    version = _version;
    verbose = _verbose;
  }

  function run() public {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.rememberKey(privKey);

    vm.startBroadcast(deployer);
    // deploy the implementation
    implementation = new ClaimsHatter{ salt: SALT }(version);
    vm.stopBroadcast();

    if (verbose) {
      console2.log("implementation", address(implementation));
    }
  }
  // forge script script/ClaimsHatter.s.sol:Deploy -f mainnet --broadcast --verify
}
