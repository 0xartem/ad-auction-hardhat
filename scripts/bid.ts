import { ethers, getNamedAccounts } from "hardhat"
import { AdAuction } from "../typechain-types"

async function main() {
  const { deployer } = await getNamedAccounts()
  const adAuction: AdAuction = await ethers.getContract("AdAuction", deployer)
  console.log("Funding contract...")
  const txRes = await adAuction.bidOnAd("hey", "url", "hey text", 5, {
    value: ethers.utils.parseEther("1"),
  })
  await txRes.wait(1)
  console.log("We bid on ad!")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
