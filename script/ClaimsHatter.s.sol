// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { ClaimsHatter } from "src/ClaimsHatter.sol";

contract Deploy is Script {
  ClaimsHatter hatter;

  function prepare() public { }

  function run() public {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.rememberKey(privKey);

    vm.startBroadcast(deployer);
		// deploy the contract
    hatter = new ClaimsHatter();
    vm.stopBroadcast();
  }
}

// forge script script/Deploy.s.sol -f ethereum --broadcast --verify
