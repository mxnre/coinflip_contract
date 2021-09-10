// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IUnifiedLiquidityPool.sol";
import "./interfaces/IGembitesProxy.sol";
import "./interfaces/IRandomNumberGenerator.sol";

/**
 * @title CoinFlip Contract
 */
contract CoinFlip is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;

    /// @notice Event emitted when gembites proxy set.
    event GembitesProxySet(address newProxyAddress);

    /// @notice Event emitted when contract is deployed.
    event CoinFlipDeployed();

    /// @notice Event emitted when bet is started.
    event BetStarted(
        address player,
        uint256 multiplier,
        uint256 number,
        uint256 amount
    );

    /// @notice Event emitted when bet is finished.
    event BetFinished(
        address player,
        uint256 paidAmount,
        bool betResult, // 0: Draw, 1: Win, 2: Loss
        BetInfo betInfo
    );

    IUnifiedLiquidityPool public ULP;
    IERC20 public GBTS;
    IGembitesProxy public GembitesProxy;
    IRandomNumberGenerator public RNG;

    uint256 public betGBTS;
    uint256 public paidGBTS;

    struct BetInfo {
        address player;
        uint256 number;
        uint256 amount;
        uint256 multiplier;
        uint256 expectedWinAmount;
        bytes32 requestId;
        uint256 gameNumber;
    }

    mapping(bytes32 => BetInfo) public requestToBet;

    modifier onlyRNG() {
        require(
            msg.sender == address(RNG),
            "CoinFlip: Caller is not the RandomNumberGenerator"
        );
        _;
    }

    /**
     * @dev Constructor function
     * @param _ULP Interface of ULP
     * @param _GBTS Interface of GBTS
     * @param _RNG Interface of RandomNumberGenerator
     */
    constructor(
        IUnifiedLiquidityPool _ULP,
        IERC20 _GBTS,
        IRandomNumberGenerator _RNG
    ) {
        ULP = _ULP;
        GBTS = _GBTS;
        RNG = _RNG;

        emit CoinFlipDeployed();
    }

    /**
     * @dev External function to start betting. This function can be called by players.
     * @param _number Number of player set
     * @param _amount Amount of player betted.
     */
    function bet(uint256 _number, uint256 _amount) external {
        uint256 expectedWinAmount;
        uint256 multiplier = 196;
        uint256 minBetAmount;
        uint256 maxWinAmount;

        minBetAmount = GembitesProxy.getMinBetAmount();
        maxWinAmount = GBTS.balanceOf(address(ULP)) / 100;

        require(1 <= _number && _number <= 2, "CoinFlip: Number out of range");

        expectedWinAmount = (multiplier * _amount) / 1000;

        require(
            _amount >= minBetAmount && expectedWinAmount <= maxWinAmount,
            "CoinFlip: Expected paid amount is out of range"
        );

        GBTS.safeTransferFrom(msg.sender, address(ULP), _amount);

        bytes32 requestId = RNG.requestRandomNumber();

        requestToBet[requestId] = BetInfo(
            msg.sender,
            _number,
            _amount,
            multiplier,
            expectedWinAmount,
            requestId,
            0
        );

        betGBTS += _amount;

        emit BetStarted(msg.sender, multiplier, _number, _amount);
    }

    /**
     * @dev External function for playing. This function can be called by only RandomNumberGenerator.
     * @param _requestId Request Id
     * @param _randomness Random Number
     */
    function play(bytes32 _requestId, uint256 _randomness) external onlyRNG {
        BetInfo storage betInfo = requestToBet[_requestId];

        uint256 expectedWinAmount = betInfo.expectedWinAmount;
        betInfo.gameNumber = (_randomness % 2) + 1;

        if (betInfo.gameNumber == betInfo.number) {
            ULP.sendPrize(msg.sender, expectedWinAmount);
            paidGBTS += expectedWinAmount;

            emit BetFinished(msg.sender, expectedWinAmount, true, betInfo);
        } else {
            emit BetFinished(msg.sender, 0, false, betInfo);
        }
    }

    /**
     * @dev External function to set gembites proxy. This function can be called by only owner.
     * @param _newProxyAddress New Gembites Proxy Address
     */
    function setGembitesProxy(address _newProxyAddress) external onlyOwner {
        require(
            _newProxyAddress.isContract() == true,
            "CoinFlip: Address is not contract address"
        );
        GembitesProxy = IGembitesProxy(_newProxyAddress);

        emit GembitesProxySet(_newProxyAddress);
    }
}
