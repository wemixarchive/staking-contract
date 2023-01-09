## `IStaking`






### `add(contract IERC20 _lpToken, contract IERC20 reward, contract IRewarder _rewarder, address[] _path, bool _inputNative, bool _rewardNative, bool _activatedMP, bool _lock, address _breaker, address _breakerSetter)` (external)

Add a new LP to the pool. Can only be called by the owner.
DO NOT add the same LP token more than once. Rewards will be messed up if you do.




### `set(uint256 pid, contract IRewarder _rewarder, address[] _path, bool rewarderOverwrite, bool pathOverwrite)` (external)

Update the given pool's reward point and `IRewarder` contract. Can only be called by the owner.




### `setSwapSlippage(uint256 _swapSlippage)` (external)





### `setPoolBreaker(uint256 pid, address _breaker)` (external)





### `setPoolBreakerSetter(uint256 pid, address _breakerSetter)` (external)





### `lockContract(uint256 pid)` (external)





### `unlockContract(uint256 pid)` (external)





### `pendingReward(uint256 pid, address _user) → uint256 pending` (external)

View function to see pending reward token on frontend.




### `pendingRewardInfo(uint256 pid, address _user) → uint256 totalPendingReward, uint256 lpPendingReward, uint256 mpPendingReward` (external)

View function to see pending reward token on frontend.




### `pendingMP(uint256 pid, address account) → uint256 mpAmount` (external)

View function to see pending reward token on frontend.




### `poolLength() → uint256 pools` (external)

The number of WEMIX 3.0 Staking pools.




### `getUserInfo(uint256 pid, address account) → struct IStaking.UserInfo info` (external)

View function to see user staking info.




### `getUserMPInfo(uint256 pid, address account) → struct IStaking.UserMPInfo info` (external)

View function to see user multiplier info.




### `getPoolInfo(uint256 pid) → struct IStaking.PoolInfo info` (external)

View function to see staking pool info.




### `getLPToken(uint256 pid) → address addr` (external)

View function to see staking token address.




### `getRewarder(uint256 pid) → address addr` (external)

View function to see staking token address.




### `massUpdatePools(uint256[] pids)` (external)

Update reward variables for all pools. Be careful of gas spending!




### `updatePool(uint256 pid) → struct IStaking.PoolInfo pool` (external)

Update reward variables of the given pool.




### `deposit(uint256 pid, uint256 amount, address payable to, bool claimReward)` (external)

Deposit LP tokens to WEMIX 3.0 Staking for reward.




### `withdraw(uint256 pid, uint256 amount, address payable to, bool claimReward)` (external)

 @notice Withdraw LP tokens from WEMIX 3.0 Staking.
 @param pid The index of the pool. See `poolInfo`.
 @param amount LP token amount to withdraw.
 @param to Receiver of the LP tokens.



### `claim(uint256 pid, address to)` (external)

 @notice Harvest proceeds for transaction sender to `to`.
 @param pid The index of the pool. See `poolInfo`.
 @param to Receiver of rewards.



### `claimWithSwap(uint256 pid, address to)` (external)

 @notice Harvest proceeds for transaction sender to `to` via swap.
 @param pid The index of the pool. See `poolInfo`.
 @param to Receiver of rewards.



### `compound(uint256 pid, address to)` (external)

 @notice Compound proceeds for transaction sender to `to`.
 @param pid The index of the pool. See `poolInfo`.
 @param to Receiver of rewards.



### `computePendingAmountReward(uint256 pendingReward, uint256 lpAmount, uint256 mpAmount) → uint256` (external)






### `Deposit(address user, uint256 pid, uint256 amount, address to, address lpAddress, address rewardAddress, uint256 rewardAmount)`





### `Withdraw(address user, uint256 pid, uint256 amount, address to, address lpAddress, address rewardAddress, uint256 rewardAmount)`





### `Harvest(address user, uint256 pid, address lpAddress, address rewardAddress, uint256 amount)`





### `LogPoolAddition(uint256 pid, contract IERC20 lpToken, contract IRewarder rewarder, bool isInputNative, bool isRewardNative, bool lock, address breaker, address breakerSetter)`





### `LogSetPool(uint256 pid, contract IRewarder rewarder, address[] path, bool rewarderOverwrite, bool pathOverwrite)`





### `SetSwapSlippage(uint256 swapSlippage)`





### `SetPoolBreaker(uint256 pid, address breaker)`





### `SetPoolBreakerSetter(uint256 pid, address breakerSetter)`





### `LockContract(uint256 pid)`





### `UnlockContract(uint256 pid)`





### `LogUpdatePool(uint256 pid, uint256 lastRewardBlock, uint256 lpSupply, uint256 accRewardPerShare)`





### `SetMultiplierPointBasis(uint256 prev, uint256 curr)`





