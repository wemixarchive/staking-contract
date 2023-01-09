// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEnvStorage {
    function getBlockRewardAmount() external view returns (uint256);

    function getBlockRewardDistributionMethod()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function DENOMINATOR() external view returns (uint256);
}
