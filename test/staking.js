const Token1 = artifacts.require('Token1')
const Nft = artifacts.require('Nft')
const StakingRouter = artifacts.require('StakingRouter')

contract("StakingRouter",  async (accounts) => {
  let token1, nft, router, admin;
  before(async () => {
    [admin, _] = await web3.eth.getAccounts()
    console.log(admin)
    token1 = await Token1.deployed()
    nft = await Nft.deployed()
    router = await StakingRouter.deployed()
  });

  it("should init", async () => {
    // this is equalt to router's init function
    await token1.transfer(router.address, 100000000000000);
    console.log(`transfer success!`);
  });

  it("should stake", async () => {
    await router.createPool(nft.address, token1.address, 'common', 200);
    const pool = await router.getPoolAddress(nft.address, token1.address, "common");
    console.log(`created pool! ${pool}`);
    await nft.approve(pool, 56);
    console.log("approved: nft tokenId of 56");
    await router.stake(nft.address, token1.address, 'common', [56]);
    console.log(`staked`);
    await nft.approve(pool, 23);
    console.log("approved: nft tokenId of 23");
    await router.stake(nft.address, token1.address, 'common', [23]);
    console.log(`one more staked!`);
  });

  it("should call function work", async ()=> {
    const no = await router.getStakeHolders(nft.address, token1.address, 'common');
    console.log(`get stakeHolders: ${no}`);
    const balanceOfPool = await nft.balanceOf(await router.getPoolAddress(nft.address, token1.address, 'common'));
    console.log(`balance of pool ${balanceOfPool}`);
    let stakedIds = await router.stakedTokenIdsOf(nft.address, token1.address, 'common', admin)
    console.log(`stakedIds: ${stakedIds}`);
    const unreward = await router.unclaimedRewardsOf(nft.address, token1.address, 'common', admin);
    console.log(`unreward value: ${unreward}`)
  });

  it("should claimReward", async () => {
    
    await router.claimRewards(nft.address, token1.address, 'common');
    const balance = await token1.balanceOf(admin);
    console.log(`get rewards: ${balance}`);
    const totalclaimed = await router.totalClaimedRewardsOf(nft.address, token1.address, 'common', admin);
    console.log(`total claimed reward: ${totalclaimed}`);
  });

  it("should unstake", async () => {
    // to do unstake function
    await router.unstake(nft.address, token1.address, 'common', [56]);
    console.log(`unstaked!`);
  });
});
