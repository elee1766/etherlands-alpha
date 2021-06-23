//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

/// @title Minecraft LandPlot NFT Interface
/// @author icpigci
interface ILandPlot {
    function setClaimable(bool _claimable) external;

    function setPlotPrices(
        uint256[] memory _prices,
        uint256[] memory _distances
    ) external;

    function setWorldSize(uint128 _worldSize) external;

    function mintMany(
        address _recv,
        int128[] memory _xs,
        int128[] memory _zs
    ) external;

    function mintOne(
        address _recv,
        int128 _x,
        int128 _z
    ) external;

    function claimLands(int128[] memory _xs, int128[] memory _zs)
        external
        payable;

    function multiTransfer(address _recv, uint256[] memory _tokenIds) external;

    function claimable() external view returns (bool);

    function totalSupply() external view returns (uint256);

    function worldSize() external view returns (uint128);

    function tokenIdOf(int128 _x, int128 _z) external view returns (uint256);

    function chunkOf(uint256 _tokenId) external view returns (int128, int128);

    function calculateLandCost(int128 _x, int128 _z)
        external
        view
        returns (uint256);
}
