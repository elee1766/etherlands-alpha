//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin/access/OwnableUpgradeable.sol";
import "./openzeppelin/token/ERC721/ERC721Upgradeable.sol";
import "./maticnetwork/NativeMetaTransaction.sol";

import "./IERC20.sol";
import "./IDistrict.sol";

contract District is
    ERC721Upgradeable,
    OwnableUpgradeable,
    IDistrict,
    NativeMetaTransaction
{
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

    IERC20 public underlyingCurrency; // currency to accept for payment
    // reward token along with
    IERC20 public rewardCurrency; // currency to reward
    uint256 public rewardAmount; // amount of currency to reward per plot
    address public trustedForwarder; // this should be set to the current contract addr

    /*** mappings ***/
    // holds plot information
    mapping(uint256 => int128) public plot_x; // mapping from plotId to x plot coordinate;
    mapping(uint256 => int128) public plot_z; // mapping from plotId to z plot coordinate;
    mapping(uint256 => uint256) public plotDistrictOf; // mapping from plotId to the district it is a part of
    mapping(int128 => mapping(int128 => uint256)) public plotIdOf; // mapping from x to z to plotId

    // holds pending and claimed reward information
    mapping(address => uint256) public totalRewardsOf;
    mapping(address => uint256) public claimedRewardsOf;

    // holds name information
    mapping(bytes24 => uint256) public nameDistrictOf;
    mapping(uint256 => bytes24) public districtNameOf;

    /*** proxy logic ***/
    function initialize(string memory _name, string memory _symbol)
        public
        override
        initializer
    {
        __ERC721_init(_name, _symbol);
        __EIP712Base_init(_name);
        __Ownable_init();

        claimable = false; // purchases are not initially available
        worldSize = 2000000; //the world is 4,000,000 x 4,000,000 plots
    }

    /*** admin functions ***/
    function eminentDomainDistrict(uint256 district_id) external override onlyOwner {
        address from = _owners[district_id];
        address to = address(this);
        _approve(address(0), district_id);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = address(this);

        emit Transfer(from, to, tokenId);
    }

    /*** admin setters ***/
    function setClaimable(bool _claimable) external override onlyOwner {
        claimable = _claimable;
    }

    function setPlotPrices(
        uint256[] memory _prices,
        uint256[] memory _distances
    ) external override onlyOwner {
        require(
            _prices.length == _distances.length,
            "District: Length doesn't match"
        );
        plotPrices = _prices;
        plotPriceDistances = _distances;
    }

    function setWorldSize(uint128 _worldSize) external override onlyOwner {
        require(_worldSize > 0, "District: World limit must be > 0");
        worldSize = _worldSize;
    }

    function setDistrictPrice(uint256 _districtPrice)
        external
        override
        onlyOwner
    {
        districtPrice = _districtPrice;
    }

    function setUnderlyingCurrency(address _erc20Address)
        external
        override
        onlyOwner
    {
        underlyingCurrency = IERC20(_erc20Address);
    }

    function setRewardCurrency(address _erc20Address)
        external
        override
        onlyOwner
    {
        rewardCurrency = IERC20(_erc20Address);
    }

    function setRewardAmount(uint256 amount) external override onlyOwner {
        rewardAmount = amount;
    }

    function setTrustedForwarder(address _address) external onlyOwner {
        trustedForwarder = _address;
    }

    function setCounts(uint256 plots, uint256 districts) external onlyOwner {
        totalPlots = plots;
        totalSupply = districts;
    }

    /*** plot logic ***/

    // the smallest subdivision of land is a plot
    // one plot represents a 16x16 plot of land within the minecraft game
    // in minecraft its 16x16 blocks (but could be anything!)

    function _calculateLandCost(int128 _x, int128 _z)
        internal
        view
        returns (uint256)
    {
        uint128 xA = uint128(_x >= 0 ? _x : -_x);
        uint128 zA = uint128(_z >= 0 ? _z : -_z);
        uint128 min = (xA < zA ? xA : zA);

        uint256 price = 0;
        for (uint256 i = 0; i < plotPrices.length; i++) {
            if (min >= plotPriceDistances[i]) {
                price = plotPrices[i];
            }
        }

        return price;
    }

    function transferPlot(
        uint256 origin_id,
        uint256 target_id,
        uint256[] calldata plot_ids
    ) external override {
        require(
            _isApprovedOrOwner(_msgSender(), origin_id),
            "District: transfer caller is not owner nor approved"
        );
        for (uint256 i = 0; i < plot_ids.length; i++) {
            _transferPlot(origin_id, target_id, plot_ids[i]);
        }
    }

    function setDistrictName(uint256 district_id, bytes24 districtName)
        public
        override
    {
        require(
            _isApprovedOrOwner(_msgSender(), district_id),
            "District: set name caller is not owner nor approved"
        );
        for (uint256 i = 0; i < districtName.length; i++) {
            require(districtName[i] < 0x42, "invalid character");
        }
        require(validate24Name(districtName), "Name must be 0 terminated");
        require(
            nameDistrictOf[districtName] == 0 ||
                nameDistrictOf[districtName] == district_id,
            "name taken"
        );
        if (districtNameOf[district_id] != 0x0) {
            nameDistrictOf[districtNameOf[district_id]] = 0x0;
        }
        nameDistrictOf[districtName] = district_id;
        districtNameOf[district_id] = districtName;

        emit DistrictName(district_id);
    }

    function validate24Name(bytes24 name) internal pure returns (bool) {
        bool found = false;
        for (uint256 i = 0; i < 24; i++) {
            if (name[i] == 0x00) {
                found = true;
            }
            if (found) {
                if (name[i] != 0x00) {
                    return false;
                }
            }
        }
        return true;
    }

    function _transferPlot(
        uint256 origin_id,
        uint256 target_id,
        uint256 plot_id
    ) internal {
        require(
            plotDistrictOf[plot_id] == origin_id,
            "District: Attempted to move plot not within origin district"
        );
        plotDistrictOf[plot_id] = target_id;
        emit PlotTransfer(origin_id, target_id, plot_id);
    }

    /*** reward logic ***/
    function claimRewardsFor(address _target) public override {
        uint256 amount = totalRewardsOf[_target] - claimedRewardsOf[_target];
        claimedRewardsOf[_target] = totalRewardsOf[_target];
        rewardCurrency.transfer(_target, amount);
    }

    /*** district logic ***/
    // an district is the actual ERC721. it is a collection of plotIds
    function claimDistrictLands(
        int128[] calldata _xs,
        int128[] calldata _zs,
        uint256 _districtId,
        bytes24 _nickname
    ) external override {
        require(claimable, "claiming is currently disabled");
        uint256 _id = _districtId;
        if (_districtId == 0) {
            totalSupply = totalSupply + 1;
            _safeMint(_msgSender(), totalSupply);
            _id = totalSupply;
            if (_nickname != 0x0) {
                setDistrictName(_id, _nickname); // nickname only matterws if districtId == 0 && _nickname != 0
            }
        } else {
            require(
                ERC721Upgradeable.ownerOf(_districtId) != address(0),
                "District: Attempting to claim lands to nonexistent district"
            );
        }
        require(
            _xs.length == _zs.length,
            "xs and zs array lengths must match!"
        );
        // calculate total cost
        uint256 total_cost = 0;
        for (uint256 i = 0; i < _xs.length; i++) {
            total_cost = total_cost + _calculateLandCost(_xs[i], _zs[i]);
        }
        if (_xs.length == 0) {
            total_cost = total_cost + districtPrice;
        }
        underlyingCurrency.transferFrom(
            _msgSender(),
            address(this),
            total_cost
        );
        for (uint256 i = 0; i < _xs.length; i++) {
            _claimPlot(_id, _xs[i], _zs[i]);
        }
        totalRewardsOf[_msgSender()] =
            totalRewardsOf[_msgSender()] +
            _xs.length;
        uint256 amount = totalRewardsOf[_msgSender()] -
            claimedRewardsOf[_msgSender()];
        if (amount > 100) {
            claimRewardsFor(_msgSender());
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
        require((xA > 2) && (zA > 2), "the claim is too close to the axis");
        // the first plot has id = 1;
        totalPlots = totalPlots + 1;
        plot_x[totalPlots] = _x;
        plot_z[totalPlots] = _z;
        plotIdOf[_x][_z] = totalPlots;
        // a transfer from 0 indicates a mint;
        _transferPlot(0, _districtId, totalPlots);
        emit PlotCreation(_x, _z, totalPlots);
        return totalPlots;
    }

    /*** admin functions ***/
    // the owner of the contract may claim any unclaimed plot and assign it to any district id
    function adminClaim(
        int128[] calldata _xs,
        int128[] calldata _zs,
        uint256 _districtId
    ) external override onlyOwner {
        require(
            _xs.length == _zs.length,
            "xs and zs array lengths must match!"
        );
        for (uint256 i = 0; i < _xs.length; i++) {
            _claimPlot(_districtId, _xs[i], _zs[i]);
        }
    }

    /*** opensea integration ***/
    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override(ERC721Upgradeable, IERC721Upgradeable)
        returns (bool isOperator)
    {
        // always approve OZ proxy 0x58807baD0B376efc12F5AD86aAc70E78ed67deaE;
        if (_operator == address(0x58807baD0B376efc12F5AD86aAc70E78ed67deaE)) {
            return true;
        }
        return ERC721Upgradeable.isApprovedForAll(_owner, _operator);
    }

    /*** metatransaction logic ***/
    function isTrustedForwarder(address forwarder)
        public
        view
        override
        returns (bool)
    {
        return forwarder == trustedForwarder
    }

    function _msgSender() internal view override returns (address signer) {
        signer = msg.sender;
        if (msg.data.length >= 20 && isTrustedForwarder(signer)) {
            assembly {
                signer := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        }
    }
}
