//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import "./interfaces/IMarketplace.sol";

/// @title Upgradable Auction House
/// @author icpigci
contract Marketplace is
    IMarketplace,
    ERC721HolderUpgradeable,
    ReentrancyGuardUpgradeable
{
    /*** Storage Properties ***/
    struct Auction {
        // auction creator
        address creator;
        // auction token info
        address token;
        uint256[] tokenIds;
        // auction end block number
        uint256 endBlock;
        // auction bid status
        address bidder;
        uint256 bidAmount;
        // auction status
        AuctionStatus status;
    }
    Auction[] private auctions;

    struct Purchase {
        // purchaser
        address purchaser;
        // token info
        address token;
        uint256 tokenId;
        // bid amount
        uint256 bidAmount;
        // purchase expire at
        uint256 expireAt;
        // purchase status
        PurchaseStatus status;
    }
    Purchase[] private purchases;

    /*** Contract Logic Starts Here */

    function initialize() public initializer {
        __ERC721Holder_init();
        __ReentrancyGuard_init();
    }

    /// @notice get auction info
    /// @param _auctionId the auction id
    function getAuctionInfo(uint256 _auctionId)
        external
        view
        override
        returns (
            address creator,
            address token,
            uint256[] memory tokenIds,
            uint256 endBlock,
            address bidder,
            uint256 bidAmount,
            AuctionStatus status
        )
    {
        require(_auctionId < auctions.length, "invalid auction id");

        Auction memory auction = auctions[_auctionId];

        status = auction.status;
        if (
            status == AuctionStatus.Started && block.number > auction.endBlock
        ) {
            status = AuctionStatus.Finished;
        }

        return (
            auction.creator,
            auction.token,
            auction.tokenIds,
            auction.endBlock,
            auction.bidder,
            auction.bidAmount,
            status
        );
    }

    /// @notice get purchase info
    /// @param _purchaseId the purchase id
    function getPurchaseInfo(uint256 _purchaseId)
        external
        view
        override
        returns (
            address purchaser,
            address token,
            uint256 tokenId,
            uint256 bidAmount,
            uint256 expireAt,
            PurchaseStatus status
        )
    {
        require(_purchaseId < purchases.length, "invalid auction id");

        Purchase memory purchase = purchases[_purchaseId];

        status = purchase.status;
        if (
            status == PurchaseStatus.Started &&
            block.timestamp > purchase.expireAt
        ) {
            status = PurchaseStatus.Expired;
        }

        return (
            purchase.purchaser,
            purchase.token,
            purchase.tokenId,
            purchase.bidAmount,
            purchase.expireAt,
            status
        );
    }

    /// @notice create a new auction with one token
    /// @dev user can place any number of tokens as a bundle
    /// @param _token the ERC721 token address
    /// @param _tokenId the tokenId for auction
    /// @param _period the auction period - block number
    function createAuction(
        address _token,
        uint256 _tokenId,
        uint256 _period
    ) external override {
        ERC721Upgradeable(_token).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _tokenId;

        auctions.push(
            Auction(
                msg.sender,
                _token,
                tokenIds,
                block.number + _period,
                address(0),
                0,
                AuctionStatus.Started
            )
        );
    }

    /// @notice create a new auction with one token
    /// @dev user can place any number of tokens as a bundle
    /// @param _token the ERC721 token address
    /// @param _tokenIds the tokenIds for auction
    /// @param _period the auction period
    function createAuctionWithMultipleTokens(
        address _token,
        uint256[] memory _tokenIds,
        uint256 _period
    ) external override {
        require(_tokenIds.length > 0, "empty tokenId array");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            ERC721Upgradeable(_token).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenIds[i]
            );
        }

        auctions.push(
            Auction(
                msg.sender,
                _token,
                _tokenIds,
                block.number + _period,
                address(0),
                0,
                AuctionStatus.Started
            )
        );
    }

    /// @notice cancel auction
    /// @param _auctionId the auction id
    function cancelAuction(uint256 _auctionId) external override nonReentrant {
        require(_auctionId < auctions.length, "invalid auction id");

        Auction memory auction = auctions[_auctionId];
        require(msg.sender == auction.creator, "not auction creator");
        require(
            auction.status == AuctionStatus.Started &&
                (block.number <= auction.endBlock ||
                    auction.bidder == address(0)),
            "auction finished"
        );

        auctions[_auctionId].bidder = address(0);
        auctions[_auctionId].bidAmount = 0;
        auctions[_auctionId].status = AuctionStatus.Canceled;

        // return NFT
        for (uint256 i = 0; i < auction.tokenIds.length; i++) {
            ERC721Upgradeable(auction.token).safeTransferFrom(
                address(this),
                msg.sender,
                auction.tokenIds[i]
            );
        }

        if (auction.bidder != address(0)) {
            // return eth
            payable(auction.bidder).transfer(auction.bidAmount);
        }
    }

    /// @notice bid on the auction
    /// @param _auctionId the auction id
    function bid(uint256 _auctionId) external payable override nonReentrant {
        require(_auctionId < auctions.length, "invalid auction id");

        Auction memory auction = auctions[_auctionId];
        require(msg.value > auction.bidAmount, "less than current bid amount");
        require(
            block.number <= auction.endBlock &&
                auction.status == AuctionStatus.Started,
            "auction finished"
        );

        auctions[_auctionId].bidder = msg.sender;
        auctions[_auctionId].bidAmount = msg.value;

        if (auction.bidder != address(0)) {
            // return eth
            payable(auction.bidder).transfer(auction.bidAmount);
        }
    }

    /// @notice claim after auction finished
    /// @param _auctionId the auction id
    function claim(uint256 _auctionId) external override nonReentrant {
        require(_auctionId < auctions.length, "invalid auction id");

        Auction memory auction = auctions[_auctionId];
        require(block.number > auction.endBlock, "auction not finished");
        require(msg.sender == auction.bidder, "not winner");
        require(auction.status == AuctionStatus.Started, "auction finished");

        auctions[_auctionId].status = AuctionStatus.Claimed;

        // pay eth to nft owner
        payable(auction.creator).transfer(auction.bidAmount);

        // return NFT to bidder
        for (uint256 i = 0; i < auction.tokenIds.length; i++) {
            ERC721Upgradeable(auction.token).safeTransferFrom(
                address(this),
                auction.bidder,
                auction.tokenIds[i]
            );
        }
    }

    /// @notice create a purchase for a token
    /// @param _token the ERC721 token address
    /// @param _tokenId the tokenId for auction
    /// @param _period the auction period - timestamp
    function createPurchase(
        address _token,
        uint256 _tokenId,
        uint256 _period
    ) external payable override {
        purchases.push(
            Purchase(
                msg.sender,
                _token,
                _tokenId,
                msg.value,
                block.timestamp + _period,
                PurchaseStatus.Started
            )
        );
    }

    /// @notice cancel purchase
    /// @param _purchaseId the purchase id
    function cancelPurchase(uint256 _purchaseId)
        external
        override
        nonReentrant
    {
        require(_purchaseId < purchases.length, "invalid purchase id");

        Purchase memory purchase = purchases[_purchaseId];
        require(msg.sender == purchase.purchaser, "not purchaser");
        require(purchase.status == PurchaseStatus.Started, "purchase finished");

        purchases[_purchaseId].status = PurchaseStatus.Canceled;

        // return eth
        payable(purchase.purchaser).transfer(purchase.bidAmount);
    }

    /// @notice accept purchase
    /// @param _purchaseId the purchase id
    function accept(uint256 _purchaseId) external override nonReentrant {
        require(_purchaseId < purchases.length, "invalid purchase id");

        Purchase memory purchase = purchases[_purchaseId];
        require(block.timestamp <= purchase.expireAt, "purchase expired");
        require(purchase.status == PurchaseStatus.Started, "purchase finished");

        purchases[_purchaseId].status = PurchaseStatus.Accepted;

        // transfer NFT to purchaser
        ERC721Upgradeable(purchase.token).transferFrom(
            msg.sender,
            purchase.purchaser,
            purchase.tokenId
        );

        // pay eth to NFT owner
        payable(msg.sender).transfer(purchase.bidAmount);
    }
}
