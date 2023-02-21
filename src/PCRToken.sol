// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { DDistributionToken, ISuperToken } from "./DDistributionToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    OptimisticRequester, OptimisticOracleV2Interface
} from "@uma/core/contracts/optimistic-oracle/implementation/OptimisticOracleV2.sol";

contract PCRToken is DDistributionToken, OptimisticRequester {

    event DistributionAmountChanged(uint256 amount);

    uint256 public distributionAmount = 1 ether; // default distribution amount

    bytes public ancillaryData;
    bytes32 public identifier = bytes32(abi.encodePacked("YES_OR_NO_QUERY")); // default query identifier
    OptimisticOracleV2Interface public optimisticOracle;
    IERC20 public oraclePaymentToken; // token to pay oracle

    uint256 internal _oracleRequestTimestamp;

    function initialize(
        string memory name,
        string memory symbol,
        address owner,
        ISuperToken rewardToken_,
        OptimisticOracleV2Interface optimisticOracle_,
        IERC20 oraclePaymentToken_
    ) public {
        super.initialize(name, symbol, owner, rewardToken_);
        if(address(optimisticOracle_) == address(0) ||
            address(oraclePaymentToken_) == address(0)
        ) revert ZeroAddress();
        optimisticOracle =  optimisticOracle_;
        oraclePaymentToken = oraclePaymentToken_;
    }

    // @dev all distribution must be verified by oracle
    function _beforeDistribution(address /*account*/, uint256 amount) internal override {
        require(amount == distributionAmount, "wrong amount");
        require(getOracleVerificationResult(), "Oracle verification failed");
    }

    // @dev change amount to be distributed
    function setDistributionAmount(uint256 amount) public onlyOwner {
        distributionAmount = amount;
        emit DistributionAmountChanged(amount);
    }

    /// @dev Request verification from the oracle if distribution should be paid out
    function requestOracleVerification() public returns (bool) {
        // TODO: implement oracle verification
        return true;
    }

    /// ? - Can resolved price be different from 1 ether or 0?
    /// @dev Retrieve the verification result, if the verification process has finished
    function getOracleVerificationResult() public returns (bool verified) {
        int256 resolvedPrice = optimisticOracle.settleAndGetPrice(identifier, _oracleRequestTimestamp, ancillaryData);
        if (1 ether == resolvedPrice) {
            verified = true;
        } else if (0 == resolvedPrice) {
            verified = false;
        }
        // TODO: handle 'uncertain'/'too early' responses
    }

    function priceSettled (
        bytes32 /*identifier*/,
        uint256 /*timestamp*/,
        bytes memory /*ancillaryData*/,
        int256 resolvedPrice
    ) external override {
    }

    function priceDisputed(
        bytes32 /*_identifier*/,
        uint256 /*_timestamp*/,
        bytes memory /*_ancillaryData*/,
        uint256 /*_refund*/
    ) external override {
    }

    function priceProposed(
        bytes32 /*_identifier*/,
        uint256 /*_timestamp*/,
        bytes memory /*_ancillaryData*/
    ) external override {
    }
}
