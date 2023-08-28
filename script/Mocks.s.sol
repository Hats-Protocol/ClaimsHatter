// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { AllEligibleMock } from "src/mocks/AllEligibleMock.sol";

contract DeployAllEligibleMock is Script {
  AllEligibleMock mock;

  function run() public {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.rememberKey(privKey);

    vm.startBroadcast(deployer);
    // deploy the contract
    mock = new AllEligibleMock();
    vm.stopBroadcast();
  }
  // forge script script/Mocks.s.sol:DeployAllEligibleMock -f mainnet --broadcast --verify
}
