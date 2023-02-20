// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDDistributionToken  {

    error ZeroAmountDistribution(); // 0xc4d0b949
    error ZeroAddress(); // 0xd92e233d
    error UpdateSubscriptionUnits(); // 0xa13fbe2e
    error InvalidToken(); // 0xc1ab6dc1
    error IntOverflow(); // 0x44dddea2

    /**
     * @dev Distribute reward tokens to index subscribers
     * @notice Anyone can distribute tokens owned by this contract
     * @notice If not wanted behavior use _beforeDistribution and _afterDistribution hooks
     * @param amount Amount of tokens to distribute
     */
    function distribute(uint256 amount) external;

    /**
     * @dev Distribute reward tokens to index subscribers from account
     * @notice Anyone can distribute tokens
     * @notice If not wanted behavior use _beforeDistribution and _afterDistribution hooks
     * @param account Account to transfer tokens from
     * @param amount Amount of tokens to distribute
     */
    function distributeFrom(address account, uint256 amount) external;

    /**
     * @dev Mint new units of IDA subscription and ERC20 representation
     * @notice Only owner can mint new tokens
     * @param account Account to mint tokens for
     * @param amount Amount of tokens to mint
     */
    function mint(address account, uint256 amount) external;

    /**
     * @dev Burn units of IDA subscription and ERC20 representation
     * @notice Only owner can burn tokens
     * @param account Account to burn tokens for
     * @param amount Amount of tokens to burn
     */
    function burn(address account, uint256 amount) external;
}