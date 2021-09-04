//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin/access/OwnableUpgradeable.sol";
import "./openzeppelin/token/ERC721/ERC721Upgradeable.sol";



import "./IDistrict.sol";


contract District is ERC721Upgradeable, OwnableUpgradeable, IDistrict {


    /*** variables ***/

    // plot price is calculated through comparing the smaller of the absolute value of both coordinates
    // the price is the last plotPrice index which corresponds with the plotPriceDistances in which the
    // number remains smaller.

    uint256[] public plotPrices; // array of prices, in gwei, which correspond to the below
    uint256[] public plotPriceDistances; // array of distances [x1,x2..] which correspond to the above

    uint256 public districtPrice; // price to mint a district without any deeds

    uint256 public totalPlots; // total number of minted plots
    uint256 public totalSupply; // total currently minted districts

    bool public claimable; // whether or not it is possible to mint an district or claim deeds

    uint128 public worldSize; // maximum value of any plot coordinate


    /*** mappings ***/

    mapping(uint256 => int128) public plot_x; // mapping from plotId to x plot coordinate;
    mapping(uint256 => int128) public plot_z; // mapping from plotId to z plot coordinate;
    mapping(uint256 => uint256) public plotDistrictOf; // mapping from plotId to the district it is a part of
    mapping(int128 => mapping(int128 => uint256)) public plotIdOf; // mapping from x to z to plotId

    /*** proxy logic ***/

    function initialize(string memory _name, string memory _symbol) public override initializer {
        __ERC721_init(_name, _symbol);
        __Ownable_init();

        claimable = false; // purchases are not initially available
        worldSize = 2000000; //the world is 4,000,000 x 4,000,000 plots
    }

    /*** setters ***/

    function setClaimable(bool _claimable) external override onlyOwner {
        claimable = _claimable;
    }

    function setPlotPrices(
        uint256[] memory _prices,
        uint256[] memory _distances
    ) external override onlyOwner {
        require(_prices.length == _distances.length, "length doesn't match");

        plotPrices = _prices;
        plotPriceDistances = _distances;
    }

    function setWorldSize(uint128 _worldSize) external override onlyOwner {
        require(_worldSize > 0, "World limit must be > 0");
        worldSize = _worldSize;
    }

    function setDistrictPrice(uint256 _districtPrice) external override onlyOwner {
        districtPrice = _districtPrice;
    }

    /*** plot logic ***/

    // the smallest subdivision of land is a plot
    // one plot represents a 16x16 plot of land within the minecraft game

    function _calculateLandCost(int128 _x, int128 _z) internal view returns (uint256 price){
        uint128 xA = uint128(_x >= 0 ? _x : -_x);
        uint128 zA = uint128(_z >= 0 ? _z : -_z);
        uint128 min = (xA < zA ? xA : zA);

        price = 0;
        for (uint256 i = 0; i < plotPrices.length; i++) {
            if (min <= plotPriceDistances[i] && price < plotPrices[i]) {
                price = plotPrices[i];
            }
        }
    }

    function transferPlot(uint256 origin_id, uint256 target_id, uint256[] calldata plot_ids) override external {
        require(_isApprovedOrOwner(_msgSender(), origin_id), "District: transfer caller is not owner nor approved");
        for (uint256 i = 0; i < plot_ids.length; i++) {
            _transferPlot(origin_id,target_id,plot_ids[i]);
        }
    }

    function _transferPlot(uint256 origin_id, uint256 target_id, uint256 plot_id) internal {
        require(plotDistrictOf[plot_id] == origin_id, "District: Attempted to move plot not within origin district");
        plotDistrictOf[plot_id] = target_id;
        emit PlotTransfer(origin_id,target_id,plot_id);
    }

    /*** district logic ***/
    // an district is the actual ERC721. it is a collection of plotIds.

    function claimDistrictLands(int128[] calldata _xs, int128[] calldata _zs, uint256 _districtId) external override payable {
        require(claimable,"claiming is currently disabled");
        require(
            _xs.length == _zs.length,
            "xs and zs array lengths must match!"
        );

        uint256 _id = _districtId;
        if(_districtId == 0){
            totalSupply = totalSupply + 1;
            _safeMint(_msgSender(), totalSupply);
            _id = totalSupply;
        }else{
            require(ERC721Upgradeable.ownerOf(_districtId) != address(0),"District: Attempting to claim lands to nonexistent district");
        }
        // calculate total cost
        uint256 total_cost = 0;
        for (uint256 i = 0; i < _xs.length; i++) {
            total_cost = total_cost + _calculateLandCost(_xs[i], _zs[i]);
        }
        if(_xs.length == 0){
            total_cost = total_cost + districtPrice;
        }
        require(
            msg.value >= total_cost,
            "not enough eth sent to purchase land"
        );

        if (msg.value > total_cost) {
            uint256 remaining = msg.value - total_cost;
            payable(msg.sender).transfer(remaining);
        }

        for (uint256 i = 0; i < _xs.length; i++) {
            _claimPlot(_id, _xs[i], _zs[i]);
        }

    }

    /*** claim logic ***/
    // we claim deeds by adding them to an existing estate.
    function _claimPlot(
        uint256 _districtId,
        int128 _x,
        int128 _z
    ) internal returns (uint256 tokenId) {
        require(
            plotIdOf[_x][_z] == 0,
            "attempting to claim already minted land"
        );

        uint128 xA = uint128(_x >= 0 ? _x : -_x);
        uint128 zA = uint128(_z >= 0 ? _z : -_z);
        require(
            (worldSize > xA) && (worldSize > zA),
            "the claim is beyond the specified world size"
        );

        // tokenId starts from 1
        totalPlots = totalPlots + 1;
        plot_x[totalPlots] = _x;
        plot_z[totalPlots] = _z;
        plotIdOf[_x][_z] = totalPlots;
        _transferPlot(0,_districtId,totalPlots);


        return totalPlots;
    }

    /*** admin functions ***/

    // the owner of the contract may claim any unclaimed plot and assign it to any district id
    function adminClaim(int128[] calldata _xs, int128[] calldata _zs, uint256 _districtId) external override onlyOwner {
        require(
            _xs.length == _zs.length,
            "xs and zs array lengths must match!"
        );
        for (uint256 i = 0; i < _xs.length; i++) {
            _claimPlot(_districtId, _xs[i], _zs[i]);
        }
    }
}
