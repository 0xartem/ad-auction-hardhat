// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IAdAuction} from "./IAdAuction.sol";
import {PriceOracle} from "./PriceOracle.sol";

/** @title A contract for ad auction
 *  @author artem0x
 *  @notice This contract is to sell anyh ad to a highest bidder
 *  @dev Use bidOnAd and then topUp as needed
 */
contract AdAuction is IAdAuction {
    using PriceOracle for uint256;

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
        uint256 blockUsdBid;
        uint256 timeLeft;
        string name;
        string imageUrl;
        string text;
        bool withdrew;
    }

    address public immutable owner;

    uint256 public immutable startAuctionTime;
    uint256 public immutable endAuctionTime;
    uint256 public immutable minimumBlockUsdBid;

    uint256 public ownerBalanceAvailable;
    address public highestBidderAddr;
    mapping(address => Payer) public addressToPayer;

    AggregatorV3Interface public priceFeed;

    event OnBid(
        address indexed payer,
        uint256 indexed blockUsdBid,
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
        uint256 _minimumBlockUsdBid,
        address _priceFeedAddress
    ) {
        owner = msg.sender;

        if (_endAuctionTime <= _startAuctionTime)
            revert AdAuction__InvalidAuctionPeriod();

        startAuctionTime = _startAuctionTime;
        endAuctionTime = _endAuctionTime;
        minimumBlockUsdBid = _minimumBlockUsdBid;
        //TODO: Multiply when needs calculations: minimumBlockUsdBid = _minimumBlockUsdBid * 1e18;

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
     *  @param _blockUsdBid the amount you want to pay for 1 block (12 sec) in USD
     */
    function bidOnAd(
        string calldata _name,
        string calldata _imageUrl,
        string calldata _text,
        uint256 _blockUsdBid
    ) external payable {
        if (block.timestamp < startAuctionTime)
            revert AdAuction__AuctionHasntStartedYet();
        if (block.timestamp > endAuctionTime) revert AdAuction__AuctionIsOver();

        if (_blockUsdBid < minimumBlockUsdBid)
            revert AdAuction__BidIsLowerThanMinimum();
        if (_blockUsdBid <= addressToPayer[highestBidderAddr].blockUsdBid)
            revert AdAuction__HigherBidIsAvailable();
        if (msg.value.convertEthToUsd(priceFeed) < _blockUsdBid)
            revert AdAuction__PaidAmountIsLowerThanBid();

        Payer storage payer = addressToPayer[msg.sender];
        payer.ethBalance += msg.value;
        payer.blockUsdBid = _blockUsdBid;
        payer.name = _name;
        payer.imageUrl = _imageUrl;
        payer.text = _text;
        payer.withdrew = false;

        highestBidderAddr = msg.sender;

        uint256 usdBalance = payer.ethBalance.convertEthToUsd(priceFeed);
        uint256 timeLeft = (usdBalance / _blockUsdBid) * 12; // 12 secs per block
        payer.timeLeft = timeLeft;

        emit OnBid(
            msg.sender,
            _blockUsdBid,
            payer.ethBalance,
            msg.value,
            timeLeft
        );
    }

    function topUp() public payable {
        if (block.timestamp < startAuctionTime)
            revert AdAuction__AuctionHasntStartedYet();

        Payer storage payer = addressToPayer[msg.sender];
        if (payer.blockUsdBid == 0) revert AdAuction__NoSuchPayer();
        if (msg.value.convertEthToUsd(priceFeed) < payer.blockUsdBid)
            revert AdAuction__PaidAmountIsLowerThanBid();

        payer.ethBalance += msg.value;
        payer.withdrew = false;

        uint256 usdBalance = payer.ethBalance.convertEthToUsd(priceFeed);
        uint256 timeLeft = (usdBalance / payer.blockUsdBid) * 12; // 12 secs per block
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
        if (payer.blockUsdBid == 0) revert AdAuction__NoSuchPayer();
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
        if (winner.blockUsdBid == 0) revert AdAuction__NoWinnerInAuction();

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
        Payer storage winner = addressToPayer[highestBidderAddr];
        if (winner.blockUsdBid == 0) revert AdAuction__NoWinnerInAuction();
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
            uint256 paidInUsd = blocksUsed * winner.blockUsdBid;
            uint256 oldUsdBalance = winner.ethBalance.convertEthToUsd(
                priceFeed
            );
            uint256 newUsdBalance = oldUsdBalance - paidInUsd;

            winner.timeLeft = winner.timeLeft - timeUsed;

            winner.ethBalance = newUsdBalance.convertUsdToEth(priceFeed);
            uint256 paidInEth = paidInUsd.convertUsdToEth(priceFeed);
            winner.ethUsed += paidInEth;
            ownerBalanceAvailable += paidInEth;
        }
    }
}
