// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IAdAuction} from "./IAdAuction.sol";
import {PriceOracle} from "./PriceOracle.sol";

contract AdAuction is IAdAuction {
    using PriceOracle for uint256;

    error NotOwner();

    error InvalidAuctionPeriod();
    error AuctionHasntStartedYet();
    error AuctionIsOver();
    error AuctionIsNotOverYet();

    error InvalidMinimumBidRequirement();
    error BidIsLowerThanMinimum();
    error HigherBidIsAvailable();
    error PaidAmountIsLowerThanBid();

    error NoSuchPayer();
    error HighestBidderCantWithdraw();
    error BidderAlreadyWithdrew();
    error BidWithdrawalFailed();

    error AdAuctionBalanceIsTooLow();
    error OwnerWithdrawalFailed();

    error NoWinnerInAuction();
    error NoFundsToCharge();

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

    uint256 public constant MINIMUM_BID_REQUIREMENT = 0;
    uint256 public immutable startAuctionTime;
    uint256 public immutable endAuctionTime;
    uint256 public immutable minimumBlockUsdBid;

    uint256 public ownerBalanceAvailable;
    address public highestBidderAddr;
    mapping(address => Payer) public addressToPayer;

    constructor(
        uint256 _startAuctionTime,
        uint256 _endAuctionTime,
        uint256 _minimumBlockUsdBid
    ) {
        owner = msg.sender;

        if (_endAuctionTime <= _startAuctionTime) revert InvalidAuctionPeriod();
        if (_minimumBlockUsdBid < MINIMUM_BID_REQUIREMENT)
            revert InvalidMinimumBidRequirement();

        startAuctionTime = _startAuctionTime;
        endAuctionTime = _endAuctionTime;
        minimumBlockUsdBid = _minimumBlockUsdBid;
        //TODO: Multiply when needs calculations: minimumBlockUsdBid = _minimumBlockUsdBid * 1e18;
    }

    function bidOnAd(
        string calldata _name,
        string calldata _imageUrl,
        string calldata _text,
        uint256 _blockUsdBid
    ) external payable {
        if (block.timestamp < startAuctionTime) revert AuctionHasntStartedYet();
        if (block.timestamp > endAuctionTime) revert AuctionIsOver();

        if (_blockUsdBid <= addressToPayer[highestBidderAddr].blockUsdBid)
            revert HigherBidIsAvailable();
        if (_blockUsdBid < minimumBlockUsdBid) revert BidIsLowerThanMinimum();
        if (msg.value.convertEthToUsd() < _blockUsdBid)
            revert PaidAmountIsLowerThanBid();

        Payer storage payer = addressToPayer[msg.sender];
        payer.ethBalance += msg.value;
        payer.blockUsdBid = _blockUsdBid;
        payer.name = _name;
        payer.imageUrl = _imageUrl;
        payer.text = _text;
        payer.withdrew = false;

        highestBidderAddr = msg.sender;

        uint256 usdBalance = payer.ethBalance.convertEthToUsd();
        uint256 timeLeft = (usdBalance / _blockUsdBid) * 12; // 12 secs per block
        payer.timeLeft = timeLeft;
    }

    function topUp() public payable {
        if (block.timestamp < startAuctionTime) revert AuctionHasntStartedYet();

        Payer storage payer = addressToPayer[msg.sender];
        if (payer.blockUsdBid == 0) revert NoSuchPayer();
        if (msg.value.convertEthToUsd() < payer.blockUsdBid)
            revert PaidAmountIsLowerThanBid();

        payer.ethBalance += msg.value;
        payer.withdrew = false;

        uint256 usdBalance = payer.ethBalance.convertEthToUsd();
        uint256 timeLeft = (usdBalance / payer.blockUsdBid) * 12; // 12 secs per block
        payer.timeLeft = timeLeft;
    }

    // todo: the next bidder will be used if the first one runs out of funds
    // todo: implement logic so you can withdraw not all but a part depending on how long your ad was up

    function withdrawBid(address receiver) external {
        if (block.timestamp <= endAuctionTime) revert AuctionIsNotOverYet();
        if (msg.sender == highestBidderAddr) revert HighestBidderCantWithdraw();

        Payer memory payer = addressToPayer[msg.sender];
        if (payer.blockUsdBid == 0) revert NoSuchPayer();
        if (payer.withdrew) revert BidderAlreadyWithdrew();

        addressToPayer[msg.sender].withdrew = true;

        (bool res, ) = receiver.call{value: payer.ethBalance}(""); // convert to payable?
        if (!res) revert BidWithdrawalFailed();
    }

    function withdraw(address receiver) external onlyOwner {
        if (block.timestamp <= endAuctionTime) revert AuctionIsNotOverYet();

        Payer storage winner = addressToPayer[highestBidderAddr];
        if (winner.blockUsdBid == 0) revert NoWinnerInAuction();

        if (winner.ethBalance > 0) {
            chargeForAdCalc(winner);
        }

        if (address(this).balance < ownerBalanceAvailable)
            revert AdAuctionBalanceIsTooLow(); // assert ?
        ownerBalanceAvailable = 0;

        (bool res, ) = receiver.call{value: ownerBalanceAvailable}("");
        if (!res) revert OwnerWithdrawalFailed();
    }

    function chargeForAd() external onlyOwner {
        if (block.timestamp <= endAuctionTime) revert AuctionIsNotOverYet();
        Payer storage winner = addressToPayer[highestBidderAddr];
        if (winner.blockUsdBid == 0) revert NoWinnerInAuction();
        chargeForAdCalc(winner);
    }

    function chargeForAdCalc(Payer storage winner) internal onlyOwner {
        if (winner.ethBalance == 0) revert NoFundsToCharge();
        assert(winner.timeLeft == 0); // Should never happen

        uint256 timeUsed = block.timestamp - endAuctionTime;

        if (timeUsed >= winner.timeLeft) {
            winner.ethUsed += winner.ethBalance;
            ownerBalanceAvailable += winner.ethBalance;
            winner.ethBalance = 0;
            winner.timeLeft = 0;
        } else {
            uint256 blocksUsed = timeUsed / 12;
            uint256 paidInUsd = blocksUsed * winner.blockUsdBid;
            uint256 oldUsdBalance = winner.ethBalance.convertEthToUsd();
            uint256 newUsdBalance = oldUsdBalance - paidInUsd;

            winner.timeLeft = winner.timeLeft - timeUsed;

            winner.ethBalance = newUsdBalance.convertUsdToEth();
            uint256 paidInEth = paidInUsd.convertUsdToEth();
            winner.ethUsed += paidInEth;
            ownerBalanceAvailable += paidInEth;
        }
    }

    receive() external payable {
        topUp();
    }

    fallback() external payable {
        topUp();
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
}
