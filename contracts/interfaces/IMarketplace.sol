//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

/// @title Upgradable Auction House Interface
/// @author icpigci
interface IMarketplace {
    // enumerations
    enum AuctionStatus {
        Started,
        Canceled,
        Finished,
        Claimed
    }

    enum PurchaseStatus {
        Started,
        Canceled,
        Expired,
        Accepted
    }

    // functions
    function getAuctionInfo(uint256 _auctionId)
        external
        view
        returns (
            address creator,
            address token,
            uint256[] memory tokenIds,
            uint256 endBlock,
            bool extendable,
            address bidder,
            uint256 bidAmount,
            AuctionStatus status
        );

    function getPurchaseInfo(uint256 _purchaseId)
        external
        view
        returns (
            address purchaser,
            address token,
            uint256 tokenId,
            uint256 bidAmount,
            uint256 expireAt,
            PurchaseStatus status
        );

    function createAuction(
        address _token,
        uint256 _tokenId,
        uint256 _period,
        bool _extendable
    ) external;

    function createAuctionWithMultipleTokens(
        address _token,
        uint256[] memory _tokenIds,
        uint256 _period,
        bool _extendable
    ) external;

    function extendAuction(uint256 _auctionId, uint256 _period) external;

    function cancelAuction(uint256 _auctionId) external;

    function bid(uint256 _auctionId) external payable;

    function claim(uint256 _auctionId) external;

    function createPurchase(
        address _token,
        uint256 _tokenId,
        uint256 _period
    ) external payable;

    function cancelPurchase(uint256 _purchaseId) external;

    function accept(uint256 _purchaseId) external;
}
