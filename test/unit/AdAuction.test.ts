import { assert, expect } from "chai"
import { deployments, ethers, getNamedAccounts } from "hardhat"
import { before } from "mocha"
import { deployAdAuction } from "../../scripts/deploy-ad-auction"
import { AdAuction, MockV3Aggregator } from "../../typechain-types"

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

  describe("bidOnAd", async () => {
    it("Fails to bid before start auction time", async () => {
      const currentTimestamp = Math.floor(Date.now() / 1000)
      const secondAdAuction = await deployAdAuction(
        currentTimestamp + 1000,
        currentTimestamp + 1010,
        0,
        mockV3Aggregator.address
      )

      await expect(
        secondAdAuction.bidOnAd("", "", "", 1)
      ).to.be.revertedWithCustomError(
        secondAdAuction,
        "AdAuction__AuctionHasntStartedYet"
      )
    })

    it("Fails to bid after auction is over", async () => {
      const currentTimestamp = Math.floor(Date.now() / 1000)
      const secondAdAuction = await deployAdAuction(
        currentTimestamp - 1000,
        currentTimestamp - 990,
        0,
        mockV3Aggregator.address
      )

      await expect(
        secondAdAuction.bidOnAd("", "", "", 1)
      ).to.be.revertedWithCustomError(
        secondAdAuction,
        "AdAuction__AuctionIsOver"
      )
    })

    it("Fails with custom error if bid is too low", async () => {
      await expect(
        adAuction.bidOnAd("Joy", "https://joy.com", "Hey Joy", 0)
      ).to.be.revertedWithCustomError(
        adAuction,
        "AdAuction__BidIsLowerThanMinimum"
      )
    })

    it("Fails is higher bidder is available", async () => {
      await adAuction.bidOnAd("", "", "", 10, { value: oneEther })
      await expect(
        adAuction.bidOnAd("", "", "", 5, { value: oneEther })
      ).to.be.revertedWithCustomError(
        adAuction,
        "AdAuction__HigherBidIsAvailable"
      )
    })

    it("Fails if eth paid less that for one block", async () => {
      await expect(
        adAuction.bidOnAd("", "", "", 10)
      ).to.be.revertedWithCustomError(
        adAuction,
        "AdAuction__PaidAmountIsLowerThanBid"
      )
    })

    it("Sets bid and payment in eth", async () => {
      const bid = 5000000000
      await adAuction.bidOnAd("Joy", "https://joy.com", "Hey Joy", bid, {
        value: oneEther,
      })
      const res = await adAuction.addressToPayer(deployer)
      assert.equal(res.ethBalance.toString(), oneEther.toString())
      assert.equal(res.name, "Joy")
      assert.equal(res.imageUrl, "https://joy.com")
      assert.equal(res.text, "Hey Joy")
      assert.equal(res.blockBid.toNumber(), bid)
      assert.equal(
        res.timeLeft.toString(),
        oneEther.div(bid).mul(12).toString()
      )
      console.log(`time left: ${res.timeLeft}`) // approx. 76 years
    })
  })

  describe("topUp", async () => {
    beforeEach(async () => {
      await adAuction.bidOnAd("Joy", "https://joy.com", "Hey Joy", 5000000000, {
        value: oneEther,
      })
      console.log("===========================================")
    })

    it("Fails to topUp before start auction time", async () => {
      const currentTimestamp = Math.floor(Date.now() / 1000)
      const secondAdAuction = await deployAdAuction(
        currentTimestamp + 1000,
        currentTimestamp + 1010,
        0,
        mockV3Aggregator.address
      )

      await expect(
        secondAdAuction.topUp({ value: oneEther })
      ).to.be.revertedWithCustomError(
        secondAdAuction,
        "AdAuction__AuctionHasntStartedYet"
      )
    })

    it("Fails to top up because the payer didn't submit a bid", async () => {
      const accounts = await ethers.getSigners()
      const adAuctionForAccount1 = adAuction.connect(accounts[1])
      await expect(
        adAuctionForAccount1.topUp({ value: oneEther })
      ).to.be.revertedWithCustomError(adAuction, "AdAuction__NoSuchPayer")
    })

    it("Fails to top up because the amount is lower than bid for one block", async () => {
      await expect(
        adAuction.topUp({ value: 5000 })
      ).to.be.revertedWithCustomError(
        adAuction,
        "AdAuction__PaidAmountIsLowerThanBid"
      )
    })

    it("Tops up the payer account", async () => {
      await adAuction.topUp({ value: oneEther })
      const res = await adAuction.addressToPayer(deployer)

      assert.equal(res.ethBalance.toString(), oneEther.add(oneEther).toString())
      assert.equal(res.name, "Joy")
      assert.equal(res.imageUrl, "https://joy.com")
      assert.equal(res.text, "Hey Joy")
      assert.equal(res.blockBid.toNumber(), 5000000000)
      assert.equal(
        res.timeLeft.toString(),
        oneEther.add(oneEther).div(5000000000).mul(12).toString()
      )
    })
  })

  describe("withdraw by owner", async () => {
    beforeEach(async () => {
      await adAuction.bidOnAd("Joy", "https://joy.com", "Hey Joy", 5, {
        value: oneEther,
      })
      // todo: await new Promise((resolve) => setTimeout(resolve, 10000))
      console.log("===========================================")
    })

    // todo: finish
    it("withdraw ETH from a single payer", async () => {
      // Arrange
      // const startingAuctionBalance = await adAuction.provider.getBalance(
      //   adAuction.address
      // )
      // const deployerStartingBalance = await adAuction.provider.getBalance(
      //   deployer
      // )
      // // Act
      // const txResponse = await adAuction.withdraw(deployer)
      // const txReceipt = await txResponse.wait(1)
      // const { gasUsed, effectiveGasPrice } = txReceipt
      // const gasCost = gasUsed.mul(effectiveGasPrice)
      // const endingAuctionBalance = await adAuction.provider.getBalance(
      //   adAuction.address
      // )
      // const endingDeployerBalance = await adAuction.provider.getBalance(
      //   deployer
      // )
      // // Assert
      // assert.equal(endingAuctionBalance.toString(), "0")
      // assert.equal(
      //   startingAuctionBalance.add(deployerStartingBalance).toString(),
      //   endingDeployerBalance.add(gasCost).toString()
      // )
    })
  })
})
