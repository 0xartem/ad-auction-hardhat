// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../AdAuction.sol";

contract EchidnaAdAuctionTest is AdAuction {
    constructor()
        AdAuction(
            block.timestamp,
            block.timestamp + 60 * 60,
            1000,
            5,
            0x0000000000000000000000000000000000000000
        )
    {}

    function echidna_chargeInterval_immutable() public view returns (bool) {
        return chargeInterval == 5;
    }
}
