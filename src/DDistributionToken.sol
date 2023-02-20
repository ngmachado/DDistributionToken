// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IDDistributionToken} from "./interfaces/IDDistributionToken.sol";

contract DDistributionToken is IDDistributionToken, ERC20Upgradeable, OwnableUpgradeable {

	using SuperTokenV1Library for ISuperToken;

	uint32 public constant INDEX_ID = 0;

	ISuperToken public rewardToken;

	function initialize(
		string memory name,
		string memory symbol,
		address owner,
		ISuperToken rewardToken_
	) public initializer {
		if(address(rewardToken_) == address(0)) revert ZeroAddress();
		__ERC20_init(name, symbol);
		__Ownable_init();
		rewardToken = rewardToken_;
		rewardToken_.createIndex(INDEX_ID);
		transferOwnership(owner);
	}

	/// @dev DDTokens are have always 0 decimals 1 token = 1 IDA unit
	function decimals() public view virtual override returns (uint8) {
		return 0;
	}

	/// @dev IDDistribution.distribute implementation
	function distribute(uint256 amount) public {
		_beforeDistribution(msg.sender, amount);
		uint256 actualAmount = _revertIfZeroAmountDistribution(amount);
		rewardToken.distribute(INDEX_ID, actualAmount);
		_afterDistribution(msg.sender, amount);
	}

	/// @dev IDDistribution.distributeFrom implementation
	function distributeFrom(address account, uint256 amount) public {
		_beforeDistribution(account, amount);
		if(account == address(0)) revert ZeroAddress();
		uint256 actualAmount = _revertIfZeroAmountDistribution(amount);
		rewardToken.transferFrom(account, address(this), actualAmount);
		rewardToken.distribute(INDEX_ID, actualAmount);
		_afterDistribution(account, amount);
	}

	/// @dev IDDistribution.mint implementation
	function mint(address account, uint256 amount) public onlyOwner {
		if(account == address(0)) revert ZeroAddress();
		uint128 amountUint128 = _toUint128(amount);
		uint128 accountUnits = _toUint128(balanceOf(account));
		_mint(account, amount);
		rewardToken.updateSubscriptionUnits(INDEX_ID, account, accountUnits + amountUint128);
	}

	function _beforeDistribution(address account, uint256 amount) internal virtual {
	}

	function _afterDistribution(address account, uint256 amount) internal virtual {
	}

	/// @dev IDDistribution.burn implementation
	function burn(address account, uint256 amount) public onlyOwner {
		if(account == address(0)) revert ZeroAddress();
		uint128 amountUint128 = _toUint128(amount);
		uint128 accountUnits = _toUint128(balanceOf(account));
		_burn(account, amount);
		rewardToken.updateSubscriptionUnits(INDEX_ID, account, accountUnits - amountUint128);
	}

	function _transfer(address from, address to, uint256 amount) internal override {
		uint128 amountUint128 = _toUint128(amount);
		uint128 senderUnits = _toUint128(balanceOf(from));
		uint128 receiverUnits = _toUint128(balanceOf(to));
		ERC20Upgradeable._transfer(from, to, amount);
		rewardToken.updateSubscriptionUnits(INDEX_ID, from, senderUnits - amountUint128);
		rewardToken.updateSubscriptionUnits(INDEX_ID, to, receiverUnits + amountUint128);
	}

	/// @dev Convert uint256 to uint128 and revert if overflow
	function _toUint128(uint256 x) private pure returns (uint128) {
		if(x > type(uint128).max) revert IntOverflow();
		return uint128(x);
	}

	/// @dev Revert if distribution amount is 0
	function _revertIfZeroAmountDistribution(uint256 amount) internal view returns (uint256 actualAmount) {
		(actualAmount, ) = rewardToken.calculateDistribution(address(this), INDEX_ID, amount);
		if(actualAmount == 0) revert ZeroAmountDistribution();
	}

}
