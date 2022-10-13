import { ethers } from "hardhat"
import { AdAuction, AdAuction__factory } from "../typechain-types"

export async function deployAdAuction(
  startAuctionTimestamp: number,
  endAuctionTimestamp: number,
  minBlockBid: number,
  chargeInterval: number,
  ethUsdPriceFeedAddress: string
): Promise<AdAuction> {
  const PriceOracleLibFactory = await ethers.getContractFactory("PriceOracle")
  console.log("Deploying PriceOracle lib...")
  const priceOracle = await PriceOracleLibFactory.deploy()
  await priceOracle.deployed()
  console.log(`Deployed PriceOracle: ${priceOracle.address}`)

  const AdAuctionFactory = (await ethers.getContractFactory("AdAuction", {
    libraries: {
      PriceOracle: priceOracle.address,
    },
  })) as AdAuction__factory

  console.log(
    `Start aucion time: ${startAuctionTimestamp}; End auction time: ${endAuctionTimestamp}`
  )

  console.log("Deploying Ad Auction...")
  const adAuction: AdAuction = (await AdAuctionFactory.deploy(
    startAuctionTimestamp,
    endAuctionTimestamp,
    minBlockBid,
    chargeInterval,
    ethUsdPriceFeedAddress
  )) as AdAuction
  await adAuction.deployed()
  console.log(`Deployed Ad Auction to: ${adAuction.address}`)
  return adAuction
}
