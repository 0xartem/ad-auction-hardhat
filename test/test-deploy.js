const { ethers } = require("hardhat")
const { expect, assert } = require("chai")

describe("AdAuction", () => {
  let AdAuctionFactory, adAuction

  beforeEach(async () => {
    const PriceOracleLibFactory = await ethers.getContractFactory("PriceOracle")
    const priceOracle = await PriceOracleLibFactory.deploy()
    await priceOracle.deployed()

    AdAuctionFactory = await ethers.getContractFactory("AdAuction", {
      libraries: {
        PriceOracle: priceOracle.address,
      },
    })
    adAuction = await AdAuctionFactory.deploy(0, 1, 1)
    await adAuction.deployed()
  })

  it("Should have highest bidder as zero address", async () => {
    const highestBidder = await adAuction.highestBidderAddr()
    const zeroAddr = 0x0000000000000000000000000000000000000000
    assert.equal(highestBidder, zeroAddr)
  })

  it("Should throw an error", async () => {})
})
