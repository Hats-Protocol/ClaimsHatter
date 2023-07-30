// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console2 } from "forge-std/Script.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { ClaimsHatter } from "src/ClaimsHatter.sol";
import { ClaimsHatterFactory } from "src/ClaimsHatterFactory.sol";

contract DeployFactory is Script {
  ClaimsHatterFactory factory;
  ClaimsHatter implementation;
  IHats public constant hats = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137); // v1.hatsprotocol.eth
  bytes32 internal constant SALT = bytes32(abi.encode(0x4a75)); // ~ H(4) A(a) T(7) S(5)

  // variables with defaul values
  string public version = "0.4.0"; // increment with each deploy
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
    // deploy the contract
    factory = new ClaimsHatterFactory{ salt: SALT }(implementation, hats, version);
    vm.stopBroadcast();

    if (verbose) {
      console2.log("implementation", address(implementation));
      console2.log("factory", address(factory));
    }
  }
  // forge script script/ClaimsHatter.s.sol:DeployFactory -f mainnet --broadcast --verify
}
