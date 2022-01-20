const Nft = artifacts.require('Nft')
const router = artifacts.require('StakingRouter')
const Token1 = artifacts.require('Token1')
module.exports = function (deployer, network, accounts) {
  deployer.deploy(Nft)
  deployer.deploy(router)
  deployer.deploy(Token1)
  //, { overwrite: true }
}
