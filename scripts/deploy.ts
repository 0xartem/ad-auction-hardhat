// Manual script deployment
import { ethers, network } from "hardhat"
import { verify } from "../utils/verify"
import { developmentChains, networkConfig } from "../helper-hardhat-config"
import { deployAdAuction } from "./deploy-ad-auction"
import { AdAuction } from "../typechain-types"

async function main() {
  const height = await ethers.provider.getBlockNumber()
  const block = await ethers.provider.getBlock(height)
  console.log(`Current block is ${block}`)

  const startAuctionTimestamp = block.timestamp
  const endAuctionTimestamp = startAuctionTimestamp + 10000
  const minBlockBid = 100
  const chargeInterval = 30

  let ethUsdPriceFeedAddress
  if (developmentChains.includes(network.name)) {
    ethUsdPriceFeedAddress = "0x0000000000000000000000000000000000000000"
  } else {
    ethUsdPriceFeedAddress = networkConfig[chainId]["ethUsdPriceFeed"]
  }

  const adAuction: AdAuction = await deployAdAuction(
    startAuctionTimestamp,
    endAuctionTimestamp,
    minBlockBid,
    chargeInterval,
    ethUsdPriceFeedAddress
  )

  console.log("Network config:")
  console.log(network.config)
  if (network.config.chainId === 5 && process.env.ETHERSCAN_API_KEY) {
    console.log("Waiting for transaction confirmations...")
    await adAuction.deployTransaction.wait(6)
    await verify(adAuction.address, [
      startAuctionTimestamp,
      endAuctionTimestamp,
      minBlockBid,
    ])
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
