//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin/token/ERC721/IERC721Upgradeable.sol";

interface IDistrict is IERC721Upgradeable {
    // admin functions
    function initialize(string memory _name, string memory _symbol) external;

    function setClaimable(bool _claimable) external;

    function setPlotPrices(uint256[] memory _prices, uint24[] memory _distances)
        external;

    function setWorldSize(uint24 _worldSize) external;

    function setDistrictPrice(uint256 _districtPrice) external;

    function setUnderlyingCurrency(address _erc20Address) external;

    function setRewardCurrency(address _erc20Address) external;

    function setRewardAmount(uint256 amount) external;

    function adminClaim(
        int24[] calldata _xs,
        int24[] calldata _zs,
        uint256 _districtId
    ) external;

    function eminentDomainDistrict(uint256 district_id) external;

    // usage functions
    function claimRewardsFor(address _target) external;

    function setDistrictName(uint256 district_id, bytes24 districtName)
        external;

    function transferPlot(
        uint256 origin_id,
        uint256 target_id,
        uint64[] calldata plot_ids
    ) external;

    function claimDistrictLands(
        int24[] calldata _xs,
        int24[] calldata _zs,
        uint256 _districtId,
        bytes24 _name
    ) external;

    // metatx functions
    function isTrustedForwarder(address forwarder) external view returns (bool);

    // events
    event PlotTransfer(uint256 origin_id, uint256 target_id, uint64 plotId);
    event PlotCreation(int24 x, int24 z, uint64 plotId);
    event DistrictName(uint256 district_id);
}
