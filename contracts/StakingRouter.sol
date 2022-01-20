// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IPancakeRouter {
    function WETH() external pure returns (address);

    function getAmountsOut(uint256 amountIn, address[] memory path)
        external
        view
        returns (uint256[] memory amounts);
}

contract StakingPool {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    // bsc testnet
    IPancakeRouter pancakeRouter =
        IPancakeRouter(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
    // bsc mainnet
    // IPancakeRouter pancakeRouter = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    StakingRouter router;
    address public collection; // Lick or Theive
    address public rewardToken; // dGold or Affinity
    string public tier; // common ...

    uint256 public Apr; // Apr of this staking pool

    modifier onlyRouter() {
        require(
            msg.sender == address(router),
            "only Router can call this function"
        );
        _;
    }
    struct StakeHolder {
        EnumerableSet.UintSet stakedTokenIds;
        uint256 lastClaimedTime;
        uint256 totalClaimedRewards;
    }
    mapping(address => StakeHolder) stakeHolders;
    mapping(uint256 => uint256) tokenId2StakedTime;
    EnumerableSet.AddressSet holders;
    EnumerableSet.UintSet totalStakedTokenIds;

    constructor(
        address _collection,
        address _rewardToken,
        string memory _tier,
        uint256 _apr,
        address _router
    ) {
        router = StakingRouter(_router);
        collection = _collection;
        rewardToken = _rewardToken;
        tier = _tier;
        Apr = _apr;
    }

    function getTotalStakedCount() external view returns (uint256) {
        return totalStakedTokenIds.length();
    }

    function setApr(uint256 _apr) external onlyRouter {
        Apr = _apr;
    }

    function stakedTokenIdsOf(address account)
        external
        view
        returns (uint256[] memory)
    {
        uint256 length = stakeHolders[account].stakedTokenIds.length();
        uint256[] memory tokenIds = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            tokenIds[i] = stakeHolders[account].stakedTokenIds.at(i);
        }
        return tokenIds;
    }

    function stakeTokenTimes(address account)
        external
        view
        returns (uint256[] memory)
    {
        uint256 length = stakeHolders[account].stakedTokenIds.length();
        uint256[] memory times = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            times[i] = tokenId2StakedTime[
                stakeHolders[account].stakedTokenIds.at(i)
            ];
        }
        return times;
    }

    function getStakeHolders()
        external
        view
        onlyRouter
        returns (address[] memory _holders, uint256 _count)
    {
        _count = holders.length();
        _holders = new address[](_count);
        for (uint256 i = 0; i < _count; i++) _holders[i] = holders.at(i);
    }

    function totalClaimedRewardsOf(address account)
        external
        view
        onlyRouter
        returns (uint256)
    {
        return stakeHolders[account].totalClaimedRewards;
    }

    function unclaimedRewardsOf(address account)
        external
        view
        onlyRouter
        returns (uint256)
    {
        return _unclaimedRewardsOf(account);
    }

    /**
     * Rewards Calculation:
     * rewards = Σ 0.45 * (block.timestamp - lastClaimedTime) / (365 * 24 * 3600) * APRi
     */
    function _unclaimedRewardsOf(address account)
        private
        view
        returns (uint256)
    {
        uint256[] memory stakedTokenIds = this.stakedTokenIdsOf(account);
        if (stakedTokenIds.length == 0) return 0;
        // lastClaimedTime calculation
        uint256 lastClaimedTime = stakeHolders[account].lastClaimedTime;

        // rewards calculation
        uint256 unclaimedRewards = 0;
        for (uint256 i = 0; i < stakedTokenIds.length; i++) {
            uint256 bnbReward = ((45 *
                1e14 *
                (block.timestamp - lastClaimedTime)) / (365 * 24 * 3600)) * Apr;
            unclaimedRewards += bnbReward;
        }

        // bnb unclaimedRewards -> dGoldToken Reward
        // address[] memory path = new address[](2);
        // path[0] = pancakeRouter.WETH();
        // path[1] = rewardToken;
        // uint256 dGoldUnclaimedRewards = pancakeRouter.getAmountsOut(
        //     unclaimedRewards,
        //     path
        // )[1];
        return unclaimedRewards;
    }

    // updated
    function stake(address user, uint256[] memory tokenIds)
        external
        onlyRouter
    {
        if (stakeHolders[user].stakedTokenIds.length() > 0) {
            uint256 unclaimedRewards = _getRewards(user);
            if (unclaimedRewards > 0)
                // updated
                router.transferRewards(
                    collection,
                    rewardToken,
                    tier,
                    user,
                    unclaimedRewards
                );
        } else {
            stakeHolders[user].lastClaimedTime = block.timestamp;
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(collection).transferFrom(user, address(this), tokenIds[i]);
            stakeHolders[user].stakedTokenIds.add(tokenIds[i]);
            totalStakedTokenIds.add(tokenIds[i]);
            tokenId2StakedTime[tokenIds[i]] = block.timestamp;
        }
        if (!holders.contains(user)) holders.add(user);
        emit Staked(user, tokenIds);
    }

    function isLocked(address user, uint256[] memory tokenIds)
        public
        view
        returns (bool)
    {
        uint256 latestStakedTime = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                stakeHolders[user].stakedTokenIds.contains(tokenIds[i]),
                "You can't unstake these tokenIds"
            );
            if (latestStakedTime < tokenId2StakedTime[tokenIds[i]])
                latestStakedTime = tokenId2StakedTime[tokenIds[i]];
        }
        if ((block.timestamp - latestStakedTime) < (30 * 1 days)) return true;
        else return false;
    }

    function unstake(address user, uint256[] memory tokenIds)
        external
        onlyRouter
    {
        uint256 rate = 100;
        if (isLocked(user, tokenIds)) rate = 80;
        uint256 unclaimedRewards = _getRewards(user);
        unclaimedRewards = rate / 100;
        if (unclaimedRewards > 0)
            router.transferRewards(
                collection,
                rewardToken,
                tier,
                user,
                unclaimedRewards
            );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            stakeHolders[user].stakedTokenIds.remove(tokenIds[i]);
            totalStakedTokenIds.remove(tokenIds[i]);
            IERC721(collection).transferFrom(address(this), user, tokenIds[i]);
        }
        if (stakeHolders[user].stakedTokenIds.length() == 0)
            holders.remove(user);
        emit UnStaked(user, tokenIds);
    }

    function claimRewards(address user) external onlyRouter {
        uint256 unclaimedRewards = _getRewards(user);
        require(unclaimedRewards > 0, "No rewards to claim");
        router.transferRewards(
            collection,
            rewardToken,
            tier,
            user,
            unclaimedRewards
        );
    }

    function _getRewards(address user) private returns (uint256) {
        uint256 unclaimedRewards = _unclaimedRewardsOf(user);
        if (unclaimedRewards == 0) return 0;
        stakeHolders[user].lastClaimedTime = block.timestamp;
        stakeHolders[user].totalClaimedRewards += unclaimedRewards;
        return unclaimedRewards;
    }

    event Staked(address account, uint256[] tokenIds);
    event UnStaked(address account, uint256[] tokenIds);
}

contract StakingRouter is Ownable {
    address constant dGold = 0x2C0b73164AF92a89d30Af163912B38F45b7f7b65; // replace this to dGold Token address
    address constant affinity = 0x2C0b73164AF92a89d30Af163912B38F45b7f7b65; // replace this to Affinity Token address
    // collection -> tokenId -> tier
    mapping(address => mapping(uint256 => string)) tokenId2tier;
    // collection -> rewardToken -> tier -> StakingPool
    mapping(address => mapping(address => mapping(string => StakingPool)))
        public pools;

    function getPoolAddress(
        address _c,
        address _r,
        string memory _t
    ) external view returns (address) {
        address to = address(pools[_c][_r][_t]);
        return to;
    }

    function stakedTokenIdsOf(
        address _c,
        address _r,
        string memory _t,
        address user
    ) external view returns (uint256[] memory tokenIds) {
        tokenIds = pools[_c][_r][_t].stakedTokenIdsOf(user);
    }

    function getStakeHolders(
        address _c,
        address _r,
        string memory _t
    ) external view returns (address[] memory, uint256) {
        return pools[_c][_r][_t].getStakeHolders();
    }

    function totalClaimedRewardsOf(
        address _c,
        address _r,
        string memory _t,
        address user
    ) external view returns (uint256) {
        return pools[_c][_r][_t].totalClaimedRewardsOf(user);
    }

    function unclaimedRewardsOf(
        address _c,
        address _r,
        string memory _t,
        address user
    ) external view returns (uint256) {
        return pools[_c][_r][_t].unclaimedRewardsOf(user);
    }

    // updated
    function stake(
        address _c,
        address _r,
        string memory _t,
        uint256[] memory _ids
    ) external {
        pools[_c][_r][_t].stake(msg.sender, _ids);
    }

    function unstake(
        address _c,
        address _r,
        string memory _t,
        uint256[] memory _ids
    ) external {
        pools[_c][_r][_t].unstake(msg.sender, _ids);
    }

    function claimRewards(
        address _c,
        address _r,
        string memory _t
    ) external {
        pools[_c][_r][_t].claimRewards(msg.sender);
    }

    function createPool(
        address _c,
        address _r,
        string memory _t,
        uint256 _a
    ) external onlyOwner returns (bool) {
        if (pools[_c][_r][_t] == StakingPool(address(0)))
            pools[_c][_r][_t] = new StakingPool(_c, _r, _t, _a, address(this));
        return true;
    }

    function init() external onlyOwner {
        require(
            IERC20(dGold).transferFrom(msg.sender, address(this), 4e6 * 1e18),
            "Could not transfer 4,000,000 as rewards"
        );
        require(
            IERC20(affinity).transferFrom(
                msg.sender,
                address(this),
                4e6 * 1e18
            ),
            "Could not transfer 4,000,000 as rewards"
        );
    }

    function transferRewards(
        address collection,
        address rewardToken,
        string memory tier,
        address user,
        uint256 amount
    ) public {
        require(
            address(pools[collection][rewardToken][tier]) == msg.sender,
            "StakingRouter: Invalid permission"
        );
        IERC20(rewardToken).transfer(user, amount);
    }

    // api for frontend
    function setAprForPool(
        address _c,
        address _r,
        string memory _t,
        uint256 apr
    ) external onlyOwner {
        pools[_c][_r][_t].setApr(apr);
    }

    function getAprOfPool(
        address _c,
        address _r,
        string memory _t
    ) external view returns (uint256) {
        return pools[_c][_r][_t].Apr();
    }

    function getPoolInfo(
        address _c,
        address _r,
        string memory _t,
        address user
    )
        external
        view
        returns (
            uint256 totalStaked,
            uint256 userStaked,
            uint256 apr,
            uint256 unclaimedReward
        )
    {
        totalStaked = pools[_c][_r][_t].getTotalStakedCount();
        uint256[] memory stakedTokenIds = pools[_c][_r][_t].stakedTokenIdsOf(
            user
        );
        userStaked = stakedTokenIds.length;
        apr = pools[_c][_r][_t].Apr();
        unclaimedReward = pools[_c][_r][_t].unclaimedRewardsOf(user);
    }
}
