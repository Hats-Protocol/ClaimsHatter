// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { ClaimsHatter } from "src/ClaimsHatter.sol";
import { ClaimsHatterFactory } from "src/ClaimsHatterFactory.sol";

contract DeployImplementation is Script {
  ClaimsHatter implementation;

  function prepare() public { }

  function run() public {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.rememberKey(privKey);

    vm.startBroadcast(deployer);
    // deploy the contract
    implementation = new ClaimsHatter();
    vm.stopBroadcast();
  }
  // forge script script/ClaimsHatter.s.sol:DeployImplementation -f mainnet --broadcast --verify
}

contract DeployFactory is Script {
  ClaimsHatterFactory factory;
  IHats public constant hats = IHats(0x9D2dfd6066d5935267291718E8AA16C8Ab729E9d); // v1.hatsprotocol.eth
  ClaimsHatter public implementation = ClaimsHatter(0x777262d3617713Aa9e6a3c6ce0d6F3c8Ef0E91c1);

  /// @dev For tests or other scripts to pass in the implementation before running
  function prepare(ClaimsHatter _implementation) public {
    implementation = _implementation;
  }

  function run() public {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.rememberKey(privKey);

    vm.startBroadcast(deployer);
    // deploy the contract
    factory = new ClaimsHatterFactory(implementation, hats);
    vm.stopBroadcast();
  }
  // forge script script/ClaimsHatter.s.sol:DeployFactory -f mainnet --broadcast --verify
}
