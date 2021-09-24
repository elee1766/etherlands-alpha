// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./openzeppelin/access/OwnableUpgradeable.sol";
import "./openzeppelin/token/ERC20/ERC20Upgradeable.sol";

import "./IEtherlandsToken.sol";

contract TestUSDC is ERC20Upgradeable, OwnableUpgradeable {

    bool public paused;

    function initialize(string memory _name, string memory _symbol) public initializer {
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        _mint(0x958892b4a0512b28AaAC890FC938868BBD42f064, 100*1000000*1e18); // 100 million tokens
        paused = true;
    }

    function adminMint(address to, uint256 amount) external  onlyOwner{
        ERC20Upgradeable._mint(to,amount);
    }

    function adminBurn(address from, uint256 amount) external  onlyOwner{
        ERC20Upgradeable._burn(from,amount);
    }


}
