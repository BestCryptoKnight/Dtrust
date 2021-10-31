// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SchedulerInterface
 * @dev The base contract that the higher contracts: BaseScheduler, BlockScheduler and TimestampScheduler all inherit from.
 */
interface SchedulerInterface {
    function schedule(
        address _toAddress,
        bytes memory _callData,
        uint256[8] memory _uintArgs
    ) external payable returns (address);

    function computeEndowment(
        uint256 _bounty,
        uint256 _fee,
        uint256 _callGas,
        uint256 _callValue,
        uint256 _gasPrice
    ) external view returns (uint256);
}
