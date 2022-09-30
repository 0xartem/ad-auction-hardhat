// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {AdAuction} from "./AdAuction.sol";

contract AdAuctionFactory {
    AdAuction[] public adAuctionArray;

    function createAdAuction(
        uint256 _startAuctionTime,
        uint256 _endAuctionTime,
        uint256 _minimumBlockUsdBid
    ) public {
        AdAuction adAuction = new AdAuction(
            _startAuctionTime,
            _endAuctionTime,
            _minimumBlockUsdBid
        );
        adAuctionArray.push(adAuction);
    }
}
