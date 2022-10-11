import { developmentChains, networkConfig } from "../helper-hardhat-config"
import { network } from "hardhat"
import { verify } from "../utils/verify"
import { BigNumber } from "ethers"
import { HardhatRuntimeEnvironment } from "hardhat/types"

module.exports = async ({
  getNamedAccounts,
  deployments,
}: HardhatRuntimeEnvironment) => {
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  const chainId: number = network.config.chainId!

  const priceOracleLib = await deploy("PriceOracle", {
    from: deployer,
    log: true,
  })

  let ethUsdPriceFeedAddress
  if (developmentChains.includes(network.name)) {
    const ethUsdAggregator = await deployments.get("MockV3Aggregator")
    ethUsdPriceFeedAddress = ethUsdAggregator.address
  } else {
    ethUsdPriceFeedAddress = networkConfig[chainId]["ethUsdPriceFeed"]
  }

  const currentTimestamp = Math.floor(Date.now() / 1000)
  const args = [
    BigNumber.from(BigNumber.from(currentTimestamp)),
    BigNumber.from(BigNumber.from(currentTimestamp + 200000)),
    BigNumber.from(1),
    ethUsdPriceFeedAddress,
  ]
  const adAuction = await deploy("AdAuction", {
    from: deployer,
    args: args,
    log: true,
    libraries: {
      PriceOracle: priceOracleLib.address,
    },
    waitConfirmations: network.config.blockConfirmations || 1,
  })

  if (
    !developmentChains.includes(network.name) &&
    process.env.ETHERSCAN_API_KEY
  ) {
    await verify(adAuction.address, args)
  }
  log("=============================================================")
}

module.exports.tags = ["all", "adauction"]
