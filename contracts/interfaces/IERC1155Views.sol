// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC1155Views {
    function totalSupply(uint256 _id) external view returns (uint256);
    function name(uint256 _id) external view returns (string memory);
    function symbol(uint256 _id) external view returns (string memory);
    function decimals(uint256 _id) external view returns (uint8);
    // function uri(uint256 _id) external view returns (string memory);
}
