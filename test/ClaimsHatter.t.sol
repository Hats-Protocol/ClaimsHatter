// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/Test.sol";
import { Deploy } from "script/ClaimsHatter.s.sol";
import { ClaimsHatter } from "src/ClaimsHatter.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { HatsErrors } from "hats-protocol/Interfaces/HatsErrors.sol";

contract ClaimsHatterTest is Test, Deploy {
  uint256 public fork;
  IHats hats = IHats(0x850f3384829D7bab6224D141AFeD9A559d745E3D); // v1.hatsprotocol.eth

  address public admin1;
  address public admin2;
  address public claimer1;
  address public claimer2;
  address public eligibility;

  uint256 public topHat2;
  uint256 public topHat3;
  uint256 public hatterHat1;
  uint256 public hatterHat2;
  uint256 public claimerHat1;
  uint256 public claimerHat2;

  function setUp() public virtual {
    // create fork of mainnet at the block Hats Protocol v1 was deployed;
    // Top hat 1 was also created in this block, so our first top hat will be 2
    fork = vm.createFork(vm.envString("ETHEREUM_RPC"), 16_856_978);
    // use the fork (Luke)
    vm.selectFork(fork);
    // deploy ClaimsHatter
    Deploy.run();
    // set up addresses
    admin1 = makeAddr("admin1");
    admin2 = makeAddr("admin2");
    claimer1 = makeAddr("claimer1");
    claimer2 = makeAddr("claimer2");
    eligibility = makeAddr("eligibility");

    // mint top hat 2 to admin1
    topHat2 = hats.mintTopHat(admin1, "Top hat 2", "");

    vm.startPrank(admin1);
    // create hatterHat1
    hatterHat1 = hats.createHat(topHat2, "adminHat1", 2, address(1), address(1), true, "");
    // mint hatterHat1 to hatter
    hats.mintHat(hatterHat1, address(hatter));
    // create claimerHat1 with good eligibility module
    claimerHat1 = hats.createHat(hatterHat1, "claimerHat1", 2, eligibility, address(1), true, "");
    // create claimerHat2, with bad eligibility module
    claimerHat2 = hats.createHat(hatterHat1, "claimerHat2", 2, address(1), address(1), true, "");
    vm.stopPrank();
  }

  /// @notice Mocks a call to the eligibility contract for `wearer` and `hat` that returns `eligible` and `standing`
  function mockEligibityCall(address wearer, uint256 hat, bool eligible, bool standing) public {
    bytes memory data = abi.encodeWithSignature("getWearerStatus(address,uint256)", wearer, hat);
    vm.mockCall(eligibility, data, abi.encode(eligible, standing));
  }
}

contract ClaimsHatterHarness is ClaimsHatter {
  function mint(uint256 _hatId, address _wearer) public {
    _mint(_hatId, _wearer);
  }

  function isEligible(uint256 _hatId, address _wearer) public view returns (bool) {
    return _isEligible(_hatId, _wearer);
  }
}

contract InternalTest is ClaimsHatterTest {
  ClaimsHatterHarness harness;

  function setUp() public virtual override {
    super.setUp();
    // deploy harness
    harness = new ClaimsHatterHarness();
    // mint hatterHat1 to harness contract
    vm.prank(admin1);
    hats.mintHat(hatterHat1, address(harness));
  }
}

contract _IsEligible is InternalTest {
  function test_eligibleWearer_isEligible() public {
    mockEligibityCall(claimer1, claimerHat1, true, true);
    assertTrue(harness.isEligible(claimerHat1, claimer1));
  }

  function test_ineligibleWearer_isNotEligible() public {
    mockEligibityCall(claimer1, claimerHat1, false, true);
    assertFalse(harness.isEligible(claimerHat1, claimer1));
  }

  function test_eligibleWearerInBadStanding_isNotEligible() public {
    mockEligibityCall(claimer1, claimerHat1, true, false);
    assertFalse(harness.isEligible(claimerHat1, claimer1));
  }

  function test_humanisticEligibility_isNotEligible() public {
    assertFalse(harness.isEligible(claimerHat2, claimer1));
  }
}

contract _Mint is InternalTest {
  function test_forEligible_mintSucceeds() public {
    mockEligibityCall(claimer1, claimerHat1, true, true);
    vm.prank(claimer1);
    harness.mint(claimerHat1, claimer1);
    assertTrue(hats.isWearerOfHat(claimer1, claimerHat1));
  }

  function test_forIneligible_mintFails() public {
    mockEligibityCall(claimer1, claimerHat1, false, true);
    vm.prank(claimer1);
    vm.expectRevert(HatsErrors.NotEligible.selector);
    harness.mint(claimerHat1, claimer1);
    assertFalse(hats.isWearerOfHat(claimer1, claimerHat1));
  }
}

contract MakeClaimable is ClaimsHatterTest {
  function setUp() public override {
    super.setUp();
    // mock claimable hat and admin
  }

  function test_makeClaimable() public {
    // TODO
  }
}

contract MakeClaimableFor is ClaimsHatterTest {
  function setUp() public override {
    super.setUp();
    // mock claimable hat and admin
  }

  function test_makeClaimableFor() public {
    // TODO
  }
}

contract Claim is ClaimsHatterTest {
  function setUp() public override {
    super.setUp();
    // mock claimable hat and admin
  }

  function test_claim() public {
    // TODO
  }
}

contract ClaimFor is ClaimsHatterTest {
  function setUp() public override {
    super.setUp();
    // mock claimable hat and admin
  }

  function testClaimFor() public {
    // TODO
  }
}

contract IsClaimable is ClaimsHatterTest {
  function setUp() public override {
    super.setUp();
    // mock claimable hat and admin
  }

  function test_isClaimable() public {
    // TODO
  }
}

contract IsClaimableFor is ClaimsHatterTest {
  function setUp() public override {
    super.setUp();
    // mock claimable hat and admin
  }

  function test_isClaimableFor() public {
    // TODO
  }
}
