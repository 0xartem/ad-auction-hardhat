import { assert, expect } from "chai"
import { deployments, ethers, getNamedAccounts, network } from "hardhat"
import { deployAdAuction } from "../../scripts/deploy-ad-auction"
import { AdAuction, MockV3Aggregator } from "../../typechain-types"

describe("AdAuction", () => {
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

  describe("constructor", () => {
    it("sets the aggregator address correctly", async () => {
      const res = await adAuction.priceFeed()
      assert.equal(res, mockV3Aggregator.address)
    })
  })

  describe("bidOnAd", () => {
    it("Fails to bid before start auction time", async () => {
      const currentTimestamp = Math.floor(Date.now() / 1000)
      const secondAdAuction = await deployAdAuction(
        currentTimestamp + 1000,
        currentTimestamp + 1010,
        0,
        10,
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
        10,
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

    // const bid = 5000000000    // ~76 years for 1 eth
    // const bid = 100000000000  // ~3.8 years for 1 eth
    // const bid = 500000000000  // ~9.1 months for 1 eth
    // const bid = 5000000000000 // ~27.7 days for 1 eth
    // const bid = 100000000000000 // ~33 hours for 1 eth
    const bid = ethers.utils.parseEther("0.1") // ~2 minutes for 1 eth

    it("Sets bid and payment in eth", async () => {
      await adAuction.bidOnAd("Joy", "https://joy.com", "Hey Joy", bid, {
        value: oneEther,
      })
      const res = await adAuction.addressToPayer(deployer)
      assert.equal(res.ethBalance.toString(), oneEther.toString())
      assert.equal(res.name, "Joy")
      assert.equal(res.imageUrl, "https://joy.com")
      assert.equal(res.text, "Hey Joy")
      assert.equal(res.blockBid.toString(), bid.toString())
      assert.equal(
        res.timeLeft.toString(),
        oneEther.div(bid).mul(12).toString()
      )
      console.log(`time left: ${res.timeLeft}`)
    })

    it("Emits event on successful bid", async () => {
      await expect(
        await adAuction.bidOnAd("Joy", "https://joy.com", "Hey Joy", bid, {
          value: oneEther,
        })
      ).to.emit(adAuction, "OnBid")
    })
  })

  describe("topUp", () => {
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
        10,
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

  describe("After auction is over", () => {
    beforeEach(async () => {
      await adAuction.bidOnAd("Joy", "https://joy.com", "Hey Joy", 5, {
        value: oneEther,
      })

      const startAuctionTime = await adAuction.startAuctionTime()
      const endAuctionTime = await adAuction.endAuctionTime()
      const auctionLength = endAuctionTime.sub(startAuctionTime)
      const chargeInterval = await adAuction.chargeInterval()
      const waitTime = auctionLength.add(chargeInterval).toNumber() + 1

      await network.provider.send("evm_increaseTime", [waitTime])
      await network.provider.send("evm_mine", [])
    })

    describe("checkUpkeep", () => {})

    describe("performUpkeep", () => {
      it("calls performUpkeep after the auction and interval is over", async () => {
        const tx = await adAuction.performUpkeep([])
        assert(tx)
        await expect(
          adAuction.bidOnAd("Joy", "https://joy.com", "Hey Joy", 10, {
            value: oneEther,
          })
        ).to.be.revertedWithCustomError(adAuction, "AdAuction__AuctionIsOver")
      })
    })

    describe("withdraw by owner", () => {
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
})
