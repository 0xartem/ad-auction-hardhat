// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAdAuction {
    function bidOnAd(
        string calldata _name,
        string calldata _imageUrl,
        string calldata _text,
        uint256 _blockUsdBid
    ) external payable;

    function chargeForAd() external;

    function withdrawBid(address receiver) external;

    function withdraw(address receiver) external;
}
