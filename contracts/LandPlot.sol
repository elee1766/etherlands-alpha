//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./_external/openzeppelin-upgradable/token/ERC721/ERC721Upgradeable.sol";
import "./_external/openzeppelin-upgradable/access/OwnableUpgradeable.sol";
import "./_external/openzeppelin-upgradable/proxy/utils/Initializable.sol";

// @title Upgradable Minecraft LandPlot NFT
// @author elee
contract LandPlot is ERC721Upgradeable, OwnableUpgradeable {

  // mapping from token id to enabled state
  mapping(uint256 => bool) private enabled;
  // mapping from tokenid to x chunk coordinate;
  mapping(uint256 => int128) public chunk_x;
  // mapping from tokenid to z chunk coordinate;
  mapping(uint256 => int128) public chunk_z;
  // mapping from x to y to bool to see if it is owned already;
  mapping(int128=> mapping(int128 => uint256)) public _owned;


  // prices for plots based on distance - curve is calculated off chain
  uint256[] public _plotPrices;
  uint256[] public _plotPriceDistances;

  // This is the amount of chunks currently claimed
  uint256 public _worldSize;

  // This is the max chunk coordinate of any claimable chunk
  // e.g. if the limit is 10, the user can mint nfts from -9,-9 to 9,9
  uint128 public _worldLimit;

  bool public _claimAvailable;

  function initialize(string memory name, string memory symbol) public initializer{
    ERC721Upgradeable.__ERC721_init(name, symbol);
    OwnableUpgradeable.__Ownable_init();
    ERC721Upgradeable._safeMint(msg.sender,0); // mint the 0 id NFT to the contract

    _worldSize = 1; // NFT id=0 is a reference to an unbought chunk
    _worldLimit = 2000; //the world is 4000x4000 chunks, or 64000x64000 blocks
    _claimAvailable = false; // purchases are not initially available
  }

  // @notice claim chunks
  // @dev you must send enough wei to pay for all chunks
  // @dev the length of xs and zs must match
  // @param xs array of x chunk coordinates to match with zs
  // @param zs array of z chunk coordinates to match with xs
  function claimLands(int128[] memory xs, int128[] memory zs) external payable {
    require(_claimAvailable, "claiming is currently disabled");
    require(xs.length <= 128, "cannot claim more than 128 chunks at a time!");
    require(xs.length == zs.length, "xs and zs array lengths must match!");
    uint256 total_cost = 0;
    for(uint256 i = 0; i < xs.length; i++){
        require(_owned[xs[i]][zs[i]] == 0, "attempting to claim already claimed land");
        genesisMint(msg.sender,xs[i],zs[i]);
        total_cost = total_cost + calculateLandCost(xs[i],zs[i]);
    }
    require(msg.value >= total_cost, "not enough eth sent to purchase land");
    uint256 change = 0;
    if(msg.value > total_cost){
      change = msg.value - total_cost;
      payable(msg.sender).transfer(change);
    }
  }

  // @param prices An array of prices in wei which correspond to a matching distance, eg [10000000000000,1000000,10000,100,...]
  // @param distances An array of distances in chunks which correspond to a matching price, eg [10,100,700,800,...]
  function admin_set_plot_costs(uint256[] memory prices, uint256[] memory distances) external onlyOwner {
    require(prices.length == distances.length);
    _plotPrices = prices;
    _plotPriceDistances = distances;
  }

  // @param world_limit as an uint128
  function admin_set_world_limit(uint128 world_limit) external onlyOwner {
    require(world_limit > 0, "World limit must be > 0");
    _worldLimit = world_limit;
  }

  // @param available Boolean flag on whether or not people can claim land
  function admin_set_claim_status(bool available) external onlyOwner{
    _claimAvailable = available;
  }

  // @notice the contract owner may mint any nft for anybody
  // @param recv address which will receive the nft
  // @param xs array of x chunk coordinate that the nfts will correspond to
  // @param zs array of z chunk coordinate that the nfts will correspond to
  function mintMany(address recv, int128[] memory xs, int128[] memory zs) external onlyOwner {
    require(xs.length == zs.length, "xs and ys coordinate count must match");
    for(uint256 i = 0; i < xs.length; i++){
        require(_owned[xs[i]][zs[i]] == 0, "plot already minted");
        mintOne(recv,xs[i],zs[i]);
    }
  }

  // @notice the contract owner may mint any nft for anybody
  // @param recv address which will receive the nft
  // @param x x chunk coordinate that the nft will correspond to
  // @param z z chunk coordinate that the nft will correspond to
  function mintOne(address recv, int128 x, int128 z) public onlyOwner {
    genesisMint(recv,x,z);
  }

  // @notice get the chunk coordinates of which nft with id tokenId has jusrisdiction over
  // @param tokenId id of the nft
  // @returns (int128,int128) corresponding to the chunk with chunk coordinates (x,z);
  function getClaimInfo(uint256 tokenId) public view returns (int128,int128){
    return (chunk_x[tokenId],chunk_z[tokenId]);
  }

  //@notice get the claim that has jusrisdiction over chunk x,z
  //@param x x chunk coordinate
  //@param z z chunk coordinate
  //@returns uint256 id of nft. if nft id == 0, then the land is unclaimed;
  function getChunkClaim(int128 x, int128 z) public view returns (uint256){
    return _owned[x][z];
  }

  // @param x x chunk coordinate of the plot
  // @param z z chunk coordinate of the plot
  // @return price in wei as uin256
  function calculateLandCost(int128 x, int128 z) public view returns (uint256 price){
    uint128 xA = uint128(x >= 0 ? x : -x);
    uint128 zA = uint128(z >= 0 ? z : -z);
    uint128 min = (xA < zA ? xA : zA);
    price = 0;
    for(uint256 i = 0; i < _plotPrices.length; i++){
      if(min > _plotPriceDistances[i]){
        price = _plotPrices[i];
      }
    }
  }

  // @dev this is the function that actually mints the nft
  // @param recv address which will receive the nft
  // @param x x chunk coordinate that the nft will correspond to
  // @param z z chunk coordinate that the nft will correspond to
  function genesisMint(address recv, int128 x, int128 z) private {
    uint128 xA = uint128(x >= 0 ? x : -x);
    uint128 zA = uint128(z >= 0 ? z : -z);
    require((_worldLimit > xA) && (_worldLimit > zA),"the claim is beyond the specified world limit");
    _worldSize = _worldSize + 1;
    ERC721Upgradeable._safeMint(recv, _worldSize);
    chunk_x[_worldSize] = x;
    chunk_z[_worldSize] = z;
    _owned[x][z] = _worldSize;
  }
}
