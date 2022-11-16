// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import {IAdAuction} from "./IAdAuction.sol";
import {PriceOracle} from "./PriceOracle.sol";
import "hardhat/console.sol";

/** @title A contract for ad auction
 *  @author artem0x
 *  @notice This contract is to sell any ad to a highest bidder
 *  @dev Use bidOnAd to bid on the ad board and then topUp as needed
 */
contract AdAuction is IAdAuction, AutomationCompatibleInterface {
    using PriceOracle for uint256;

    /// Type declarations
    error AdAuction__NotOwner();

    error AdAuction__InvalidAuctionPeriod();
    error AdAuction__AuctionHasntStartedYet();
    error AdAuction__AuctionIsOver();
    error AdAuction__AuctionIsNotOverYet();

    error AdAuction__InvalidMinimumBidRequirement();
    error AdAuction__BidIsLowerThanMinimum();
    error AdAuction__HigherBidIsAvailable();
    error AdAuction__PaidAmountIsLowerThanBid();

    error AdAuction__NoSuchPayer();
    error AdAuction__HighestBidderCantWithdraw();
    error AdAuction__BidderAlreadyWithdrew();
    error AdAuction__BidWithdrawalFailed();

    error AdAuction__AdAuctionBalanceIsTooLow();
    error AdAuction__OwnerWithdrawalFailed();

    error AdAuction__NoWinnerInAuction();
    error AdAuction__NoFundsToCharge();

    error AdAuction__UpkeepNotNeeded(
        uint256 currentBalance,
        address highestBidder
    );

    struct Payer {
        uint256 ethBalance;
        uint256 ethUsed;
        uint256 blockBid;
        uint256 timeLeft;
        string name;
        string imageUrl;
        string text;
        bool withdrew;
    }

    /// State variables
    address public immutable owner;

    uint256 public immutable startAuctionTime;
    uint256 public immutable endAuctionTime;
    uint256 public immutable minimumBlockBid;
    uint256 public immutable chargeInterval;
    uint256 private lastTimestamp;

    uint256 public ownerBalanceAvailable;
    address public highestBidderAddr;
    mapping(address => Payer) public addressToPayer;

    AggregatorV3Interface public priceFeed;

    /// Events
    event OnBid(
        address indexed payer,
        uint256 indexed blockBid,
        uint256 indexed ethBalance,
        uint256 ethPaid,
        uint256 timeLeft
    );

    event OnTopUp(
        address indexed payer,
        uint256 indexed ethBalance,
        uint256 ethPaid,
        uint256 timeLeft
    );

    event BidWithdrawn(address indexed payer, uint256 indexed ethAmount);
    event BalanceWithdrawn(address indexed payer, uint256 indexed ethAmount);

    /// Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) revert AdAuction__NotOwner();
        _;
    }

    /// Functions
    constructor(
        uint256 _startAuctionTime,
        uint256 _endAuctionTime,
        uint256 _minimumBlockBid,
        uint256 _chargeInterval,
        address _priceFeedAddress
    ) {
        owner = msg.sender;

        if (_endAuctionTime <= _startAuctionTime) {
            revert AdAuction__InvalidAuctionPeriod();
        }

        startAuctionTime = _startAuctionTime;
        endAuctionTime = _endAuctionTime;
        minimumBlockBid = _minimumBlockBid;
        chargeInterval = _chargeInterval;
        lastTimestamp = _endAuctionTime;

        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    receive() external payable {
        topUp();
    }

    fallback() external payable {
        topUp();
    }

    /** @notice This functions places a bid along with the amount
     *  @dev You can use it to provide or update the bid
     *  @param _name is a name of the ad
     *  @param _imageUrl is a url to a resource that will be displayed in the ad
     *  @param _text is the text that will be displayed along with the resource
     *  @param _blockBid the amount you want to pay for 1 block (12 sec) in in wei
     */
    function bidOnAd(
        string calldata _name,
        string calldata _imageUrl,
        string calldata _text,
        uint256 _blockBid
    ) external payable {
        if (block.timestamp < startAuctionTime)
            revert AdAuction__AuctionHasntStartedYet();
        if (block.timestamp > endAuctionTime) revert AdAuction__AuctionIsOver();

        if (_blockBid < minimumBlockBid)
            revert AdAuction__BidIsLowerThanMinimum();
        if (_blockBid <= addressToPayer[highestBidderAddr].blockBid)
            revert AdAuction__HigherBidIsAvailable();

        if (msg.value < _blockBid) revert AdAuction__PaidAmountIsLowerThanBid();

        uint256 usdBid = _blockBid.convertEthToUsd(priceFeed);
        console.log("USD bid %i", usdBid);

        Payer storage payer = addressToPayer[msg.sender];
        payer.ethBalance += msg.value;
        payer.blockBid = _blockBid;
        payer.name = _name;
        payer.imageUrl = _imageUrl;
        payer.text = _text;
        payer.withdrew = false;
        highestBidderAddr = msg.sender;

        console.log("ETH balance %i", payer.ethBalance);
        uint256 timeLeft = (payer.ethBalance / _blockBid) * 12; // 12 secs per block
        payer.timeLeft = timeLeft;

        emit OnBid(
            msg.sender,
            _blockBid,
            payer.ethBalance,
            msg.value,
            timeLeft
        );
    }

    function topUp() public payable {
        if (block.timestamp < startAuctionTime)
            revert AdAuction__AuctionHasntStartedYet();

        Payer storage payer = addressToPayer[msg.sender];
        if (payer.blockBid == 0) revert AdAuction__NoSuchPayer();
        if (msg.value < payer.blockBid)
            revert AdAuction__PaidAmountIsLowerThanBid();

        payer.ethBalance += msg.value;
        payer.withdrew = false;

        uint256 timeLeft = (payer.ethBalance / payer.blockBid) * 12; // 12 secs per block
        payer.timeLeft = timeLeft;

        emit OnTopUp(msg.sender, payer.ethBalance, msg.value, timeLeft);
    }

    // todo: the next bidder will be used if the first one runs out of funds
    // todo: implement logic so you can withdraw not all but a part depending on how long your ad was up
    // todo: automatically execute selecting a winner (once or ongoing)

    function withdrawBid(address receiver) external {
        if (block.timestamp <= endAuctionTime)
            revert AdAuction__AuctionIsNotOverYet();
        if (msg.sender == highestBidderAddr)
            revert AdAuction__HighestBidderCantWithdraw();

        Payer memory payer = addressToPayer[msg.sender];
        if (payer.blockBid == 0) revert AdAuction__NoSuchPayer();
        if (payer.withdrew) revert AdAuction__BidderAlreadyWithdrew();

        addressToPayer[msg.sender].withdrew = true;

        (bool res, ) = receiver.call{value: payer.ethBalance}(""); // todo: convert to payable?
        if (!res) revert AdAuction__BidWithdrawalFailed();

        emit BidWithdrawn(receiver, payer.ethBalance);
    }

    function withdraw(address receiver) external onlyOwner {
        if (block.timestamp <= endAuctionTime)
            revert AdAuction__AuctionIsNotOverYet();

        Payer storage winner = addressToPayer[highestBidderAddr];
        if (winner.blockBid == 0) revert AdAuction__NoWinnerInAuction();

        if (winner.ethBalance > 0) {
            chargeForAdCalc(winner);
        }

        if (address(this).balance < ownerBalanceAvailable)
            revert AdAuction__AdAuctionBalanceIsTooLow(); // assert ?
        uint256 withdrawableBalance = ownerBalanceAvailable;
        ownerBalanceAvailable = 0;

        (bool res, ) = receiver.call{value: withdrawableBalance}("");
        if (!res) revert AdAuction__OwnerWithdrawalFailed();

        emit BalanceWithdrawn(receiver, withdrawableBalance);
    }

    function chargeForAd() external {
        if (block.timestamp <= endAuctionTime)
            revert AdAuction__AuctionIsNotOverYet();

        if (highestBidderAddr == address(0))
            revert AdAuction__NoWinnerInAuction();
        chargeForAdCalc(addressToPayer[highestBidderAddr]);
    }

    /**
     * @dev This function is called by the Chainlink Automation nodes
     * they will trigger the performUpkeep if the following conditions are true
     * 1. The endAuctionTime has to pass the current timestamp
     * It means the auction is over and need to be moved to the AUCTION_CLOSED state
     * 2 If the auction is closed, then we need to check if the inverval passed to charge the payer if
     * 3 The winner is available
     * 4 The balance of the contract is > 0
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool hasWinner = (highestBidderAddr != address(0));
        bool hasBalance = address(this).balance > 0;
        bool isAuctionClosed = (block.timestamp > endAuctionTime);
        bool intervalPassed = false;
        if (isAuctionClosed) {
            intervalPassed = ((block.timestamp - lastTimestamp) >
                chargeInterval);
        }
        upkeepNeeded = (hasWinner &&
            hasBalance &&
            isAuctionClosed &&
            intervalPassed);
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert AdAuction__UpkeepNotNeeded(
                address(this).balance,
                highestBidderAddr
            );
        }

        chargeForAdCalc(addressToPayer[highestBidderAddr]);
    }

    function getCurrentMinimumBid() public view returns (uint256) {
        if (highestBidderAddr == address(0)) {
            return minimumBlockBid;
        }
        return addressToPayer[highestBidderAddr].blockBid;
    }

    function chargeForAdCalc(Payer storage winner) internal {
        if (winner.ethBalance == 0) revert AdAuction__NoFundsToCharge();
        // assert(winner.timeLeft == 0); // Should never happen

        uint256 timeUsed = block.timestamp - endAuctionTime;

        if (timeUsed >= winner.timeLeft) {
            winner.ethUsed += winner.ethBalance;
            ownerBalanceAvailable += winner.ethBalance;
            winner.ethBalance = 0;
            winner.timeLeft = 0;
        } else {
            uint256 blocksUsed = timeUsed / 12;
            uint256 paidInEth = blocksUsed * winner.blockBid;

            winner.timeLeft = winner.timeLeft - timeUsed;
            winner.ethBalance = winner.ethBalance - paidInEth;
            winner.ethUsed += paidInEth;
            ownerBalanceAvailable += paidInEth;
        }
        // Reset the timestamp so we know when the last time charge happened
        lastTimestamp = block.timestamp;
    }
}
