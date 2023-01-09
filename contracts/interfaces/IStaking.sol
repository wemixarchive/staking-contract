// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IRewarder.sol";

/// @author @seunghwalee
interface IStaking {
    /* =========== STATE VARIABLES ===========*/

    /**
     * @notice Info of each WEMIX 3.0 Staking user.
     * `amount` LP token amount the user has provided.
     * `rewardDebt` The amount of reward entitled to the user.
     * `pendingReward` The amount of rewards(lp + mp) the user will receive.
     * `pendingAmountReward` The amount of rewards(lp) the user will receive.
     */
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingReward;
        uint256 pendingAmountReward;
        uint256 lastRewardClaimed;
    }

    /**
     * @notice Info of each WEMIX 3.0 Staking user.
     * `staked` Current user's mp amount.
     * `lastMPUpdatedTime` The amount of reward entitled to the user.
     */
    struct UserMPInfo {
        uint256 staked;
        uint256 lastMPUpdatedTime;
    }

    /**
     * @notice Info of each WEMIX 3.0 Staking pool.
     * `accRewardPerShare` Accumulated reward per share.
     * `accMPPerShare` Accumulated mp per share.
     * `lastRewardBlock` Last block number that Rewards distribution occurs.
     * `totalDeposit` The amount of total deposit lp token.
     * `totalMP` The amount of total deposit mp.
     * `rewardToken` The address of the reward token.
     * `isInputNative` True if lp token is native coin.
     * `isRewardNative` True if reward token is native coin.
     * `activatedMP` True if mp is used.
     * `lock` True in case of emergency.
     * `path` The Path to be used when running compound function.
     * `breaker` The address of breaker.
     * `breakerSetter` The address of breakerSetter.
     */
    struct PoolInfo {
        uint256 accRewardPerShare;
        uint256 accMPPerShare;
        uint256 lastRewardBlock;
        uint256 totalDeposit;
        uint256 totalMP;
        IERC20 rewardToken;
        bool isInputNative;
        bool isRewardNative;
        bool activatedMP;
        bool lock;
        address[] path;
        address breaker;
        address breakerSetter;
    }

    /**
     * @notice Add a new LP to the pool. Can only be called by the owner.
     * DO NOT add the same LP token more than once. Rewards will be messed up if you do.
     * @param _lpToken Address of the LP ERC-20 token.
     * @param _rewarder Address of the rewarder delegate.
     * @param _path The Path to be used when running compound function.
     * @param _inputNative True if lp token is native coin.
     * @param _rewardNative True if reward token is native coin.
     * @param _activatedMP True if mp is used.
     * @param _lock True in case of emergency.
     * @param _breaker The address of breaker.
     * @param _breakerSetter The address of breakerSetter.
     */
    function add(
        IERC20 _lpToken,
        IERC20 reward,
        IRewarder _rewarder,
        address[] calldata _path,
        bool _inputNative,
        bool _rewardNative,
        bool _activatedMP,
        bool _lock,
        address _breaker,
        address _breakerSetter
    ) external;

    /* =========== SET FUNCTIONS =========== */

    /**
     * @notice Update the given pool's reward point and `IRewarder` contract. Can only be called by the owner.
     * @param pid The index of the pool. See `poolInfo`.
     * @param _rewarder Address of the rewarder delegate.
     * @param _path Path to be used when compound.
     * @param rewarderOverwrite True if _rewarder should be `set`. Otherwise `_rewarder` is ignored.
     * @param pathOverwrite True if _path should be `set`. Otherwise `_path` is ignored.
     */
    function set(
        uint256 pid,
        IRewarder _rewarder,
        address[] memory _path,
        bool rewarderOverwrite,
        bool pathOverwrite
    ) external;

    function setSwapSlippage(uint256 _swapSlippage) external;

    function setPoolBreaker(uint256 pid, address _breaker) external;

    function setPoolBreakerSetter(uint256 pid, address _breakerSetter) external;

    function lockContract(uint256 pid) external;

    function unlockContract(uint256 pid) external;

    /**
     * @notice View function to see pending reward token on frontend.
     * @param pid The index of the pool. See `poolInfo`.
     * @param _user Address of user.
     * @return pending reward for a given user.
     */
    function pendingReward(
        uint256 pid,
        address _user
    ) external view returns (uint256 pending);

    /**
     * @notice View function to see pending reward token on frontend.
     * @param pid The index of the pool. See `poolInfo`.
     * @param _user Address of user.
     * @return totalPendingReward total reward for a given user.
     * @return lpPendingReward lp reward for a given user.
     * @return mpPendingReward mp reward for a given user.
     */
    function pendingRewardInfo(
        uint256 pid,
        address _user
    )
        external
        view
        returns (
            uint256 totalPendingReward,
            uint256 lpPendingReward,
            uint256 mpPendingReward
        );

    /**
     * @notice View function to see pending reward token on frontend.
     * @param pid The index of the pool. See `poolInfo`.
     * @param account Address of user.
     * @return mpAmount The amount of mp to receive when updateMP function is executed.
     */
    function pendingMP(
        uint256 pid,
        address account
    ) external view returns (uint256 mpAmount);

    /**
     * @notice The number of WEMIX 3.0 Staking pools.
     * @return pools Pool lengths.
     */
    function poolLength() external view returns (uint256 pools);

    /**
     * @notice View function to see user staking info.
     * @param pid The index of the pool. See `poolInfo`.
     * @param account Address of user.
     * @return info user staking info
     */
    function getUserInfo(
        uint256 pid,
        address account
    ) external view returns (UserInfo memory info);

    /**
     * @notice View function to see user multiplier info.
     * @param pid The index of the pool. See `poolInfo`.
     * @param account Address of user.
     * @return info user multiplier point info
     */
    function getUserMPInfo(
        uint256 pid,
        address account
    ) external view returns (UserMPInfo memory info);

    /**
     * @notice View function to see staking pool info.
     * @param pid The index of the pool. See `poolInfo`.
     * @return info staking pool info
     */
    function getPoolInfo(
        uint256 pid
    ) external view returns (PoolInfo memory info);

    /**
     * @notice View function to see staking token address.
     * @param pid The index of the pool. See `poolInfo`.
     * @return addr staking pool input token address
     */
    function getLPToken(uint256 pid) external view returns (address addr);

    /**
     * @notice View function to see staking token address.
     * @param pid The index of the pool. See `poolInfo`.
     * @return addr staking pool rewarder address
     */
    function getRewarder(uint256 pid) external view returns (address addr);

    /**
     * @notice Update reward variables for all pools. Be careful of gas spending!
     * @param pids Pool IDs of all to be updated. Make sure to update all active pools.
     */
    function massUpdatePools(uint256[] calldata pids) external;

    /**
     * @notice Update reward variables of the given pool.
     * @param pid The index of the pool. See `poolInfo`.
     * @return pool Returns the pool that was updated.
     */
    function updatePool(
        uint256 pid
    ) external payable returns (PoolInfo memory pool);

    /**
     * @notice Deposit LP tokens to WEMIX 3.0 Staking for reward.
     * @param pid The index of the pool. See `poolInfo`.
     * @param amount LP token amount to deposit.
     * @param to The receiver of `amount` deposit benefit.
     */
    function deposit(
        uint256 pid,
        uint256 amount,
        address payable to,
        bool claimReward
    ) external payable;

    /**
     *  @notice Withdraw LP tokens from WEMIX 3.0 Staking.
     *  @param pid The index of the pool. See `poolInfo`.
     *  @param amount LP token amount to withdraw.
     *  @param to Receiver of the LP tokens.
     */
    function withdraw(
        uint256 pid,
        uint256 amount,
        address payable to,
        bool claimReward
    ) external;

    /**
     *  @notice Harvest proceeds for transaction sender to `to`.
     *  @param pid The index of the pool. See `poolInfo`.
     *  @param to Receiver of rewards.
     */
    function claim(uint256 pid, address to) external;

    /**
     *  @notice Harvest proceeds for transaction sender to `to` via swap.
     *  @param pid The index of the pool. See `poolInfo`.
     *  @param to Receiver of rewards.
     */
    function claimWithSwap(uint256 pid, address to) external;

    /**
     *  @notice Compound proceeds for transaction sender to `to`.
     *  @param pid The index of the pool. See `poolInfo`.
     *  @param to Receiver of rewards.
     */
    function compound(uint256 pid, address to) external;

    function computePendingAmountReward(
        uint256 pendingReward,
        uint256 lpAmount,
        uint256 mpAmount
    ) external pure returns (uint256);

    // function massMigration(uint256[] calldata pids, address to) external;

    // function migration(uint256 pid, address to) external;

    /* ========== EVENTS ========== */

    event Deposit(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to,
        address lpAddress,
        address rewardAddress,
        uint256 rewardAmount
    );
    event Withdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to,
        address lpAddress,
        address rewardAddress,
        uint256 rewardAmount
    );
    event Harvest(
        address indexed user,
        uint256 indexed pid,
        address lpAddress,
        address rewardAddress,
        uint256 amount
    );
    event LogPoolAddition(
        uint256 indexed pid,
        IERC20 indexed lpToken,
        IRewarder indexed rewarder,
        bool isInputNative,
        bool isRewardNative,
        bool lock,
        address breaker,
        address breakerSetter
    );
    event LogSetPool(
        uint256 indexed pid,
        IRewarder indexed rewarder,
        address[] path,
        bool rewarderOverwrite,
        bool pathOverwrite
    );
    event SetSwapSlippage(uint256 swapSlippage);
    event SetPoolBreaker(uint256 pid, address breaker);
    event SetPoolBreakerSetter(uint256 pid, address breakerSetter);
    event LockContract(uint256 pid);
    event UnlockContract(uint256 pid);
    event LogUpdatePool(
        uint256 indexed pid,
        uint256 lastRewardBlock,
        uint256 lpSupply,
        uint256 accRewardPerShare
    );
    event SetMultiplierPointBasis(uint256 prev, uint256 curr);
}
