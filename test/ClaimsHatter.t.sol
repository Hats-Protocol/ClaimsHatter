// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2 } from "forge-std/Test.sol";
import { ClaimsHatter } from "src/ClaimsHatter.sol";
import { IHats } from "hats-protocol/Interfaces/IHats.sol";
import { HatsErrors } from "hats-protocol/Interfaces/HatsErrors.sol";
import { LibClone } from "solady/utils/LibClone.sol";
import { Deploy } from "../script/ClaimsHatter.s.sol";
import { HatsModuleFactory, deployModuleInstance } from "lib/hats-module/src/utils/DeployFunctions.sol";

contract ClaimsHatterTestSetup is Test, Deploy {
  uint256 public fork;
  uint256 public topHat1 = 0x0000000100000000000000000000000000000000000000000000000000000000;
  uint256 public hat1 = 0x0000000100010000000000000000000000000000000000000000000000000000;
  bytes32 maxBytes32 = bytes32(type(uint256).max);
  bytes largeBytes = abi.encodePacked("this is a fairly large bytes object");
  string public constant VERSION = "this is a test";
  IHats public constant hats = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137); // v1.hatsprotocol.eth
  HatsModuleFactory constant factory = HatsModuleFactory(0xEcb86bAB1E2494Dd3C4bcE4d0528842E226A869c);

  function setUp() public virtual {
    // create and activate a goerli fork, at the block number where hats module factory was deployed
    fork = vm.createSelectFork(vm.rpcUrl("goerli"), 9_550_399);

    // deploy the implementation contract
    Deploy.prepare(VERSION, false); // set verbose to true to log the deployed address
    Deploy.run();
  }
}

contract ClaimsHatterTest is ClaimsHatterTestSetup {
  ClaimsHatter hatter;
  address public admin1;
  address public claimer1;
  address public eligibility;
  address public bot;

  uint256 public hatterHat1;
  uint256 public claimerHat1;

  error ClaimsHatter_NotClaimableFor();
  error ClaimsHatter_NotHatAdmin();
  error ClaimsHatter_NotExplicitlyEligible();

  event ClaimingForChanged(uint256 _hatId, bool _claimableFor);
  // ERC1155 Transfer event
  event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount);

  function setUp() public virtual override {
    super.setUp();
    // set up addresses
    admin1 = makeAddr("admin1");
    claimer1 = makeAddr("claimer1");
    eligibility = makeAddr("eligibility");
    bot = makeAddr("bot");

    vm.startPrank(admin1);
    // mint top hat to admin1
    topHat1 = hats.mintTopHat(admin1, "Top hat", "");
    // create hatterHat1
    hatterHat1 = hats.createHat(topHat1, "hatterHat1", 2, address(1), address(1), true, "");
    // derive id of claimHat1
    claimerHat1 = hats.buildHatId(hatterHat1, 1);
    vm.stopPrank();
  }

  function deployClaimsHatter(bool claimableFor) public {
    bytes memory initData = abi.encode(claimableFor);
    hatter = ClaimsHatter(deployModuleInstance(factory, address(implementation), claimerHat1, "", initData));
  }

  /// @notice Mocks a call to the eligibility contract for `wearer` and `hat` that returns `eligible` and `standing`
  function mockEligibityCall(address wearer, uint256 hat, bool eligible, bool standing) public {
    bytes memory data = abi.encodeWithSignature("getWearerStatus(address,uint256)", wearer, hat);
    vm.mockCall(eligibility, data, abi.encode(eligible, standing));
  }
}

contract HatCreatedTest is ClaimsHatterTest {
  function setUp() public virtual override {
    super.setUp();
    super.deployClaimsHatter(false);
    // create claimerHat1 with good eligibility module
    vm.prank(admin1);
    claimerHat1 = hats.createHat(hatterHat1, "claimerHat1", 2, eligibility, address(1), true, "");
  }
}

contract HatCreatedClaimableForTest is ClaimsHatterTest {
  function setUp() public virtual override {
    super.setUp();
    super.deployClaimsHatter(true);
    // create claimerHat1 with good eligibility module
    vm.prank(admin1);
    claimerHat1 = hats.createHat(hatterHat1, "claimerHat1", 2, eligibility, address(1), true, "");
  }
}

contract ClaimsHatterHarness is ClaimsHatter {
  constructor() ClaimsHatter("this is a test harness") { }

  function mint(address _wearer) public {
    _mint(_wearer);
  }

  function isExplicitlyEligible(address _wearer) public view returns (bool) {
    return _isExplicitlyEligible(_wearer);
  }

  function checkOnlyAdmin() public view onlyAdmin returns (bool) {
    return true;
  }
}

contract InternalTest is HatCreatedTest {
  ClaimsHatterHarness harnessImplementation;
  ClaimsHatterHarness harness;

  function setUp() public virtual override {
    super.setUp();
    // deploy harness implementation
    harnessImplementation = new ClaimsHatterHarness();
    // deploy harness proxy
    harness = ClaimsHatterHarness(
      LibClone.cloneDeterministic(
        address(harnessImplementation), abi.encodePacked(address(this), hats, claimerHat1), bytes32("salt")
      )
    );
    // mint hatterHat1 to harness contract
    vm.prank(admin1);
    hats.mintHat(hatterHat1, address(harness));
  }
}

contract _isExplicitlyEligible is InternalTest {
  function test_eligibleWearer_isExplicitlyEligible() public {
    mockEligibityCall(claimer1, claimerHat1, true, true);
    assertTrue(harness.isExplicitlyEligible(claimer1));
  }

  function test_ineligibleWearer_isNotEligible() public {
    mockEligibityCall(claimer1, claimerHat1, false, true);
    assertFalse(harness.isExplicitlyEligible(claimer1));
  }

  function test_eligibleWearerInBadStanding_isNotEligible() public {
    mockEligibityCall(claimer1, claimerHat1, true, false);
    assertFalse(harness.isExplicitlyEligible(claimer1));
  }

  function test_humanisticEligibility_isNotExplicitlyEligible() public {
    assertFalse(harness.isExplicitlyEligible(claimer1));
  }
}

contract _Mint is InternalTest {
  function test_forEligible_mintSucceeds() public {
    mockEligibityCall(claimer1, claimerHat1, true, true);
    vm.prank(claimer1);
    harness.mint(claimer1);
    assertTrue(hats.isWearerOfHat(claimer1, claimerHat1));
  }

  function test_forIneligible_mintFails() public {
    mockEligibityCall(claimer1, claimerHat1, false, true);
    vm.prank(claimer1);
    vm.expectRevert(ClaimsHatter_NotExplicitlyEligible.selector);
    harness.mint(claimer1);
    assertFalse(hats.isWearerOfHat(claimer1, claimerHat1));
  }
}

contract _onlyAdmin is InternalTest {
  function test_forAdmin_returnsTrue() public {
    vm.prank(admin1);
    assertTrue(harness.checkOnlyAdmin());
  }

  function test_forNonAdmin_reverts() public {
    vm.prank(claimer1); // claimer does not wear the admin hat (top hat)
    vm.expectRevert(ClaimsHatter_NotHatAdmin.selector);
    harness.checkOnlyAdmin();
  }
}

contract DeployTest is ClaimsHatterTest {
  function setUp() public virtual override {
    super.setUp();
    super.deployClaimsHatter(false);
  }

  function test_deploy() public {
    assertEq(hatter.version(), VERSION);
    assertEq(hatter.hatId(), claimerHat1);
    assertEq(address(hatter.HATS()), address(hats));
  }
}

contract EnableClaimingFor is HatCreatedTest {
  function test_adminCall_succeeds() public {
    vm.expectEmit(true, true, true, true);
    emit ClaimingForChanged(claimerHat1, true);
    vm.prank(admin1);
    hatter.enableClaimingFor();
    // should be false since hatter does not yet wear hatterHat1
    assertFalse(hatter.claimableFor());
    // mint hatterHat1 to hatter
    vm.prank(admin1);
    hats.mintHat(hatterHat1, address(hatter));
    // now it should be true
    assertTrue(hatter.claimableFor());
  }

  function test_nonAdminCall_reverts() public {
    vm.expectRevert(ClaimsHatter_NotHatAdmin.selector);
    vm.prank(claimer1);
    hatter.enableClaimingFor();
  }
}

contract DisableClaimingFor is HatCreatedTest {
  function setUp() public override {
    super.setUp();
    // mint hatterHat1 to hatter
    vm.prank(admin1);
    hats.mintHat(hatterHat1, address(hatter));
    // enable claiming for
    vm.prank(admin1);
    hatter.enableClaimingFor();
  }

  function test_adminCall_succeeds() public {
    // claimableFor starts out as true
    assertTrue(hatter.claimableFor());
    // now we disable it
    vm.expectEmit(true, true, true, true);
    emit ClaimingForChanged(claimerHat1, false);
    vm.prank(admin1);
    hatter.disableClaimingFor();
    // now it should be false
    assertFalse(hatter.claimableFor());
  }

  function test_nonAdminCall_reverts() public {
    vm.expectRevert(ClaimsHatter_NotHatAdmin.selector);
    vm.prank(claimer1);
    hatter.disableClaimingFor();
  }
}

contract Claim is HatCreatedTest {
  function setUp() public override {
    super.setUp();
    // mint hatterHat1 to hatter
    vm.prank(admin1);
    hats.mintHat(hatterHat1, address(hatter));
  }

  function test_eligibleWearer_canClaim() public {
    // mock explicitly eligibility for claimer1
    mockEligibityCall(claimer1, claimerHat1, true, true);
    // attempt the claim, expecting a transfer event when minted
    vm.prank(claimer1);
    vm.expectEmit(true, true, true, true);
    emit TransferSingle(address(hatter), address(0), address(claimer1), claimerHat1, 1);
    hatter.claimHat();
    // claimer1 should now wear claimerHat1
    assertTrue(hats.isWearerOfHat(claimer1, claimerHat1));
  }

  function test_ineligibleWearer_cannotClaim() public {
    vm.prank(claimer1);
    vm.expectRevert(ClaimsHatter_NotExplicitlyEligible.selector);
    hatter.claimHat();
  }
}

contract MakeClaimableAndClaimFor is HatCreatedTest {
  function setUp() public override {
    super.setUp();
    // mint hatterHat1 to hatter
    vm.prank(admin1);
    hats.mintHat(hatterHat1, address(hatter));
    // enable claiming for
    vm.prank(admin1);
    hatter.enableClaimingFor();
  }

  function test_eligibleWearer_canBeClaimedFor() public {
    // mock explicitly eligibility for claimer1
    mockEligibityCall(claimer1, claimerHat1, true, true);
    // attempt the claim from another address, expecting a transfer event when minted
    vm.prank(bot);
    vm.expectEmit(true, true, true, true);
    emit TransferSingle(address(hatter), address(0), address(claimer1), claimerHat1, 1);
    hatter.claimHatFor(claimer1);
    // claimer1 should now wear claimerHat1
    assertTrue(hats.isWearerOfHat(claimer1, claimerHat1));
  }

  function test_ineligibleWearer_cannotBeClaimedFor() public {
    // attempt the claim from another address, expecting a revert
    vm.prank(bot);
    vm.expectRevert(ClaimsHatter_NotExplicitlyEligible.selector);
    hatter.claimHatFor(claimer1);

    // this should also happen if the wearer is explicitly ineligible
    // mock explicit ineligibility for claimer1
    mockEligibityCall(claimer1, claimerHat1, false, true);
    // attempt the claim from another address, expecting a revert
    vm.prank(bot);
    vm.expectRevert(ClaimsHatter_NotExplicitlyEligible.selector);
    hatter.claimHatFor(claimer1);
  }

  function test_eligibleWearer_notClaimableFor_cannotBeClaimedFor() public {
    // disable claiming for
    vm.prank(admin1);
    hatter.disableClaimingFor();
    // mock explicitly eligibility for claimer1
    mockEligibityCall(claimer1, claimerHat1, true, true);
    // attempt the claim from another address, expecting a revert
    vm.prank(bot);
    vm.expectRevert(ClaimsHatter_NotClaimableFor.selector);
    hatter.claimHatFor(claimer1);
  }
}

contract ClaimableFromInitClaimFor is HatCreatedClaimableForTest {
  function setUp() public override {
    super.setUp();
    // mint hatterHat1 to hatter
    vm.prank(admin1);
    hats.mintHat(hatterHat1, address(hatter));
    // enable claiming for
    vm.prank(admin1);
  }

  function test_eligibleWearer_canBeClaimedFor() public {
    // mock explicitly eligibility for claimer1
    mockEligibityCall(claimer1, claimerHat1, true, true);
    // attempt the claim from another address, expecting a transfer event when minted
    vm.prank(bot);
    vm.expectEmit(true, true, true, true);
    emit TransferSingle(address(hatter), address(0), address(claimer1), claimerHat1, 1);
    hatter.claimHatFor(claimer1);
    // claimer1 should now wear claimerHat1
    assertTrue(hats.isWearerOfHat(claimer1, claimerHat1));
  }

  function test_ineligibleWearer_cannotBeClaimedFor() public {
    // attempt the claim from another address, expecting a revert
    vm.prank(bot);
    vm.expectRevert(ClaimsHatter_NotExplicitlyEligible.selector);
    hatter.claimHatFor(claimer1);

    // this should also happen if the wearer is explicitly ineligible
    // mock explicit ineligibility for claimer1
    mockEligibityCall(claimer1, claimerHat1, false, true);
    // attempt the claim from another address, expecting a revert
    vm.prank(bot);
    vm.expectRevert(ClaimsHatter_NotExplicitlyEligible.selector);
    hatter.claimHatFor(claimer1);
  }

  function test_eligibleWearer_notClaimableFor_cannotBeClaimedFor() public {
    // disable claiming for
    vm.prank(admin1);
    hatter.disableClaimingFor();
    // mock explicitly eligibility for claimer1
    mockEligibityCall(claimer1, claimerHat1, true, true);
    // attempt the claim from another address, expecting a revert
    vm.prank(bot);
    vm.expectRevert(ClaimsHatter_NotClaimableFor.selector);
    hatter.claimHatFor(claimer1);
  }
}

contract ViewFunctions is ClaimsHatterTest {
  function setUp() public virtual override {
    super.setUp();
    super.deployClaimsHatter(false);
  }

  function test_wearsAdmin() public {
    // claimable starts out as false since hatter does not yet wear hatterHat1
    assertFalse(hatter.wearsAdmin());
    // mint hatterHat1 to hatter
    vm.prank(admin1);
    hats.mintHat(hatterHat1, address(hatter));
    // now it should be true
    assertTrue(hatter.wearsAdmin());
    // now hatter gets rid of hatterHat1
    vm.prank(address(hatter));
    hats.renounceHat(hatterHat1);
    // now it should be false again
    assertFalse(hatter.wearsAdmin());
  }

  function test_hatExists() public {
    // hatExists starts out as false since claimerHat1 doesn't exist yet
    assertFalse(hatter.hatExists());
    // create claimerHat1
    vm.prank(admin1);
    hats.createHat(hatterHat1, "claimerHat1", 2, eligibility, address(1), true, "");
    // now it should be true
    assertTrue(hatter.hatExists());
  }

  function test_claimable() public {
    // claimable starts out as false since hatter does not yet wear hatterHat1
    assertFalse(hatter.claimable());
    // mint hatterHat1 to hatter
    vm.prank(admin1);
    hats.mintHat(hatterHat1, address(hatter));
    // should still be false since claimerHat1 doesn't exist yet
    assertFalse(hatter.claimable());
    // create claimerHat1
    vm.prank(admin1);
    hats.createHat(hatterHat1, "claimerHat1", 2, eligibility, address(1), true, "");
    // now it should be true
    assertTrue(hatter.claimable());
    // now hatter gets rid of hatterHat1
    vm.prank(address(hatter));
    hats.renounceHat(hatterHat1);
    // now it should be false again
    assertFalse(hatter.claimable());
  }

  function test_claimableFor() public {
    // claimableFor starts out as false
    assertFalse(hatter.claimableFor());
    // now we enable it
    vm.prank(admin1);
    hatter.enableClaimingFor();
    // should still be false since claimerHat1 doesn't exist yet
    assertFalse(hatter.claimable());
    // create claimerHat1
    vm.prank(admin1);
    hats.createHat(hatterHat1, "claimerHat1", 2, eligibility, address(1), true, "");
    // should still be false since hatter does not yet wear hatterHat1
    assertFalse(hatter.claimableFor());
    // mint hatterHat1 to hatter
    vm.prank(admin1);
    hats.mintHat(hatterHat1, address(hatter));
    // now it should be true
    assertTrue(hatter.claimableFor());
    // now we disable it
    vm.prank(admin1);
    hatter.disableClaimingFor();
    // now it should be false again
    assertFalse(hatter.claimableFor());
  }

  function test_claimableByWearer() public {
    // claimableBy starts out as false
    assertFalse(hatter.claimableBy(claimer1));
    // we need to ...
    // a) create the claimerHat1 hat
    vm.prank(admin1);
    hats.createHat(hatterHat1, "claimerHat1", 2, eligibility, address(1), true, "");
    assertFalse(hatter.claimableBy(claimer1));
    // b) mint hatterHat1 to hatter
    vm.prank(admin1);
    hats.mintHat(hatterHat1, address(hatter));
    assertFalse(hatter.claimableBy(claimer1));
    // c) and ensure that claimer1 is eligible for claimerHat1
    mockEligibityCall(claimer1, claimerHat1, true, true);
    // now it should be true
    assertTrue(hatter.claimableBy(claimer1));
  }

  function test_claimableForWearer() public {
    // claimableBy starts out as false
    assertFalse(hatter.claimableFor(claimer1));
    // we need to ...
    // a) create the claimerHat1 hat
    vm.prank(admin1);
    hats.createHat(hatterHat1, "claimerHat1", 2, eligibility, address(1), true, "");
    assertFalse(hatter.claimableFor(claimer1));
    // b) mint hatterHat1 to hatter
    vm.prank(admin1);
    hats.mintHat(hatterHat1, address(hatter));
    assertFalse(hatter.claimableFor(claimer1));
    // c) and ensure that claimer1 is eligible for claimerHat1
    mockEligibityCall(claimer1, claimerHat1, true, true);
    assertFalse(hatter.claimableFor(claimer1));
    // d) and enable claiming for
    vm.prank(admin1);

    hatter.enableClaimingFor();
    // now it should be true
    assertTrue(hatter.claimableFor(claimer1));
  }
}
