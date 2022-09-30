import "@nomicfoundation/hardhat-toolbox"
import "dotenv/config"
import "hardhat-gas-reporter"
import "solidity-coverage"
import "@typechain/hardhat"

const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL || "https://eth-goerli/ex"
const PRIVATE_KEY = process.env.PRIVATE_KEY || "0xkey"
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "key"
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "key"

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    goerli: {
      url: GOERLI_RPC_URL,
      accounts: [PRIVATE_KEY],
      chainId: 420,
    },
    localhost: {
      url: "http://localhost:8545",
      chainId: 31337,
    },
  },
  gasReporter: {
    enabled: false,
    outputFile: "gas-report.txt",
    noColors: true,
    currency: "USD",
    coinmarketcap: COINMARKETCAP_API_KEY,
    token: "ETH",
  },
  solidity: "0.8.17",
}
