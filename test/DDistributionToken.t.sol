pragma solidity ^0.8.0;

import "forge-std/Console.sol";
import { ISuperToken, IERC20 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { ISuperApp } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperApp.sol";
import { SuperfluidFrameworkDeployer, SuperfluidTester, Superfluid, IDAv1Library, InstantDistributionAgreementV1 } from "./utils/SuperfluidTester.sol";
import { ERC1820RegistryCompiled } from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import { DDistributionToken } from "./../src/DDistributionToken.sol";

contract DDistributionTokenTest is SuperfluidTester {

	using IDAv1Library for IDAv1Library.InitData;

	SuperfluidFrameworkDeployer internal immutable sfDeployer;
	SuperfluidFrameworkDeployer.Framework internal sf;
	Superfluid host;
	InstantDistributionAgreementV1 ida;
	IDAv1Library.InitData internal idaV1Lib;

	DDistributionToken ddToken;
	ISuperToken SuperTokenReward;
	IERC20 ERC20Reward;
	uint32 constant INDEX_ID = 0;

	constructor() SuperfluidTester(3) {
		vm.startPrank(admin);
		vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);
		sfDeployer = new SuperfluidFrameworkDeployer();
		sf = sfDeployer.getFramework();
		host = sf.host;
		ida = sf.ida;
		idaV1Lib = IDAv1Library.InitData(host,ida);
		vm.stopPrank();
	}

	function setUp() public virtual {
		(token1, superToken1) = sfDeployer.deployWrapperSuperToken("Reward", "RW", 18, type(uint256).max);
		for (uint32 i = 0; i < N_TESTERS; ++i) {
			token1.mint(TEST_ACCOUNTS[i], INIT_TOKEN_BALANCE);
			vm.startPrank(TEST_ACCOUNTS[i]);
			token1.approve(address(superToken1), INIT_SUPER_TOKEN_BALANCE);
			superToken1.upgrade(INIT_SUPER_TOKEN_BALANCE);
			vm.stopPrank();
		}
		deployDDToken();
	}

	function _mintAndUpgradeToSuperToken(address account, uint256 amount) public {
			token1.mint(account, amount);
			vm.startPrank(account);
			token1.approve(address(superToken1), amount);
			superToken1.upgrade(amount);
			vm.stopPrank();
	}

	function _checkSubscription(address account, bool exist, bool approved, uint128 units, uint256 pendingDistribution) internal {
		(bool _exist, bool _approved, uint128 _units, uint256 _pendingDistribution) =
		idaV1Lib.getSubscription(superToken1, address(ddToken), 0, account);
		assertEq(_exist, exist);
		assertEq(_approved, approved);
		assertEq(_units, units);
		assertEq(_pendingDistribution, pendingDistribution);
	}

	// to be invariant later
	function _DDBalanceIsEqualToIDAUnits() public {
		for (uint32 i = 0; i < N_TESTERS; ++i) {
			(bool exist, , uint128 units, ) =
				idaV1Lib.getSubscription(superToken1, address(ddToken), INDEX_ID, TEST_ACCOUNTS[i]);
			if(exist) {
				assertEq(ddToken.balanceOf(TEST_ACCOUNTS[i]), units);
			}
		}
	}

	function deployDDToken() public {
		vm.startPrank(admin);
		ddToken = new DDistributionToken();
		ddToken.initialize(
			"DDToken",
			"DD",
			admin,
			superToken1
		);
		vm.stopPrank();
	}

	function testDeployDDToken() public {
		assertEq(ddToken.name(), "DDToken");
		assertEq(ddToken.symbol(), "DD");
		assertEq(ddToken.owner(), admin);
		assertEq(address(ddToken.rewardToken()), address(superToken1));
		assertEq(ddToken.owner(), admin);
		assertEq(ddToken.decimals(), 0);
	}

	function testMint() public {
		vm.startPrank(admin);
		ddToken.mint(alice, 100);
		vm.stopPrank();
		assertEq(ddToken.balanceOf(alice), 100);
		_DDBalanceIsEqualToIDAUnits();
	}

	function test_RevertIf_Mint_notOwner() public {
		vm.startPrank(alice);
		vm.expectRevert("Ownable: caller is not the owner");
		ddToken.mint(alice, 100);
		vm.stopPrank();
	}

	function testDistribute() public {
		vm.startPrank(admin);
		ddToken.mint(alice, 100);
		superToken1.transfer(address(ddToken), 100);
		ddToken.distribute(100);
		vm.stopPrank();
		assertEq(ddToken.balanceOf(alice), 100);
		assertEq(ddToken.totalSupply(), 100);
		// test subscription amount
		_checkSubscription(alice, true, false, 100, 100);
		_DDBalanceIsEqualToIDAUnits();
	}

	function testTransferTokenAndDistribute() public {
		vm.startPrank(admin);
		superToken1.approve(address(ddToken), type(uint256).max);
		ddToken.mint(alice, 100);
		ddToken.distributeFrom(admin, 100);
		vm.stopPrank();
		assertEq(ddToken.balanceOf(alice), 100);
		assertEq(ddToken.totalSupply(), 100);
		// test subscription amount
		_checkSubscription(alice, true, false, 100, 100);
		_DDBalanceIsEqualToIDAUnits();
	}

	// should revert if amount bigger than 128bits
	function test_RevertIf_MintAmountBiggerThanUnitsType() public {
		vm.startPrank(admin);
		superToken1.approve(address(ddToken), type(uint256).max);
		vm.expectRevert(0x44dddea2);
		ddToken.mint(alice, uint256(type(uint128).max) + 1);
		vm.stopPrank();
	}

	// should revert if transferred amount bigger than 128bits
	function test_RevertIf_TransferAmountBiggerThanUnitsType() public {
		vm.startPrank(admin);
		superToken1.approve(address(ddToken), type(uint256).max);
		ddToken.mint(alice, type(uint128).max);
		vm.stopPrank();
		_checkSubscription(alice, true, false, type(uint128).max, 0);
		vm.startPrank(alice);
		vm.expectRevert(0x44dddea2);
		ddToken.transfer(bob, uint256(type(uint128).max) + 1);
	}

	function testZeroDistribution() public {
		vm.startPrank(admin);
		ddToken.mint(alice, 100);
		superToken1.transfer(address(ddToken), 100);
		vm.expectRevert(0xc4d0b949);
		ddToken.distribute(0);
	}
}