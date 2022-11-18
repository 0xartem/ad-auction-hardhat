import { ethers, network } from "hardhat"
import * as fs from "fs-extra"

const FRONT_END_ADDRESSES_FILE =
  "../ad-auction-nextjs-app/constants/contractAddresses.json"
const FRONT_END_ABI_FILE =
  "../ad-auction-nextjs-app/constants/adAuctionAbi.json"
const AD_AUCTION_ABI_FILE = "./artifacts/contracts/AdAuction.sol/AdAuction.json"

export default async function () {
  if (process.env.UPDATE_FRONT_END) {
    console.log("Updating front end...")
    updateContractAddresses()
    updateAbis()
  }
}

async function updateAbis() {
  const adAuctionAbiRaw = fs.readFileSync(AD_AUCTION_ABI_FILE, "utf-8")
  fs.writeFileSync(FRONT_END_ABI_FILE, adAuctionAbiRaw, "utf-8")
}

async function updateContractAddresses() {
  const adAuction = await ethers.getContract("AdAuction")
  const chainId = network.config.chainId?.toString() as string
  const currentAddresses = JSON.parse(
    fs.readFileSync(FRONT_END_ADDRESSES_FILE, "utf-8")
  )
  if (chainId in currentAddresses) {
    if (!currentAddresses[chainId].includes(adAuction.address)) {
      currentAddresses[chainId].push(adAuction.address)
    }
  } else {
    currentAddresses[chainId] = [adAuction.address]
  }
  fs.writeFileSync(FRONT_END_ADDRESSES_FILE, JSON.stringify(currentAddresses))
}

module.exports.tags = ["all", "frontend"]
