// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface MARKET {
    struct Creator {
        address creator;
        uint256 feeBasisPoints;
    }

    function getCreatorFeeBasisPoints(address NFTAddress) external view returns (Creator memory);

    function getSalesFee() external view returns (uint256);
}

contract DutchAuction is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds; // Id for each individual item

    address public admin;
    address public feeAddress;
    address public OTMarketAddress = 0xbB5f35D40132A0478f6aa91e79962e9F752167EA;
    uint256 public auctionFeeTFuel;

    constructor() {
        admin = payable(msg.sender);
    }


    struct AuctionItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        uint256 startPrice;
        uint256 endPrice;
        uint256 startTimestamp;
        uint256 endTimestamp;
        address highestBidderAddress;
        uint256 highestBid;
        bool sold;
        address sellerAddress;
    }

    struct Creator {
        address creator;
        uint256 feeBasisPoints;
    }


    mapping(uint256 => AuctionItem) private idToAuctionItem;


    // Event called when a new Item is created
    event DutchAuctionCreated(uint256 indexed itemId, address indexed nftContract, uint256 indexed tokenId,
        uint256 startPrice, uint256 endPrice, uint256 startTimestamp, uint256 endTimestamp, address sellerAddress);

    // Event called when a new Item is updated
    event DutchAuctionUpdated(uint256 indexed itemId, address indexed nftContract, uint256 indexed tokenId,
        uint256 startPrice, uint256 endPrice, uint256 startTimestamp, uint256 endTimestamp, address sellerAddress);

    // Event called when an Item is sold
    event AuctionSold(uint256 indexed itemId, address nftContract, uint256 tokenId,
        uint256 endTimestamp, address indexed bidder, uint256 indexed bid, address seller);

    // Event called when an Item gets canceled
    event AuctionCanceled(uint256 indexed itemId, address nftContract, uint256 tokenId, address indexed receiverAddress);

    // Event called TFuel is spit into creator fee, opentheta fee and payment to seller
    event FeeSplit(uint256 userPayout, address indexed sellerAddress, uint256 feePayout, address indexed feeAddress,
        uint256 creatorPayout, address indexed creatorAddress);


    /**
    * @notice modifiers
    */
    modifier onlyAdmin {
        require(msg.sender == admin, "only the admin can perform this action");
        _;
    }

    /**
    * @notice get auction item by Id. Returns all the information about an auction
    * @param itemId The id of the auction
    * @return all the information stored about the auction in the struct
    */
    function getByAuctionId(uint256 itemId) public view returns (AuctionItem memory){
        require(itemId <= _itemIds.current(), "id doesn't exist");
        return idToAuctionItem[itemId];
    }

    /**
    * @notice get auction item info by Id. Returns all the information about an auction plus the last block timestamp
    * @param itemId The id of the auction
    * @return all the information stored about the auction in the struct, plus block timestamp
    */
    function getInfoByAuctionId(uint256 itemId) public view returns (AuctionItem memory, uint256, uint256){
        require(itemId <= _itemIds.current(), "id doesn't exist");
        return (idToAuctionItem[itemId], getCurrentPrice(itemId), block.timestamp);
    }


    /**
    * @notice calculates the current price of a dutch auction
    * @param itemId the id of the auction
    * @return price calculated by the function
    */
    function getCurrentPrice(uint256 itemId) public view returns (uint256) {
        AuctionItem memory auction = idToAuctionItem[itemId];
        if (block.timestamp < auction.startTimestamp) {
            return auction.startPrice;
        }
        if (block.timestamp > auction.endTimestamp) {
            return auction.endPrice;
        } else {
            // startPrice - (startPrice-endPrice)/(EndTime-StartTime)*(currentTime - Starttime)
            uint256 diffBid = auction.startPrice - auction.endPrice;
            uint256 diffTime = auction.endTimestamp - auction.startTimestamp;
            uint256 res = diffBid / diffTime * (block.timestamp - auction.startTimestamp);
            return auction.startPrice - res;
        }
    }

    /**
    * @notice Buy the NFT directly, this only works in a dutch auction
    * @param itemId the id of the auction
    * @param nftContract the contract address of the auctioned NFT
    */
    function buyNFT(uint256 itemId, address nftContract) external payable nonReentrant {
        AuctionItem memory auction = idToAuctionItem[itemId];
        require(auction.sold == false, "Item sold");
        require(auction.nftContract == nftContract, "contract do not match");
        require(auction.startTimestamp < block.timestamp, "Auction not live");
        require(auction.endTimestamp > block.timestamp, "Auction ended");
        require(getCurrentPrice(itemId) <= msg.value, "not enough TFuel");

        idToAuctionItem[itemId].sold = true;
        idToAuctionItem[itemId].highestBidderAddress = msg.sender;
        idToAuctionItem[itemId].highestBid = msg.value;

        uint256 creatorPayout;
        MARKET.Creator memory creatorData = MARKET(OTMarketAddress).getCreatorFeeBasisPoints(auction.nftContract);
        if (creatorData.creator != address(0x0)) {
            // if creator is set
            creatorPayout = (msg.value / 10000) * creatorData.feeBasisPoints / 100;
            (bool successCreator,) = payable(creatorData.creator).call{value : creatorPayout}("");
            require(successCreator, "Transfer failed.");
        }

        // OpenTheta Fee
        uint256 feePayout = (msg.value / 10000) * MARKET(OTMarketAddress).getSalesFee() / 100;
        (bool successFee,) = payable(feeAddress).call{value : feePayout}("");
        require(successFee, "Transfer to seller failed.");

        // User Payout
        uint256 UserPayout = msg.value - creatorPayout - feePayout;
        (bool successUser,) = payable(auction.sellerAddress).call{value : UserPayout}("");
        require(successUser, "Transfer to seller failed.");

        // Send NFT to highest bidder
        IERC721(auction.nftContract).transferFrom(address(this), msg.sender, auction.tokenId);
        emit FeeSplit(UserPayout, auction.sellerAddress, feePayout, feeAddress, creatorPayout, creatorData.creator);
        emit AuctionSold(itemId, auction.nftContract, auction.tokenId,
            auction.endTimestamp, msg.sender, msg.value, auction.sellerAddress);
    }

    /**
    * @notice create either a dutch auction or a simple auction
    * @param nftContract the contract address of the auctioned NFT
    * @param tokenId token id of the auctioned NFT
    * @param startPrice if bigger then zero, its a Dutch auction and indicates the start price
    * @param endPrice the minimum amount that needs to be bid (simple auction) or the end price of the dutch auction
    * @param startTimestamp indicates when the auction starts
    * @param endTimestamp indicates when the auction ends, has to be higher then startTimestamp and in the future
    */
    function createAuction(address nftContract, uint256 tokenId, uint256 startPrice, uint256 endPrice, uint256 startTimestamp,
        uint256 endTimestamp) external payable {
        require(endPrice > 0, "No item for free here");
        require(endTimestamp > block.timestamp, "Auction can't end in the past");
        require(startTimestamp < endTimestamp, "Can't start after end");
        require(msg.value >= auctionFeeTFuel, "Not the fee amount");
        require(startPrice > endPrice, "Price needs to fall");

        if (auctionFeeTFuel > 0) {
            (bool successFee,) = payable(feeAddress).call{value : msg.value}("");
            require(successFee, "Transfer to seller failed.");
        }

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        idToAuctionItem[itemId] = AuctionItem(
            itemId,
            nftContract,
            tokenId,
            startPrice,
            endPrice,
            startTimestamp,
            endTimestamp,
            payable(address(0)),
            0, // No bid
            false,
            msg.sender
        );

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        emit DutchAuctionCreated(itemId, nftContract, tokenId, startPrice, endPrice, startTimestamp, endTimestamp, msg.sender);
    }

    /**
    * @notice Admin can change the auction parameters as long as it has not sold (even if there was already a bid)
    * @param itemId the id of the auction
    * @param startPrice if bigger then zero, its a Dutch auction and indicates the start price
    * @param endPrice the minimum amount that needs to be bid (simple auction) or the end price of the dutch auction
    * @param startTimestamp indicates when the auction starts
    * @param endTimestamp indicates when the auction ends, has to be higher then startTimestamp and in the future
    */
    function updateAuctionAdmin(uint256 itemId, uint256 startPrice, uint256 endPrice, uint256 startTimestamp,
        uint256 endTimestamp) onlyAdmin external {
        require(idToAuctionItem[itemId].sold == false, "Item sold");
        require(endPrice > 0, "No item for free here");
        require(endTimestamp > block.timestamp, "Auction can end in the past");
        require(startTimestamp < endTimestamp, "Can't start after end");

        idToAuctionItem[itemId].endPrice = endPrice;
        idToAuctionItem[itemId].startPrice = startPrice;
        idToAuctionItem[itemId].startTimestamp = startTimestamp;
        idToAuctionItem[itemId].endTimestamp = endTimestamp;
        emit DutchAuctionUpdated(itemId, idToAuctionItem[itemId].nftContract, idToAuctionItem[itemId].tokenId,
            startPrice, endPrice, startTimestamp, endTimestamp, idToAuctionItem[itemId].sellerAddress);
    }

    /**
    * @notice Creator of the auction can change the auction parameters as long as it has not sold or bid on
    * @param itemId the id of the auction
    * @param startPrice if bigger then zero, its a Dutch auction and indicates the start price
    * @param endPrice the minimum amount that needs to be bid (simple auction) or the end price of the dutch auction
    * @param startTimestamp indicates when the auction starts
    * @param endTimestamp indicates when the auction ends, has to be higher then startTimestamp and in the future
    */
    function updateAuctionUser(uint256 itemId, uint256 startPrice, uint256 endPrice, uint256 startTimestamp,
        uint256 endTimestamp) external {
        require(idToAuctionItem[itemId].sold == false, "Item sold");
        require(endPrice > 0, "No item for free here");
        require(endTimestamp > block.timestamp, "Auction can end in the past");
        require(startTimestamp < endTimestamp, "Can't start after end");

        idToAuctionItem[itemId].endPrice = endPrice;
        idToAuctionItem[itemId].startPrice = startPrice;
        idToAuctionItem[itemId].startTimestamp = startTimestamp;
        idToAuctionItem[itemId].endTimestamp = endTimestamp;
        emit DutchAuctionUpdated(itemId, idToAuctionItem[itemId].nftContract, idToAuctionItem[itemId].tokenId,
            startPrice, endPrice, startTimestamp, endTimestamp, idToAuctionItem[itemId].sellerAddress);
    }

    /**
    * @notice cancel auction by admin, admin can cancel auction that already have bids or ended, but not sold/finalized
    * @param itemId the id of the auction
    */
    function cancelAuctionAdmin(uint256 itemId) onlyAdmin external nonReentrant {
        require(idToAuctionItem[itemId].sold == false, "Item sold");

        idToAuctionItem[itemId].sold = true;
        idToAuctionItem[itemId].endTimestamp = 0;
        idToAuctionItem[itemId].startTimestamp = 0;

        IERC721(idToAuctionItem[itemId].nftContract).transferFrom(address(this), idToAuctionItem[itemId].sellerAddress,
            idToAuctionItem[itemId].tokenId);
        emit AuctionCanceled(itemId, idToAuctionItem[itemId].nftContract, idToAuctionItem[itemId].tokenId,
            idToAuctionItem[itemId].sellerAddress);
    }

    /**
    * @notice cancel auction by user, only the creator can cancel an auction if it has no bids yet
    * @param itemId the id of the auction
    */
    function cancelAuctionUser(uint256 itemId) external nonReentrant {
        require(idToAuctionItem[itemId].sold == false, "Item sold");
        require(msg.sender == idToAuctionItem[itemId].sellerAddress, "Only creator can cancel");

        idToAuctionItem[itemId].sold = true;
        idToAuctionItem[itemId].endTimestamp = 0;
        idToAuctionItem[itemId].startTimestamp = 0;

        IERC721(idToAuctionItem[itemId].nftContract).transferFrom(address(this), idToAuctionItem[itemId].sellerAddress,
            idToAuctionItem[itemId].tokenId);
        emit AuctionCanceled(itemId, idToAuctionItem[itemId].nftContract, idToAuctionItem[itemId].tokenId,
            idToAuctionItem[itemId].sellerAddress);
    }

    /**
    * @notice finishAuction settles the auction. If it has a bid the bidder gets the NFT and the seller the TFuel minus the fees.
    * if it has no bids, the seller gets the NFT returned to his wallet.
    * @param itemId the id of the auction
    */
    function endAuction(uint256 itemId) external nonReentrant {
        AuctionItem memory auction = idToAuctionItem[itemId];
        require(auction.endTimestamp < block.timestamp, "Auction can end in the past");
        require(auction.sold == false, "Item sold");
        idToAuctionItem[itemId].sold = true;
        // send NFT back to User
        IERC721(auction.nftContract).transferFrom(address(this), auction.sellerAddress, auction.tokenId);
        emit AuctionSold(itemId, auction.nftContract, auction.tokenId, auction.endTimestamp,
            auction.highestBidderAddress, auction.highestBid, auction.sellerAddress);
    }

    /**
    * @notice Change the fee address
     * @param feeAddress_ The address of the new fee address
     */
    function setFeeAddress(address feeAddress_) onlyAdmin external {
        feeAddress = feeAddress_;
    }

    /**
    * @notice Change the opentheta market address to get the sales and creator fee
    * @param marketAddress The address of the new marketplace
    */
    function setOTMarketAddress(address marketAddress) onlyAdmin external {
        OTMarketAddress = marketAddress;
    }

    /**
    * @notice Change auctionFee that is payed to create a new auction
     * @param auctionFeeTFuel_ The amount to pay
     */
    function setAuctionFeeTFuel(uint256 auctionFeeTFuel_) onlyAdmin external {
        auctionFeeTFuel = auctionFeeTFuel_;
    }

    /**
     * @notice Change the admin address
     * @param admin_ The address of the new admin
     */
    function setAdmin(address admin_) onlyAdmin external {
        admin = admin_;
    }
}