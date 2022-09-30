// SPDX-License-Identifier: MIT

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library PriceOracle {
    function getPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
        ); // Goerli
        uint8 decimals = priceFeed.decimals();
        require(
            decimals > 0,
            "AdAuction::getPrice: decimals in the price oracle are wrong"
        );

        (, int256 usdPrice, , , ) = priceFeed.latestRoundData();
        return uint256(usdPrice) * 1**(18 - decimals);
    }

    function convertEthToUsd(uint256 ethAmount) public view returns (uint256) {
        uint256 ethPrice = getPrice();
        uint256 usdAmount = (ethAmount * ethPrice) / 1e18;
        return usdAmount;
    }

    function convertUsdToEth(uint256 usd) public view returns (uint256) {
        uint256 ethPrice = getPrice();
        uint256 ethAmount = (usd / ethPrice); //todo: check math
        return ethAmount;
    }
}
