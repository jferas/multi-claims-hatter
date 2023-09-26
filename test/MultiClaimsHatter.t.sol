// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2 } from "forge-std/Test.sol";
import {
  MultiClaimsHatter,
  MultiClaimsHatter_HatNotClaimable,
  MultiClaimsHatter_HatNotClaimableFor,
  MultiClaimsHatter_NotAdminOfHat,
  MultiClaimsHatter_NotExplicitlyEligible
} from "../src/MultiClaimsHatter.sol";
import { IHats, HatsModuleFactory, deployModuleInstance } from "hats-module/utils/DeployFunctions.sol";
import { DeployImplementation } from "../script/MultiClaimsHatter.s.sol";
import { TestEligibilityAlwaysEligible, TestEligibilityAlwaysNotEligible } from "./utils/TestModules.sol";

contract Setup is DeployImplementation, Test {
  uint256 public fork;
  // the block number where hats module factory was deployed on Goerli
  uint256 public constant BLOCK_NUMBER = 9_713_194;
  IHats public constant HATS = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137); // v1.hatsprotocol.eth
  HatsModuleFactory public constant FACTORY = HatsModuleFactory(0xfE661c01891172046feE16D3a57c3Cf456729efA);

  MultiClaimsHatter public instance;
  uint256 public tophat_x;
  uint256 public hat_x_1; // claims hatter hat
  uint256 public hat_x_1_1; // admined by the claims hatter
  uint256 public hat_x_1_1_1; // admined by the claims hatter
  uint256 public hat_x_1_1_1_1; // admined by the claims hatter
  uint256 public hat_x_2; // not admined by the claims hatter
  address public dao = makeAddr("dao");
  address public wearer = makeAddr("wearer");
  address public eligibility = makeAddr("eligibility");
  address public toggle = makeAddr("toggle");
  address public bot = makeAddr("bot");

  uint256[] public inputHats;
  address[] public inputWearers;

  function deployInstance(bytes memory initData) public returns (MultiClaimsHatter) {
    // deploy the instance
    return MultiClaimsHatter(deployModuleInstance(FACTORY, address(implementation), 0, "", initData));
  }

  function setUp() public virtual {
    // create and activate a fork, at BLOCK_NUMBER
    fork = vm.createSelectFork(vm.rpcUrl("goerli"), BLOCK_NUMBER);

    // deploy via the script
    DeployImplementation.prepare(false, "test"); // set last arg to true to log deployment
    DeployImplementation.run();

    // set up hats
    tophat_x = HATS.mintTopHat(dao, "tophat", "dao.eth/tophat");
    vm.startPrank(dao);
    hat_x_1 = HATS.createHat(tophat_x, "hat_x_1", 50, eligibility, toggle, true, "dao.eth/hat_x_1");
    hat_x_1_1 = HATS.createHat(hat_x_1, "hat_x_1_1", 50, eligibility, toggle, true, "dao.eth/hat_x_1_1");
    hat_x_1_1_1 = HATS.createHat(hat_x_1_1, "hat_x_1_1_1", 50, eligibility, toggle, true, "dao.eth/hat_x_1_1_1");
    hat_x_1_1_1_1 = HATS.createHat(hat_x_1_1_1, "hat_x_1_1_1_1", 50, eligibility, toggle, true, "dao.eth/hat_x_1_1_1_1");
    hat_x_2 = HATS.createHat(tophat_x, "hat_x_2", 50, eligibility, toggle, true, "dao.eth/hat_x_2");

    address alwaysEligibleModule = address(new TestEligibilityAlwaysEligible("test"));
    address alwaysNotEligibleModule = address(new TestEligibilityAlwaysNotEligible("test"));

    vm.startPrank(dao);
    HATS.changeHatEligibility(hat_x_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1, alwaysEligibleModule);
    HATS.changeHatEligibility(hat_x_1_1_1_1, alwaysNotEligibleModule);
    HATS.changeHatEligibility(hat_x_2, alwaysEligibleModule);
    vm.stopPrank();
  }
}

contract DeployInstanceWithoutInitialHats is Setup {
  function setUp() public virtual override {
    super.setUp();

    //bytes memory initData = initHats ? abi.encode(_hats, _claimTypes) : "";
    instance = MultiClaimsHatter(deployInstance(""));
    vm.prank(dao);
    HATS.mintHat(hat_x_1, address(instance));
  }
}

contract TestDeployInstanceWithoutInitialHats is DeployInstanceWithoutInitialHats {
  function test_hatExistsFunction() public {
    assertEq(instance.hatExists(hat_x_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1_1), true);
    assertEq(instance.hatExists(hat_x_2), true);
    assertEq(instance.hatExists(HATS.getNextId(hat_x_2)), false);
  }

  function test_wearsAdmin() public {
    assertEq(instance.wearsAdmin(hat_x_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_2), false);
    assertEq(instance.wearsAdmin(HATS.getNextId(hat_x_2)), false);
  }

  function test_hatIsClaimableFor() public {
    assertEq(instance.hatIsClaimableFor(hat_x_1_1), false);
    assertEq(instance.hatIsClaimableFor(hat_x_1_1_1), false);
    assertEq(instance.hatIsClaimableFor(hat_x_1_1_1_1), false);
    assertEq(instance.hatIsClaimableFor(hat_x_2), false);
    assertEq(instance.hatIsClaimableFor(HATS.getNextId(hat_x_2)), false);
  }

  function test_hatIsClaimableBy() public {
    assertEq(instance.hatIsClaimableBy(hat_x_1_1), false);
    assertEq(instance.hatIsClaimableBy(hat_x_1_1_1), false);
    assertEq(instance.hatIsClaimableBy(hat_x_1_1_1_1), false);
    assertEq(instance.hatIsClaimableBy(hat_x_2), false);
    assertEq(instance.hatIsClaimableBy(HATS.getNextId(hat_x_2)), false);
  }

  function test_accountCanClaim() public {
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1), false);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1), false);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.accountCanClaim(wearer, hat_x_2), false);
    assertEq(instance.accountCanClaim(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_canClaimForAccount() public {
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_2), false);
    assertEq(instance.canClaimForAccount(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_reverts_initialization() public {
    vm.expectRevert("Initializable: contract is already initialized");
    instance.setUp("");
  }

  function test_reverts_claimHat() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_1_1));
    vm.prank(wearer);
    instance.claimHat(hat_x_1_1);
  }

  function test_reverts_claimHatFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));
    vm.prank(wearer);
    instance.claimHatFor(hat_x_1_1, wearer);
  }

  function test_reverts_claimHats() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_1_1));

    inputHats = [hat_x_1_1];
    vm.prank(wearer);
    instance.claimHats(inputHats);
  }

  function test_reverts_claimHatsFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));

    inputHats = [hat_x_1_1];
    inputWearers = [wearer];
    vm.prank(wearer);
    instance.claimHatsFor(inputHats, inputWearers);
  }

  function test_reverts_setHatClaimabilityNotAdmin() public {
    vm.expectRevert();

    vm.prank(wearer);
    instance.setHatClaimability(hat_x_2, MultiClaimsHatter.ClaimType.Claimable);
  }
}

contract AddClaimableHats is DeployInstanceWithoutInitialHats {
  function setUp() public virtual override {
    super.setUp();

    vm.startPrank(dao);
    instance.setHatClaimability(hat_x_1_1, MultiClaimsHatter.ClaimType.Claimable);
    instance.setHatClaimability(hat_x_1_1_1, MultiClaimsHatter.ClaimType.ClaimableFor);
    instance.setHatClaimability(hat_x_1_1_1_1, MultiClaimsHatter.ClaimType.Claimable);
    vm.stopPrank();
  }
}

contract TestAddClaimableHats is AddClaimableHats {
  function test_hatExistsFunction() public {
    assertEq(instance.hatExists(hat_x_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1), true);
    assertEq(instance.hatExists(hat_x_1_1_1_1), true);
    assertEq(instance.hatExists(hat_x_2), true);
    assertEq(instance.hatExists(HATS.getNextId(hat_x_2)), false);
  }

  function test_wearsAdmin() public {
    assertEq(instance.wearsAdmin(hat_x_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_1_1_1_1), true);
    assertEq(instance.wearsAdmin(hat_x_2), false);
    assertEq(instance.wearsAdmin(HATS.getNextId(hat_x_2)), false);
  }

  function test_hatIsClaimableFor() public {
    assertEq(instance.hatIsClaimableFor(hat_x_1_1), false);
    assertEq(instance.hatIsClaimableFor(hat_x_1_1_1), true);
    assertEq(instance.hatIsClaimableFor(hat_x_1_1_1_1), false);
    assertEq(instance.hatIsClaimableFor(hat_x_2), false);
    assertEq(instance.hatIsClaimableFor(HATS.getNextId(hat_x_2)), false);
  }

  function test_hatIsClaimableBy() public {
    assertEq(instance.hatIsClaimableBy(hat_x_1_1), true);
    assertEq(instance.hatIsClaimableBy(hat_x_1_1_1), true);
    assertEq(instance.hatIsClaimableBy(hat_x_1_1_1_1), true);
    assertEq(instance.hatIsClaimableBy(hat_x_2), false);
    assertEq(instance.hatIsClaimableBy(HATS.getNextId(hat_x_2)), false);
  }

  function test_accountCanClaim() public {
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1), true);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1), true);
    assertEq(instance.accountCanClaim(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.accountCanClaim(wearer, hat_x_2), false);
    assertEq(instance.accountCanClaim(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_canClaimForAccount() public {
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1), true);
    assertEq(instance.canClaimForAccount(wearer, hat_x_1_1_1_1), false);
    assertEq(instance.canClaimForAccount(wearer, hat_x_2), false);
    assertEq(instance.canClaimForAccount(wearer, HATS.getNextId(hat_x_2)), false);
  }

  function test_reverts_claimHat() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_2));
    vm.prank(wearer);
    instance.claimHat(hat_x_2);
  }

  function test_reverts_claimHatFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));
    vm.prank(wearer);
    instance.claimHatFor(hat_x_1_1, wearer);
  }

  function test_reverts_claimHats() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimable.selector, hat_x_2));

    inputHats = [hat_x_2];
    vm.prank(wearer);
    instance.claimHats(inputHats);
  }

  function test_reverts_claimHatsFor() public {
    vm.expectRevert(abi.encodePacked(MultiClaimsHatter_HatNotClaimableFor.selector, hat_x_1_1));

    inputHats = [hat_x_1_1];
    inputWearers = [wearer];
    vm.prank(wearer);
    instance.claimHatsFor(inputHats, inputWearers);
  }
}

contract ClaimHat is AddClaimableHats {
  function setUp() public virtual override {
    super.setUp();

    vm.prank(wearer);
    instance.claimHat(hat_x_1_1);
    vm.prank(bot);
    instance.claimHatFor(hat_x_1_1_1, wearer);
  }
}

contract TestClaimHat is ClaimHat {
  function test_hatsClaimed() public {
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1), true);
    assertEq(HATS.isWearerOfHat(wearer, hat_x_1_1_1), true);
  }

  function test_reverts_claimHatNotEligible() public {
    vm.expectRevert(
      abi.encodePacked(MultiClaimsHatter_NotExplicitlyEligible.selector, uint256(uint160(wearer)), hat_x_1_1_1_1)
    );
    vm.prank(wearer);
    instance.claimHat(hat_x_1_1_1_1);
  }

  function test_reverts_claimHatsNotEligible() public {
    vm.expectRevert(
      abi.encodePacked(MultiClaimsHatter_NotExplicitlyEligible.selector, uint256(uint160(wearer)), hat_x_1_1_1_1)
    );

    inputHats = [hat_x_1_1_1_1];
    vm.prank(wearer);
    instance.claimHats(inputHats);
  }
}