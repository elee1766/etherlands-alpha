//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin/token/ERC721/IERC721Upgradeable.sol";

interface IDistrict is IERC721Upgradeable{

    // admin functions
    function initialize(string memory _name, string memory _symbol) external;
    function setClaimable(bool _claimable) external;
    function setPlotPrices(uint256[] memory _prices, uint256[] memory _distances) external;
    function setWorldSize(uint128 _worldSize) external;
    function setDistrictPrice(uint256 _districtPrice) external;

    function adminClaim(int128[] calldata _xs, int128[] calldata _zs, uint256 _districtId) external;

    // usage functions
    function transferPlot(uint256 origin_id, uint256 target_id, uint256[] calldata plot_ids) external;
    function claimDistrictLands(int128[] calldata _xs, int128[] calldata _zs, uint256 _districtId) external payable;

    // events
    event PlotTransfer(uint256 origin_id, uint256 target_id, uint256 plotId);
}
