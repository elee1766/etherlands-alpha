// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./openzeppelin/access/OwnableUpgradeable.sol";
import "./openzeppelin/token/ERC20/ERC20Upgradeable.sol";
import "./maticnetwork/NativeMetaTransaction.sol";

import "./IEtherlandsToken.sol";

contract EtherlandsBridgeToken is
    ERC20Upgradeable,
    OwnableUpgradeable,
    NativeMetaTransaction
{
    bool public paused;

    address public childChainManager;

    function initialize(string memory _name, string memory _symbol)
        public
        initializer
    {
        __ERC20_init(_name, _symbol);
        __EIP712Base_init(_name);
        __Ownable_init();
        paused = true;
        childChainManager = 0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal view override {
        if (
            from == OwnableUpgradeable.owner() ||
            to == OwnableUpgradeable.owner()
        ) {
            return;
        }

        if (from == childChainManager || to == childChainManager) {
            return;
        }
        require(paused != true, "transfers are currently paused");
    }

    function setPaused(bool pause) external onlyOwner {
        paused = pause;
    }

    /**
     * @notice called when token is deposited on root chain
     * @dev Should be callable only by ChildChainManager
     * Should handle deposit by minting the required amount for user
     * Make sure minting is done only by this function
     * @param user user address for whom deposit is being done
     * @param depositData abi encoded amount
     */
    function deposit(address user, bytes calldata depositData) external {
        require(
            _msgSender() == childChainManager,
            "only childChainMember may call deposit"
        );
        uint256 amount = abi.decode(depositData, (uint256));
        _mint(user, amount);
    }

    /**
     * @notice called when user wants to withdraw tokens back to root chain
     * @dev Should burn user's tokens. This transaction will be verified when exiting on root chain
     * @param amount amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}
