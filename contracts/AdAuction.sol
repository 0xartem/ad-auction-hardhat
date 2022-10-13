// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IAdAuction} from "./IAdAuction.sol";
import {PriceOracle} from "./PriceOracle.sol";
import "hardhat/console.sol";

/** @title A contract for ad auction
 *  @author artem0x
 *  @notice This contract is to sell anyh ad to a highest bidder
 *  @dev Use bidOnAd and then topUp as needed
 */
contract AdAuction is IAdAuction {
    using PriceOracle for uint256;

    enum AdAuctionState {
        AUCTION_OPEN,
        AUCTION_CLOSED
    }

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

    AdAuctionState public state;
    address public immutable owner;

    uint256 public immutable startAuctionTime;
    uint256 public immutable endAuctionTime;
    uint256 public immutable minimumBlockBid;

    uint256 public ownerBalanceAvailable;
    address public highestBidderAddr;
    mapping(address => Payer) public addressToPayer;

    AggregatorV3Interface public priceFeed;

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

    modifier onlyOwner() {
        if (msg.sender != owner) revert AdAuction__NotOwner();
        _;
    }

    constructor(
        uint256 _startAuctionTime,
        uint256 _endAuctionTime,
        uint256 _minimumBlockBid,
        address _priceFeedAddress
    ) {
        owner = msg.sender;

        if (
            _endAuctionTime <= _startAuctionTime ||
            block.timestamp >= _endAuctionTime
        ) {
            revert AdAuction__InvalidAuctionPeriod();
        }

        if (block.timestamp >= _startAuctionTime) {
            state = AdAuctionState.AUCTION_OPEN;
        } else {
            state = AdAuctionState.AUCTION_CLOSED;
        }

        startAuctionTime = _startAuctionTime;
        endAuctionTime = _endAuctionTime;
        minimumBlockBid = _minimumBlockBid;

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

        state = AdAuctionState.AUCTION_OPEN;

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

        state = AdAuctionState.AUCTION_OPEN;

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

        state = AdAuctionState.AUCTION_CLOSED;

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

        state = AdAuctionState.AUCTION_CLOSED;

        Payer storage winner = addressToPayer[highestBidderAddr];
        if (winner.blockBid == 0) revert AdAuction__NoWinnerInAuction();

        if (winner.ethBalance > 0) {
            chargeForAdCalc(winner);
        }

        if (address(this).balance < ownerBalanceAvailable)
            revert AdAuction__AdAuctionBalanceIsTooLow(); // assert ?
        ownerBalanceAvailable = 0;

        (bool res, ) = receiver.call{value: ownerBalanceAvailable}("");
        if (!res) revert AdAuction__OwnerWithdrawalFailed();

        emit BalanceWithdrawn(receiver, ownerBalanceAvailable);
    }

    function chargeForAd() external {
        if (block.timestamp <= endAuctionTime)
            revert AdAuction__AuctionIsNotOverYet();

        state = AdAuctionState.AUCTION_CLOSED;

        Payer storage winner = addressToPayer[highestBidderAddr];
        if (winner.blockBid == 0) revert AdAuction__NoWinnerInAuction();
        chargeForAdCalc(winner);
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
    }
}
