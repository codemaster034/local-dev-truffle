//const dGold = artifacts.require('dGoldToken')
const Token1 = artifacts.require("Token1");
const Nft = artifacts.require("Nft");
const StakingRouter = artifacts.require("StakingRouter");

module.exports = async (done) => {
  try {
    const [admin, _] = await web3.eth.getAccounts();
    console.log(`admin: ${admin}`);
    const token1 = await Token1.deployed();
    console.log(`token1 deployed! address: ${token1.address}`);
    const nft = await Nft.deployed();
    console.log(`Nft deployed! address: ${nft.address}`);
    const router = await StakingRouter.deployed();
    console.log(`router deployed! address: ${router.address}`);

    const balanceOfPool = await nft.balanceOf(
      await router.getPoolAddress(nft.address, token1.address, "common")
    );
    console.log(`balance of pool ${balanceOfPool}`);

    const weth = await router.pancakeRouter.WETH();
  } catch (e) {
    console.log(e);
  }
  done();
};
