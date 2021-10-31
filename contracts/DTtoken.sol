// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DTtoken is ERC20 {

    uint256 public constant INITIAL_SUPPLY = 1000;

    address public registry;

    constructor(address _manager, address _registry) ERC20("DTtoken", "DT") {
        registry = _registry;
        _mint(_manager, INITIAL_SUPPLY);
    }

    function mint(address _account, uint256 value) external {
        require(
            msg.sender == registry,
            "Only the registry can mint new tokens"
        );
        _mint(_account, value);
    }
}
