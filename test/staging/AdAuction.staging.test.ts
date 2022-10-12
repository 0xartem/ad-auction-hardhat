import { ethers, getNamedAccounts, network } from "hardhat"
import { developmentChains } from "../../helper-hardhat-config"

developmentChains.includes(network.name)
  ? describe.skip
  : describe("AdAuciton", async () => {
      let adauction
      let deployer
      const oneEther = ethers.utils.parseEther("1")
      beforeEach(async () => {
        deployer = (await getNamedAccounts()).deployer
        adauction = await ethers.getContract("AdAuction", deployer)
      })

      it("allows to bid and withdraw", async () => {
        // bidOnAd
        // withdraw
      })
    })
