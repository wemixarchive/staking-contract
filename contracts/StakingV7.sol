// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./interfaces/IWWEMIX.sol";
import "./interfaces/IWeswapRouter.sol";
import "./interfaces/IStaking.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

/// @author @seunghwalee
/// @notice Allows compound to liquid staking contract only.
contract StakingV7 is IStaking, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using AddressUpgradeable for address payable;

    /* =========== STATE VARIABLES ===========*/

    /**
     * @notice Info of each WEMIX 3.0 Staking pool.
     */
    PoolInfo[] private _poolInfo;

    /**
     * @notice Address of the LP token for each WEMIX 3.0 Staking pool.
     */
    IERC20[] private _lpToken;

    /**
     * @notice Address of each `IRewarder` contract in WEMIX 3.0 Staking.
     */
    IRewarder[] private _rewarder;

    /**
     * @notice Info of each user that stakes LP tokens.
     */
    mapping(uint256 => mapping(address => UserInfo)) private _userInfo;

    uint256 private constant ACC_REWARD_PRECISION = 1e18;

    /**
     * @notice Address of weswap router.
     */
    IWeswapRouter public router;

    /* =========== MP STATE VARIABLES ===========*/

    /**
     * @notice Info of each user that stakes LP tokens.
     */
    mapping(uint256 => mapping(address => UserMPInfo)) private _userMPInfo;

    uint256 public multiplierPointBasis;
    uint256 public constant BASIS_POINTS_DIVISOR = 1000;
    uint256 public constant MP_DUARTION = 365 days;

    /* =========== COMPOUND STATE VARIABLES ===========*/

    uint256 public swapSlippage;
    uint256 public constant SWAP_DIVISOR = 10000;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IWeswapRouter _router) external reinitializer(7) {
        require(
            address(_router) != address(0),
            "Rewarder::initialize: INVALID_ADDRESS."
        );
        router = _router;

        multiplierPointBasis = 1000;
        swapSlippage = 9000;

        whitelistSetter = msg.sender;

        __Ownable_init();
        __ReentrancyGuard_init();
    }

    receive() external payable {}

    function setMultiplierPointBasis(
        uint256 newMultiplierPointBasis
    ) external onlyOwner {
        uint256 prevMultiplierPointBasis = multiplierPointBasis;
        multiplierPointBasis = newMultiplierPointBasis;
        emit SetMultiplierPointBasis(
            prevMultiplierPointBasis,
            newMultiplierPointBasis
        );
    }

    function migrate_withdraw_all(
        uint256 pid,
        address[] memory froms_,
        address to
    ) external nonReentrant onlyOwner {
        require(!oneTime, "Only once.");

        for (uint256 i = 0; i < froms_.length; i++) {
            UserInfo memory user = _userInfo[pid][froms_[i]];

            _migrate_withdraw(pid, user.amount, froms_[i], payable(to), true);
        }

        oneTime = true;
    }

    function _migrate_withdraw(
        uint256 pid,
        uint256 amount,
        address from_,
        address payable to,
        bool claimReward
    ) internal {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = _userInfo[pid][from_];
        UserMPInfo memory mpInfo = _userMPInfo[pid][from_];

        {
            bool claimReward_ = claimReward;
            if (user.amount == amount) {
                claimReward_ = true;
            }

            if (user.amount > 0) {
                _harvest(pid, payable(from_), to, claimReward_, true, true);
            }
        }
        (pool, mpInfo) = _updateMP(pid, from_);

        uint256 reductionMP = (mpInfo.staked * amount) / user.amount;
        mpInfo.staked -= reductionMP;
        pool.totalMP -= reductionMP;

        user.amount -= amount;

        // Effects
        user.rewardDebt =
            ((user.amount + mpInfo.staked) * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION;

        if (pool.isInputNative) {
            IWWEMIX((address(_lpToken[pid]))).withdraw(amount);
            to.sendValue(amount);
        } else {
            _lpToken[pid].transfer(to, amount);
        }

        pool.totalDeposit -= amount;
        _poolInfo[pid] = pool;
        _userMPInfo[pid][from_] = mpInfo;
    }

    /* =========== ADD FUNCTION =========== */

    /**
     * @notice Add a new LP to the pool. Can only be called by the owner.
     * DO NOT add the same LP token more than once. Rewards will be messed up if you do.
     * @param lpToken_ Address of the LP ERC-20 token.
     * @param rewarder_ Address of the _rewarder delegate.
     * @param _path The Path to be used when running compound function.
     * @param _inputNative True if lp token is native coin.
     * @param _rewardNative True if reward token is native coin.
     * @param _activatedMP True if mp is used.
     * @param _lock True in case of emergency.
     * @param _breaker The address of breaker.
     * @param _breakerSetter The address of breakerSetter.
     */
    function add(
        IERC20 lpToken_,
        IERC20 reward,
        IRewarder rewarder_,
        address[] calldata _path,
        bool _inputNative,
        bool _rewardNative,
        bool _activatedMP,
        bool _lock,
        address _breaker,
        address _breakerSetter
    )
        external
        onlyOwner
        nonZeroAddress(_breaker)
        nonZeroAddress(_breakerSetter)
    {
        require(
            address(lpToken_) != address(0),
            "Staking::add: INVALID_ADDRESS."
        );
        require(
            address(reward) != address(0),
            "Staking::add: INVALID_ADDRESS."
        );
        require(
            address(rewarder_) != address(0),
            "Staking::add: INVALID_ADDRESS."
        );

        _lpToken.push(lpToken_);
        _rewarder.push(rewarder_);

        // check path exist
        require(address(reward) == _path[0], "Staking::add: INVALID_PATH.");
        require(
            address(lpToken_) == _path[_path.length - 1],
            "Staking::add: INVALID_PATH."
        );
        if (_rewardNative && _inputNative) {} else {
            router.getAmountsOut(1 ether, _path);
        }

        _poolInfo.push(
            PoolInfo({
                lastRewardBlock: block.number,
                accRewardPerShare: 0,
                accMPPerShare: 0,
                totalDeposit: 0,
                totalMP: 0,
                rewardToken: reward,
                path: _path,
                isInputNative: _inputNative,
                isRewardNative: _rewardNative,
                activatedMP: _activatedMP,
                lock: _lock,
                breaker: _breaker,
                breakerSetter: _breakerSetter
            })
        );
        emit LogPoolAddition(
            _lpToken.length - 1,
            lpToken_,
            rewarder_,
            _inputNative,
            _rewardNative,
            _lock,
            _breaker,
            _breakerSetter
        );
    }

    /* =========== SET FUNCTIONS =========== */

    /**
     * @notice Update the given pool's reward point and `IRewarder` contract. Can only be called by the owner.
     * @param pid The index of the pool. See `_poolInfo`.
     * @param rewarder_ Address of the _rewarder delegate.
     * @param _path Path to be used when compound.
     * @param rewarderOverwrite True if rewarder_ should be `set`. Otherwise `rewarder_` is ignored.
     * @param pathOverwrite True if _path should be `set`. Otherwise `_path` is ignored.
     */
    function set(
        uint256 pid,
        IRewarder rewarder_,
        address[] memory _path,
        bool rewarderOverwrite,
        bool pathOverwrite
    ) external onlyOwner checkPoolExists(pid) whenNotLock(pid) {
        require(
            address(rewarder_) != address(0),
            "Staking::add: INVALID_ADDRESS."
        );

        updatePool(pid);
        PoolInfo storage pool = _poolInfo[pid];

        if (rewarderOverwrite) {
            _rewarder[pid] = rewarder_;
        }

        // check path exist
        require(
            address(pool.rewardToken) == _path[0],
            "Staking::set: INVALID_PATH."
        );
        require(
            address(_lpToken[pid]) == _path[_path.length - 1],
            "Staking::set: INVALID_PATH."
        );
        if (pool.isRewardNative && pool.isInputNative) {} else {
            router.getAmountsOut(1 ether, _path);
        }

        if (pathOverwrite) {
            pool.path = _path;
        }

        emit LogSetPool(
            pid,
            rewarderOverwrite ? rewarder_ : _rewarder[pid],
            pathOverwrite ? _path : pool.path,
            rewarderOverwrite,
            pathOverwrite
        );
    }

    function setSwapSlippage(
        uint256 _swapSlippage
    ) external onlyOwner validSwapSlippage(_swapSlippage) {
        swapSlippage = _swapSlippage;

        emit SetSwapSlippage(swapSlippage);
    }

    function setPoolBreaker(
        uint256 pid,
        address _breaker
    ) external nonZeroAddress(_breaker) checkPoolExists(pid) whenNotLock(pid) {
        PoolInfo storage pool = _poolInfo[pid];

        require(
            msg.sender == pool.breakerSetter,
            "STAKING: Caller is not BreakerSetter."
        );

        pool.breaker = _breaker;

        emit SetPoolBreaker(pid, _breaker);
    }

    function setPoolBreakerSetter(
        uint256 pid,
        address _breakerSetter
    )
        external
        nonZeroAddress(_breakerSetter)
        checkPoolExists(pid)
        whenNotLock(pid)
    {
        PoolInfo storage pool = _poolInfo[pid];

        require(
            msg.sender == pool.breakerSetter,
            "STAKING: Caller is not BreakerSetter."
        );

        pool.breakerSetter = _breakerSetter;

        emit SetPoolBreakerSetter(pid, _breakerSetter);
    }

    /* =========== BREAK FUNCTIONS =========== */

    function lockContract(
        uint256 pid
    ) external checkPoolExists(pid) whenNotLock(pid) {
        PoolInfo storage pool = _poolInfo[pid];

        require(msg.sender == pool.breaker, "STAKING: Caller is not Breaker.");

        pool.lock = true;

        emit LockContract(pid);
    }

    function unlockContract(uint256 pid) external checkPoolExists(pid) {
        PoolInfo storage pool = _poolInfo[pid];

        require(msg.sender == pool.breaker, "STAKING: Caller is not Breaker.");
        require(pool.lock, "STAKING: NOT EMERGENCY!");

        pool.lock = false;

        emit UnlockContract(pid);
    }

    /* =========== VIEW FUNCTIONS =========== */

    /**
     * @notice View function to see pending reward token on frontend.
     * @param pid The index of the pool. See `_poolInfo`.
     * @param _user Address of user.
     * @return pending reward for a given user.
     */
    function pendingReward(
        uint256 pid,
        address _user
    ) public view returns (uint256 pending) {
        PoolInfo memory pool = _poolInfo[pid];
        UserInfo memory user = _userInfo[pid][_user];
        UserMPInfo memory mpInfo = _userMPInfo[pid][_user];

        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lastReward = _rewarder[pid].getLastReward(pool.rewardToken);
        uint256 currentTotalReward = 0;

        if (pool.isRewardNative) {
            currentTotalReward = address(_rewarder[pid]).balance;
        } else {
            currentTotalReward = pool.rewardToken.balanceOf(
                address(_rewarder[pid])
            );
        }

        if (block.number > pool.lastRewardBlock && pool.totalDeposit != 0) {
            uint256 allocReward = currentTotalReward - lastReward;
            accRewardPerShare =
                accRewardPerShare +
                (allocReward * ACC_REWARD_PRECISION) /
                (pool.totalDeposit + pool.totalMP);
        }

        uint256 addedReward = ((user.amount + mpInfo.staked) *
            accRewardPerShare) /
            ACC_REWARD_PRECISION -
            user.rewardDebt;
        pending = user.pendingReward + addedReward;
    }

    /**
     * @notice View function to see pending reward token on frontend.
     * @param pid The index of the pool. See `_poolInfo`.
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
        )
    {
        UserInfo memory user = _userInfo[pid][_user];
        UserMPInfo memory mpInfo = _userMPInfo[pid][_user];

        totalPendingReward = pendingReward(pid, _user);
        lpPendingReward =
            user.pendingAmountReward +
            computePendingAmountReward(
                totalPendingReward - user.pendingReward,
                user.amount,
                mpInfo.staked
            );
        mpPendingReward = totalPendingReward - lpPendingReward;
    }

    /**
     * @notice View function to see pending reward token on frontend.
     * @param pid The index of the pool. See `_poolInfo`.
     * @param account Address of user.
     * @return mpAmount The amount of mp to receive when updateMP function is executed.
     */
    function pendingMP(
        uint256 pid,
        address account
    ) external view returns (uint256 mpAmount) {
        UserInfo memory user = _userInfo[pid][account];
        UserMPInfo memory mpInfo = _userMPInfo[pid][account];

        uint256 lastMPUpdate = mpInfo.lastMPUpdatedTime;
        if (block.timestamp == lastMPUpdate) return 0;

        mpAmount =
            ((block.timestamp - lastMPUpdate) *
                user.amount *
                multiplierPointBasis) /
            BASIS_POINTS_DIVISOR /
            MP_DUARTION;
    }

    /**
     * @notice The number of WEMIX 3.0 Staking pools.
     * @return pools Pool lengths.
     */
    function poolLength() external view returns (uint256 pools) {
        pools = _poolInfo.length;
    }

    /**
     * @notice View function to see user staking info.
     * @param pid The index of the pool. See `_poolInfo`.
     * @param account Address of user.
     * @return info user staking info
     */
    function getUserInfo(
        uint256 pid,
        address account
    ) external view returns (UserInfo memory info) {
        info = _userInfo[pid][account];
    }

    /**
     * @notice View function to see user multiplier info.
     * @param pid The index of the pool. See `_poolInfo`.
     * @param account Address of user.
     * @return info user multiplier point info
     */
    function getUserMPInfo(
        uint256 pid,
        address account
    ) external view returns (UserMPInfo memory info) {
        info = _userMPInfo[pid][account];
    }

    /**
     * @notice View function to see staking pool info.
     * @param pid The index of the pool. See `_poolInfo`.
     * @return info staking pool info
     */
    function getPoolInfo(
        uint256 pid
    ) external view returns (PoolInfo memory info) {
        info = _poolInfo[pid];
    }

    /**
     * @notice View function to see staking token address.
     * @param pid The index of the pool. See `_poolInfo`.
     * @return addr staking pool input token address
     */
    function getLPToken(uint256 pid) external view returns (address addr) {
        addr = address(_lpToken[pid]);
    }

    /**
     * @notice View function to see staking token address.
     * @param pid The index of the pool. See `_poolInfo`.
     * @return addr staking pool _rewarder address
     */
    function getRewarder(uint256 pid) external view returns (address addr) {
        addr = address(_rewarder[pid]);
    }

    /* =========== FUNCTIONS =========== */

    /**
     * @notice Update reward variables for all pools. Be careful of gas spending!
     * @param pids Pool IDs of all to be updated. Make sure to update all active pools.
     */
    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    /**
     * @notice Update reward variables of the given pool.
     * @param pid The index of the pool. See `_poolInfo`.
     * @return pool Returns the pool that was updated.
     */
    function updatePool(
        uint256 pid
    ) public payable returns (PoolInfo memory pool) {
        pool = _poolInfo[pid];

        require(pool.lastRewardBlock != 0, "STAKING: Pool does not exist");

        if (block.number > pool.lastRewardBlock) {
            uint256 lpSupply = pool.totalDeposit;
            uint256 lastReward = _rewarder[pid].getLastReward(pool.rewardToken);
            uint256 currentTotalReward = _rewarder[pid].update(
                pool.rewardToken,
                pool.isRewardNative
            );

            if (lpSupply > 0) {
                uint256 allocReward = currentTotalReward - lastReward;
                pool.accRewardPerShare =
                    pool.accRewardPerShare +
                    (allocReward * ACC_REWARD_PRECISION) /
                    (lpSupply + pool.totalMP);
            }

            pool.lastRewardBlock = block.number;
            _poolInfo[pid] = pool;

            emit LogUpdatePool(
                pid,
                pool.lastRewardBlock,
                lpSupply,
                pool.accRewardPerShare
            );
        }
    }

    /**
     * @notice Update reward variables of the given pool.
     * @param pid The index of the pool. See `_poolInfo`.
     */
    function updateMP(uint256 pid) external {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = _userInfo[pid][msg.sender];
        UserMPInfo memory mpInfo = _userMPInfo[pid][msg.sender];

        if (user.amount > 0) {
            uint256 accumulatedReward = ((user.amount + mpInfo.staked) *
                pool.accRewardPerShare) / ACC_REWARD_PRECISION;
            uint256 pending = accumulatedReward - user.rewardDebt;

            user.pendingReward += pending;
            user.pendingAmountReward += computePendingAmountReward(
                pending,
                user.amount,
                mpInfo.staked
            );
        }

        (pool, mpInfo) = _updateMP(pid, msg.sender);

        // Effects
        user.rewardDebt =
            ((user.amount + mpInfo.staked) * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION;
        _userMPInfo[pid][msg.sender] = mpInfo;
    }

    /**
     * @notice Update reward variables of the given pool.
     * @param pid The index of the pool. See `_poolInfo`.
     * @param account user account.
     * @return pool Returns the pool that was updated.
     * @return mpInfo Returns the mpInfo that was updated.
     */
    function _updateMP(
        uint256 pid,
        address account
    ) internal returns (PoolInfo memory pool, UserMPInfo memory mpInfo) {
        pool = _poolInfo[pid];
        UserInfo memory user = _userInfo[pid][account];
        mpInfo = _userMPInfo[pid][account];

        if (!pool.activatedMP) return (pool, mpInfo);

        if (mpInfo.lastMPUpdatedTime == 0) {
            _userMPInfo[pid][account].lastMPUpdatedTime = block.timestamp;
            return (pool, _userMPInfo[pid][account]);
        }

        if (block.timestamp > mpInfo.lastMPUpdatedTime) {
            uint256 increasedMP = ((block.timestamp -
                mpInfo.lastMPUpdatedTime) *
                user.amount *
                multiplierPointBasis) /
                BASIS_POINTS_DIVISOR /
                MP_DUARTION;
            mpInfo.staked += increasedMP;
            pool.totalMP += increasedMP;
            mpInfo.lastMPUpdatedTime = block.timestamp;

            _poolInfo[pid] = pool;
            _userMPInfo[pid][account] = mpInfo;
        }
        return (pool, mpInfo);
    }

    /**
     * @notice Deposit LP tokens to WEMIX 3.0 Staking for reward.
     * @param pid The index of the pool. See `_poolInfo`.
     * @param amount LP token amount to deposit.
     * @param to The receiver of `amount` deposit benefit.
     * @param claimReward Whether claim rewards or not.
     */
    function deposit(
        uint256 pid,
        uint256 amount,
        address payable to,
        bool claimReward
    ) external payable nonReentrant {
        uint256 prevAmount;

        prevAmount = IERC20((address(_lpToken[pid]))).balanceOf(address(this));
        if (msg.value != 0) {
            require(msg.value == amount, "STAKING: Wrong amount");
            IWWEMIX((address(_lpToken[pid]))).deposit{value: amount}();
        } else {
            _lpToken[pid].transferFrom(msg.sender, address(this), amount);
        }
        require(
            IERC20((address(_lpToken[pid]))).balanceOf(address(this)) -
                prevAmount ==
                amount,
            "Staking::deposit: Deflationary tokens are not supported"
        );

        _deposit(pid, amount, to, claimReward);
    }

    /**
     * @notice Deposit LP tokens to WEMIX 3.0 Staking for reward.
     * @param pid The index of the pool. See `_poolInfo`.
     * @param amount LP token amount to deposit.
     * @param to The receiver of `amount` deposit benefit.
     * @param claimReward Whether claim rewards or not.
     */
    function _deposit(
        uint256 pid,
        uint256 amount,
        address payable to,
        bool claimReward
    ) internal {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = _userInfo[pid][to];
        UserMPInfo memory mpInfo = _userMPInfo[pid][to];

        uint256 _pendingReward = pendingReward(pid, to);

        if (user.lastRewardClaimed == 0) {
            user.lastRewardClaimed = block.timestamp;
        }

        if (pool.lock) {
            require(!claimReward, "STAKING: EMERGENCY!");
        }

        if (user.amount > 0) {
            _harvest(pid, to, to, claimReward, true, true);
        }
        (pool, mpInfo) = _updateMP(pid, to);

        user.amount += amount;

        // Effects
        user.rewardDebt =
            ((user.amount + mpInfo.staked) * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION;

        pool.totalDeposit += amount;
        _poolInfo[pid] = pool;
        _userMPInfo[pid][to] = mpInfo;

        emit Deposit(
            msg.sender,
            pid,
            amount,
            to,
            address(_lpToken[pid]),
            address(pool.rewardToken),
            _pendingReward - user.pendingReward
        );
    }

    /**
     *  @notice Withdraw LP tokens from WEMIX 3.0 Staking.
     *  @param pid The index of the pool. See `_poolInfo`.
     *  @param amount LP token amount to withdraw.
     *  @param to Receiver of the LP tokens.
     */
    function withdraw(
        uint256 pid,
        uint256 amount,
        address payable to,
        bool claimReward
    ) external nonReentrant whenNotLock(pid) {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = _userInfo[pid][msg.sender];
        UserMPInfo memory mpInfo = _userMPInfo[pid][msg.sender];

        uint256 _pendingReward = pendingReward(pid, msg.sender);

        {
            bool claimReward_ = claimReward;
            if (user.amount == amount) {
                claimReward_ = true;
            }

            if (user.amount > 0) {
                _harvest(
                    pid,
                    payable(msg.sender),
                    to,
                    claimReward_,
                    true,
                    true
                );
            }
        }
        (pool, mpInfo) = _updateMP(pid, msg.sender);

        uint256 reductionMP = (mpInfo.staked * amount) / user.amount;
        mpInfo.staked -= reductionMP;
        pool.totalMP -= reductionMP;

        user.amount -= amount;

        // Effects
        user.rewardDebt =
            ((user.amount + mpInfo.staked) * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION;

        if (pool.isInputNative) {
            IWWEMIX((address(_lpToken[pid]))).withdraw(amount);
            to.sendValue(amount);
        } else {
            _lpToken[pid].transfer(to, amount);
        }

        pool.totalDeposit -= amount;
        _poolInfo[pid] = pool;
        _userMPInfo[pid][msg.sender] = mpInfo;

        emit Withdraw(
            msg.sender,
            pid,
            amount,
            to,
            address(_lpToken[pid]),
            address(pool.rewardToken),
            _pendingReward - user.pendingReward
        );
    }

    /**
     *  @notice Harvest proceeds for transaction sender to `to`.
     *  @param pid The index of the pool. See `_poolInfo`.
     *  @param to Receiver of rewards.
     */
    function claim(
        uint256 pid,
        address to
    ) external nonReentrant whenNotLock(pid) {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = _userInfo[pid][msg.sender];
        UserMPInfo memory mpInfo = _userMPInfo[pid][msg.sender];

        if (user.amount > 0) {
            _harvest(pid, payable(msg.sender), payable(to), true, true, false);
        }

        // Effects
        user.rewardDebt =
            ((user.amount + mpInfo.staked) * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION;
    }

    /**
     *  @notice Harvest proceeds for transaction sender to `to` via swap.
     *  @param pid The index of the pool. See `_poolInfo`.
     *  @param to Receiver of rewards.
     */
    function claimWithSwap(
        uint256 pid,
        address to
    ) external nonReentrant whenNotLock(pid) {
        _claimWithSwap(pid, to);
    }

    function _claimWithSwap(uint256 pid, address to) internal {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = _userInfo[pid][msg.sender];
        UserMPInfo memory mpInfo = _userMPInfo[pid][msg.sender];

        if (user.amount > 0) {
            _harvest(
                pid,
                payable(msg.sender),
                payable(address(this)),
                true,
                false,
                false
            );

            if (user.pendingReward > 0) {
                address swapTarget = pool.path[pool.path.length - 1];
                bool isSwapTargetNative = swapTarget == router.WWEMIX();

                if (pool.isRewardNative) {
                    if (isSwapTargetNative) {
                        payable(to).sendValue(user.pendingReward);
                    } else {
                        uint256[] memory amounts = router.getAmountsOut(
                            10 **
                                IERC20Metadata(address(pool.rewardToken))
                                    .decimals(),
                            pool.path
                        );
                        uint256 minAmountNotDivideYet = (user.pendingReward *
                            amounts[amounts.length - 1]);

                        router.swapExactWEMIXForTokens{
                            value: user.pendingReward
                        }(
                            (minAmountNotDivideYet * swapSlippage) /
                                (SWAP_DIVISOR * amounts[0]),
                            pool.path,
                            to,
                            block.timestamp + 600
                        );
                    }
                } else {
                    uint256 minAmount;
                    {
                        uint256[] memory amounts = router.getAmountsOut(
                            10 **
                                IERC20Metadata(address(pool.rewardToken))
                                    .decimals(),
                            pool.path
                        );
                        minAmount =
                            (user.pendingReward * amounts[amounts.length - 1]) /
                            amounts[0];
                    } // to avoid stack too deep error

                    pool.rewardToken.approve(
                        address(router),
                        user.pendingReward
                    );

                    uint256 expectedAmount;
                    {
                        uint256[] memory expectedAmounts = router.getAmountsOut(
                            user.pendingReward,
                            pool.path
                        );
                        expectedAmount = expectedAmounts[
                            expectedAmounts.length - 1
                        ];
                    } // to avoid stack too deep error

                    if (isSwapTargetNative) {
                        uint256[] memory amountouts = router
                            .swapExactTokensForWEMIX(
                                user.pendingReward,
                                (minAmount * swapSlippage) / SWAP_DIVISOR,
                                pool.path,
                                to,
                                block.timestamp + 600
                            );
                        require(
                            expectedAmount == amountouts[amountouts.length - 1],
                            "Staking::compound: Deflationary tokens are not supported"
                        );
                    } else {
                        uint256[] memory amountouts = router
                            .swapExactTokensForTokens(
                                user.pendingReward,
                                (minAmount * swapSlippage) / SWAP_DIVISOR,
                                pool.path,
                                to,
                                block.timestamp + 600
                            );
                        require(
                            expectedAmount == amountouts[amountouts.length - 1],
                            "Staking::compound: Deflationary tokens are not supported"
                        );
                    }
                }

                // updateUser
                user.pendingReward = 0;
                user.pendingAmountReward = 0;
                user.lastRewardClaimed = block.timestamp;
            }
        }

        // Effects
        user.rewardDebt =
            ((user.amount + mpInfo.staked) * pool.accRewardPerShare) /
            ACC_REWARD_PRECISION;
    }

    /**
     *  @notice Compound proceeds for transaction sender to `to`.
     *  @param pid The index of the pool. See `_poolInfo`.
     *  @param to Receiver of rewards.
     */
    function compound(
        uint256 pid,
        address to
    )
        external
        nonReentrant
    /* whenNotLock(pid) */ /* onlyWhitelist(msg.sender) */ {
        if (pid == 0) {
            require(whitelist[msg.sender], "onlyWhitelist: INVALID_ACCOUNT.");
        }
        PoolInfo memory pool = updatePool(pid);
        UserInfo memory user = _userInfo[pid][msg.sender];
        // UserMPInfo memory mpInfo = _userMPInfo[pid][msg.sender];

        if (user.amount > 0) {
            // swap
            uint256 prevAmount = IERC20((address(_lpToken[pid]))).balanceOf(
                address(this)
            );
            _claimWithSwap(pid, address(this));
            if (pool.isInputNative) {
                IWWEMIX(address(_lpToken[pid])).deposit{
                    value: address(this).balance
                }();
            }
            uint256 currAmount = IERC20((address(_lpToken[pid]))).balanceOf(
                address(this)
            );

            // deposit
            if (currAmount - prevAmount > 0) {
                _deposit(pid, currAmount - prevAmount, payable(to), false);
            }
        }
    }

    function _harvest(
        uint256 pid,
        address from_,
        address payable to,
        bool claimReward,
        bool updateUser,
        bool computeReward
    ) internal {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = _userInfo[pid][from_];
        UserMPInfo memory mpInfo = _userMPInfo[pid][from_];

        uint256 accumlatedReward = ((user.amount + mpInfo.staked) *
            pool.accRewardPerShare) / ACC_REWARD_PRECISION;
        uint256 pending = accumlatedReward - user.rewardDebt;

        user.pendingReward += pending;

        if (computeReward) {
            user.pendingAmountReward += computePendingAmountReward(
                pending,
                user.amount,
                mpInfo.staked
            );
        }

        if (claimReward) {
            _rewarder[pid].onReward(
                pool.rewardToken,
                to,
                user.pendingReward,
                pool.isRewardNative
            );
            emit Harvest(
                msg.sender,
                pid,
                address(_lpToken[pid]),
                address(pool.rewardToken),
                user.pendingReward
            );
            if (updateUser) {
                user.pendingReward = 0;
                user.pendingAmountReward = 0;
                user.lastRewardClaimed = block.timestamp;
            }
        }
    }

    /* =========== Migration =========== */

    bool public migrationFlag;
    bool internal migrateWemixFlag;
    bool internal oneTime;

    // Deprecated

    /* =========== MODIFIER FUNCTIONS =========== */

    modifier nonZeroAddress(address inputAddress) {
        require(inputAddress != address(0), "STAKING: Address cannot be 0.");
        _;
    }

    modifier checkPoolExists(uint256 pid) {
        require(
            _poolInfo.length > pid,
            "STAKING: _poolInfo length must be greater than or equal to pid"
        );
        _;
    }

    modifier validSwapSlippage(uint256 swapSlippageFactor) {
        require(
            SWAP_DIVISOR > swapSlippageFactor,
            "STAKING: SWAP_DIVISOR must be greater than swapSlippageFactor."
        );
        _;
    }

    modifier whenNotLock(uint256 pid) {
        require(!_poolInfo[pid].lock, "STAKING: EMERGENCY!");
        _;
    }

    /* =========== FUNCTIONS =========== */

    function computePendingAmountReward(
        uint256 pendingRewardAmount,
        uint256 lpAmount,
        uint256 mpAmount
    ) public pure returns (uint256) {
        if ((lpAmount + mpAmount) == 0) return 0;
        return (pendingRewardAmount * lpAmount) / (lpAmount + mpAmount);
    }

    /* =========== Liquid-related Functions =========== */

    mapping(address => bool) public whitelist;

    address public whitelistSetter;

    event SetWhitelistSetter(address whitelistSetter);
    event SetWhitelist(address account, bool allow);

    modifier onlyWhitelistSetter() {
        require(
            msg.sender == whitelistSetter,
            "onlyWhitelistSetter: INVALID_ACCOUNT."
        );
        _;
    }

    function setWhitelistSetter(
        address _whitelistSetter
    ) external onlyWhitelistSetter {
        whitelistSetter = _whitelistSetter;
        emit SetWhitelistSetter(whitelistSetter);
    }

    function setWhitelist(
        address account,
        bool allow
    ) external onlyWhitelistSetter {
        whitelist[account] = allow;
        emit SetWhitelist(account, allow);
    }
}
