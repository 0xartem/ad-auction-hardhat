import { ethers } from "hardhat"
import { expect, assert } from "chai"
import { AdAuction, AdAuction__factory } from "../typechain-types"

describe("AdAuction bidOnAd", () => {
  let AdAuctionFactory: AdAuction__factory
  let adAuction: AdAuction

  beforeEach(async () => {
    const PriceOracleLibFactory = await ethers.getContractFactory("PriceOracle")
    const priceOracle = await PriceOracleLibFactory.deploy()
    await priceOracle.deployed()

    AdAuctionFactory = (await ethers.getContractFactory("AdAuction", {
      libraries: {
        PriceOracle: priceOracle.address,
      },
    })) as AdAuction__factory

    adAuction = await AdAuctionFactory.deploy(0, 1, 1, "0x0")
    await adAuction.deployed()
  })

  it("Should", async () => {})
})
