// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./interfaces/IRewarder.sol";
import "./interfaces/IStaking.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @author @seunghwalee
contract Rewarder is IRewarder, Ownable {
    using SafeERC20 for IERC20;

    address private immutable staking;
    address public WWEMIX;

    mapping(IERC20 => uint256) public lastRewardAmount;

    event LogOnReward(
        IERC20 indexed reward,
        address indexed to,
        uint256 amount,
        bool native
    );

    constructor(address _staking, address _WWEMIX) {
        staking = _staking;
        WWEMIX = _WWEMIX;
    }

    receive() external payable {}

    function onReward(
        IERC20 reward,
        address payable to,
        uint256 amount,
        bool native
    ) external override onlyStaking {
        if (native) {
            require(address(this).balance >= amount, "Not enough reward");
            to.transfer(amount);
        } else {
            require(
                reward.balanceOf(address(this)) >= amount,
                "Not enough reward"
            );
            reward.transfer(to, amount);
        }
        update(reward, native);
        emit LogOnReward(reward, to, amount, native);
    }

    function update(
        IERC20 reward,
        bool isNative
    ) public onlyStaking returns (uint256) {
        if (isNative) lastRewardAmount[reward] = address(this).balance;
        else lastRewardAmount[reward] = reward.balanceOf(address(this));
        return lastRewardAmount[reward];
    }

    function getLastReward(IERC20 reward) external view returns (uint256) {
        return lastRewardAmount[reward];
    }

    modifier onlyStaking() {
        require(msg.sender == staking, "Only Staking can call this function.");
        _;
    }
}
