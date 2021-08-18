// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

/**
 * @title GembitesProxy interface
 */

interface IGembitesProxy {
    /**
     * @dev External function to return min bet amount.
     */
    function getMinBetAmount() external view returns (uint256);

    /**
     * @dev External function to set min bet amount. This function can be called by only owner.
     * @param _newMinBetAmount New min bet amount
     */
    function setMinBetAmount(uint256 _newMinBetAmount) external;
}
