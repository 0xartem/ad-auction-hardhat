import { assert, expect } from "chai"
import { BigNumber } from "ethers"
import { deployments, ethers, getNamedAccounts } from "hardhat"
import { AdAuction, MockV3Aggregator } from "../typechain-types"

describe("AdAuction", async () => {
  let deployer: string
  let adAuction: AdAuction
  let mockV3Aggregator: MockV3Aggregator
  const oneEther = ethers.utils.parseEther("1")

  beforeEach(async () => {
    deployer = (await getNamedAccounts()).deployer
    await deployments.fixture("all")
    adAuction = await ethers.getContract("AdAuction", deployer)
    mockV3Aggregator = await ethers.getContract("MockV3Aggregator", deployer)
  })

  describe("constructor", async () => {
    it("sets the aggregator address correctly", async () => {
      const res = await adAuction.priceFeed()
      assert.equal(res, mockV3Aggregator.address)
    })
  })

  describe("bid", async () => {
    it("Fails with custom error if bid is too low", async () => {
      await expect(
        adAuction.bidOnAd("Joy", "https://joy.com", "Hey Joy", 0)
      ).to.be.revertedWithCustomError(
        adAuction,
        "AdAuction__BidIsLowerThanMinimum"
      )
    })

    it("Sets bid and payment in eth", async () => {
      await adAuction.bidOnAd("Joy", "https://joy.com", "Hey Joy", 5, {
        value: oneEther,
      })
      const res = await adAuction.addressToPayer(deployer)
      assert.equal(res.ethBalance.toString(), oneEther.toString())
      assert.equal(res.name, "Joy")
      assert.equal(res.imageUrl, "https://joy.com")
      assert.equal(res.text, "Hey Joy")
      assert.equal(res.blockUsdBid.toNumber(), 5)
    })
  })

  describe("withdraw by owner", async () => {
    beforeEach(async () => {
      await adAuction.bidOnAd("Joy", "https://joy.com", "Hey Joy", 5, {
        value: oneEther,
      })
    })

    // todo: finish
    it("withdraw ETH from a single payer", async () => {
      // Arrange
      const startingAuctionBalance = await adAuction.provider.getBalance(
        adAuction.address
      )
      const deployerStartingBalance = await adAuction.provider.getBalance(
        deployer
      )

      // Act
      const txResponse = await adAuction.withdraw(deployer)
      const txReceipt = await txResponse.wait(1)

      const endingAuctionBalance = await adAuction.provider.getBalance(
        adAuction.address
      )
      const endingDeployerBalance = await adAuction.provider.getBalance(
        deployer
      )

      // Assert
      //   assert.equal(endingAuctionBalance, BigNumber.from(0))
      //   assert.equal(
      //     startingAuctionBalance.add(deployerStartingBalance).toString(),
      //     endingDeployerBalance.add(gasCost).toString()
      //   )
    })
  })
})
