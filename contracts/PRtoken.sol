// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PRtoken is ERC20 {
    address public registry;
    uint256 private tokenId = 0;

    struct Token {
        uint256 tokenId;
        string tokenKey;
    }

    uint256 public constant INITIAL_SUPPLY = 0;

    mapping(string => Token) tokens;
    mapping(string => bool) tokenExist;

    constructor(address _registry) ERC20("PRtoken", "PR") {
        registry = _registry;
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function mint(
        address _account,
        uint256 value,
        string memory _tokenKey
    ) external {
        require(
            msg.sender == registry,
            "Only the registry can mint new tokens"
        );
        Token memory newToken;
        newToken.tokenId = tokenId;
        newToken.tokenKey = _tokenKey;

        tokens[_tokenKey] = newToken;
        tokenExist[_tokenKey] = true;

        tokenId++;

        _mint(_account, value);
    }

    function usePRtoken(string memory _tokenKey) view external returns (bool) {
        return tokenExist[_tokenKey];
    } 
}