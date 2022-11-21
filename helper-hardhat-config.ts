import { ethers } from "ethers"

export const networkConfig = {
  5: {
    name: "goerli",
    ethUsdPriceFeed: "0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e",
    minimumBlockBid: 100000000000000, // ~33 hours for 1 eth
    chargeInterval: 30,
    auctionLength: 60 * 60 * 60,
  },
  137: {
    name: "polygon",
    ethUsdPriceFeed: "0xF9680D99D6C9589e2a93a78A04A279e509205945",
    minimumBlockBid: 5000000000000, // ~27.7 days for 1 matic
    chargeInterval: 60,
    auctionLength: 60 * 60 * 60,
  },
  1: {
    name: "mainnet",
    ethUsdPriceFeed: "",
    minimumBlockBid: 100000000000, // ~3.8 years for 1 eth
    chargeInterval: 60,
    auctionLength: 60 * 60 * 60,
  },
  1337: {
    name: "localhost",
    // minimumBlockBid: ethers.utils.parseEther("0.1"), // ~2 minutes for 1 eth
    minimumBlockBid: 1000,
    chargeInterval: 5,
    auctionLength: 60 * 60,
  },
  31337: {
    name: "hardhat",
    // minimumBlockBid: ethers.utils.parseEther("0.1"), // ~2 minutes for 1 eth
    minimumBlockBid: 1000,
    chargeInterval: 5,
    auctionLength: 60 * 60,
  },
}

export const developmentChains = ["hardhat", "localhost"]
export const DECIMALS = 8
export const INITIAL_ANSWER = 200000000000
