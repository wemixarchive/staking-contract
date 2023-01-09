// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface IWWEMIX {
    
    /* =========== FUNCTIONS ===========*/

    function deposit() external payable;

    function withdraw(uint256 _amount) external;

    /* ========== EVENTS ========== */

    event Deposit(address indexed dst, uint256 amount);
    event Withdraw(address indexed src, uint256 amount);
}