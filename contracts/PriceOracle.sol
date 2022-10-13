// SPDX-License-Identifier: MIT

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library PriceOracle {
    function getPrice(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint256)
    {
        // AggregatorV3Interface priceFeed = AggregatorV3Interface(
        //     0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
        // ); // Goerli
        // uint8 decimals = priceFeed.decimals();
        // require(
        //     decimals > 0,
        //     "AdAuction::getPrice: decimals in the price oracle are wrong"
        // );

        (, int256 usdPrice, , , ) = priceFeed.latestRoundData();
        return uint256(usdPrice * 1e10);
    }

    function convertEthToUsd(uint256 ethAmount, AggregatorV3Interface priceFeed)
        public
        view
        returns (uint256)
    {
        uint256 ethPrice = getPrice(priceFeed);
        uint256 ethAmountInUsd = (ethAmount * ethPrice) / 1e18;
        return ethAmountInUsd;
    }

    function convertUsdToEth(uint256 usdAmount, AggregatorV3Interface priceFeed)
        public
        view
        returns (uint256)
    {
        uint256 ethPrice = getPrice(priceFeed);
        uint256 ethAmount = (usdAmount / ethPrice); //todo: check math
        return ethAmount;
    }
}
