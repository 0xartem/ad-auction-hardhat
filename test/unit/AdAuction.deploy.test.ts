import { ethers } from "hardhat"
import { expect, assert } from "chai"
import { AdAuction, AdAuction__factory } from "../../typechain-types"

describe("AdAuction Deployment", () => {
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

    adAuction = await AdAuctionFactory.deploy(
      0,
      1,
      1,
      10,
      "0x0000000000000000000000000000000000000000"
    )
    await adAuction.deployed()
  })

  it("Should throw an AdAuction__InvalidAuctionPeriod error", async () => {
    await expect(
      AdAuctionFactory.deploy(
        1,
        0,
        1,
        10,
        "0x0000000000000000000000000000000000000000"
      )
    ).to.be.revertedWithCustomError(
      adAuction,
      "AdAuction__InvalidAuctionPeriod"
    )
  })

  it("Should deploy successfully", async () => {
    const startAuctionTime = await adAuction.startAuctionTime()
    assert.equal(startAuctionTime.toNumber(), 0)

    const endAuctionTime = await adAuction.endAuctionTime()
    assert.equal(endAuctionTime.toNumber(), 1)

    const minBlockBid = await adAuction.minimumBlockBid()
    assert.equal(minBlockBid.toNumber(), 1)

    const owner = await adAuction.owner()
    const signer = ethers.provider.getSigner()
    assert.equal(await signer.getAddress(), owner)

    const highestBidder = await adAuction.highestBidderAddr()
    const zeroAddr: string = "0x0000000000000000000000000000000000000000"
    assert.equal(highestBidder, zeroAddr)
  })
})
