// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRewarder {
    function onReward(
        IERC20 reward,
        address payable to,
        uint256 amount,
        bool native
    ) external;
    function update(IERC20 reward, bool isNative) external returns(uint256);
    function getLastReward(IERC20 reward) external view returns(uint256);
}
