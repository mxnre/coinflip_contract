// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IUnifiedLiquidityPool.sol";
import "./interfaces/IGembitesProxy.sol";

/**
 * @title CoinFlip Contract
 */
contract CoinFlip is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;

    /// @notice Event emitted only on construction.
    event CoinFlipDeployed();

    /// @notice Event emitted when player start the betting.
    event BetStarted(
        address indexed player,
        uint256 number,
        uint256 amount,
        bytes32 batchID
    );

    /// @notice Event emitted when player finish the betting.
    event BetFinished(address indexed player, bool won);

    /// @notice Event emitted when game number generated.
    event VerifiedGameNumber(uint256 vrf, uint256 gameNumber, uint256 gameId);

    /// @notice Event emitted when gembites proxy set.
    event GembitesProxySet(address newProxyAddress);

    IUnifiedLiquidityPool public ULP;
    IERC20 public GBTS;
    IGembitesProxy public GembitesProxy;

    uint256 constant RTP = 98;
    uint256 public gameId;

    uint256 public betGBTS;
    uint256 public paidGBTS;

    uint256 public vrfCost = 10000; // 0.0001 Link

    struct BetInfo {
        uint256 number;
        uint256 amount;
        uint256 potentialWinnings;
        bytes32 requestId;
    }

    mapping(address => BetInfo) private betInfos;

    /**
     * @dev Constructor function
     * @param _ULP Interface of ULP
     * @param _GBTS Interface of GBTS
     * @param _GembitesProxy Interface of GembitesProxy
     * @param _gameID Id of Game
     */
    constructor(
        IUnifiedLiquidityPool _ULP,
        IERC20 _GBTS,
        IGembitesProxy _GembitesProxy,
        uint256 _gameID
    ) {
        ULP = _ULP;
        GBTS = _GBTS;
        GembitesProxy = _GembitesProxy;
        gameId = _gameID;

        emit CoinFlipDeployed();
    }

    /**
     * @dev External function to start betting. This function can be called by players.
     * @param _number Number of player set
     * @param _amount Amount of player betted.
     */
    function bet(uint256 _number, uint256 _amount) external {
        require(betInfos[msg.sender].number == 0, "CoinFlip: Already betted");
        require(1 <= _number && _number <= 2, "CoinFlip: Number out of range");
        require(
            GBTS.balanceOf(msg.sender) >= _amount,
            "CoinFlip: Caller has not enough balance"
        );

        uint256 winnings = (_amount * 196) / 100;

        require(
            checkBetAmount(winnings, _amount),
            "CoinFlip: Bet amount is out of range"
        );

        GBTS.safeTransferFrom(msg.sender, address(ULP), _amount);

        betInfos[msg.sender].number = _number;
        betInfos[msg.sender].amount = _amount;
        betInfos[msg.sender].potentialWinnings = winnings;
        betInfos[msg.sender].requestId = ULP.requestRandomNumber();
        betGBTS += _amount;

        emit BetStarted(
            msg.sender,
            _number,
            _amount,
            betInfos[msg.sender].requestId
        );
    }

    /**
     * @dev External function to calculate betting win or lose.
     */
    function play() external nonReentrant {
        require(
            betInfos[msg.sender].number != 0,
            "CoinFlip: Cannot play without betting"
        );

        uint256 randomNumber = ULP.getVerifiedRandomNumber(
            betInfos[msg.sender].requestId
        );

        uint256 gameNumber = (uint256(
            keccak256(abi.encode(randomNumber, address(msg.sender), gameId))
        ) % 2) + 1;

        emit VerifiedGameNumber(randomNumber, gameNumber, gameId);

        BetInfo storage betInfo = betInfos[msg.sender];

        if (gameNumber == betInfo.number) {
            betInfos[msg.sender].number = 0;
            ULP.sendPrize(msg.sender, betInfo.potentialWinnings);

            paidGBTS += betInfo.potentialWinnings;

            emit BetFinished(msg.sender, true);
        } else {
            betInfos[msg.sender].number = 0;

            emit BetFinished(msg.sender, false);
        }
    }

    /**
     * @dev Internal function to check current bet amount is enough to bet.
     * @param _winnings Amount of GBTS user received if he wins.
     * @param _betAmount Bet Amount
     */
    function checkBetAmount(uint256 _winnings, uint256 _betAmount)
        internal
        view
        returns (bool)
    {
        return (GBTS.balanceOf(address(ULP)) / 100 >= _winnings &&
            _betAmount >= GembitesProxy.getMinBetAmount());
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
