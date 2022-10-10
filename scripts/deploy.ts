import { ethers, network } from "hardhat"
import { verify } from "../utils/verify"

async function main() {
  const PriceOracleLibFactory = await ethers.getContractFactory("PriceOracle")
  console.log("Deploying PriceOracle lib...")
  const priceOracle = await PriceOracleLibFactory.deploy()
  await priceOracle.deployed()
  console.log(`Deployed PriceOracle: ${priceOracle.address}`)

  const AdAuctionFactory = await ethers.getContractFactory("AdAuction", {
    libraries: {
      PriceOracle: priceOracle.address,
    },
  })

  const height = await ethers.provider.getBlockNumber()
  const block = await ethers.provider.getBlock(height)
  console.log(`Current block is ${block}`)

  const startAuctionTimestamp = block.timestamp
  const endAuctionTimestamp = startAuctionTimestamp + 10000
  const minBlockUsdBid = 100
  console.log(
    `Start aucion time: ${startAuctionTimestamp}; End auction time: ${endAuctionTimestamp}`
  )

  console.log("Deploying Ad Auction...")
  const adAuction = await AdAuctionFactory.deploy(
    startAuctionTimestamp,
    endAuctionTimestamp,
    minBlockUsdBid
  )
  await adAuction.deployed()
  console.log(`Deployed Ad Auction to: ${adAuction.address}`)

  console.log(network.config)
  if (network.config.chainId === 420 && process.env.ETHERSCAN_API_KEY) {
    console.log("Waiting for transaction confirmations...")
    await adAuction.deployTransaction.wait(6)
    await verify(adAuction.address, [
      startAuctionTimestamp,
      endAuctionTimestamp,
      minBlockUsdBid,
    ])
  }

  const txResponse = await adAuction.bidOnAd(
    "Joe",
    "https://i.imgflip.com/30b1gx.jpg",
    "Wait for it...",
    200
  )
  await txResponse.wait(1)

  const highestBidderAddr = await adAuction.highestBidderAddr()
  console.log(`Highest bidder is ${highestBidderAddr}`)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
