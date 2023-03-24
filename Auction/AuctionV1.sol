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

contract Auctions is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds; // Id for each individual item

    address public admin;
    address public feeAddress;
    address public OTMarketAddress = 0xbB5f35D40132A0478f6aa91e79962e9F752167EA;
    uint256 auctionFeeTFuel;

    enum AuctionType{SIMPLE, DUTCH}

    constructor() {
        admin = payable(msg.sender);
    }


    struct AuctionItem {
        uint256 itemId;
        AuctionType auctionType;
        address nftContract;
        uint256 tokenId;
        uint256 maxBid;
        uint256 minBid;
        uint256 startTimestamp;
        uint256 endTimestamp;
        address highestBidderAddress;
        uint256 highestBid;
        bool sold;
        address userAddress;
    }

    struct Creator {
        address creator;
        uint256 feeBasisPoints;
    }


    mapping(uint256 => AuctionItem) private idToAuctionItem;


    // Event called when a new Item is created
    event SimpleAuctionCreated(uint256 indexed itemId, address indexed nftContract, uint256 indexed tokenId,
        uint256 minBid, uint256 startTimestamp, uint256 endTimestamp, address userAddress);

    event DutchAuctionCreated(uint256 indexed itemId, address indexed nftContract, uint256 indexed tokenId,
        uint256 maxBid, uint256 minBid, uint256 startTimestamp, uint256 endTimestamp, address userAddress);

    // Event called when a new Item is updated
    event SimpleAuctionUpdated(uint256 indexed itemId, address indexed nftContract, uint256 indexed tokenId,
        uint256 minBid, uint256 startTimestamp, uint256 endTimestamp, address userAddress);

    event DutchAuctionUpdated(uint256 indexed itemId, address indexed nftContract, uint256 indexed tokenId,
        uint256 maxBid, uint256 minBid, uint256 startTimestamp, uint256 endTimestamp, address userAddress);

    // Event called when an Item is sold
    event AuctionSold(uint256 indexed itemId, address nftContract, uint256 tokenId,
        uint256 endTimestamp, address indexed bidder, uint256 indexed bid, address seller);

    // Event called when an Item gets canceled
    event AuctionCanceled(uint256 indexed itemId, address nftContract, uint256 tokenId, address indexed receiverAddress);

    // Event when someone places a bid
    event BidPlaced(uint256 indexed itemId, address nftContract, uint256 tokenId, address indexed bidder,
        uint256 indexed bid);

    // Event called TFuel is spit into creator fee, opentheta fee and payment to seller
    event FeeSplit(uint256 userPayout, address indexed userAddress, uint256 feePayout, address indexed feeAddress,
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
    * @param id The id of the auction
    * @return all the information stored about the auction in the struct
    */
    function getByAuctionId(uint256 id) public view returns (AuctionItem memory){
        require(id <= _itemIds.current(), "id doesn't exist");
        return idToAuctionItem[id];
    }

    // currentTimestamp, alle infos, currentPrice

    /**
    * @notice Returns the amount of TFuel is charged to create an auction
    * @return actionFeeTFuel what the fee in TFuel is to create an auction
    */
    function getAuctionFeeTFuel() public view returns (uint256){
        return auctionFeeTFuel;
    }

    /**
    * @notice place a bid in an auction Todo: Differenz 1 TFuel
    * @param itemId the id of the auction
    * @param nftContract the contract address of the auctioned NFT
    */
    function placeBid(uint256 itemId, address nftContract) external payable nonReentrant {
        require(idToAuctionItem[itemId].sold == false, "Item sold");
        require(idToAuctionItem[itemId].nftContract == nftContract, "contract do not match");
        require(idToAuctionItem[itemId].auctionType == AuctionType.SIMPLE, "Only for simple auction available");
        require(idToAuctionItem[itemId].startTimestamp < block.timestamp, "Auction not live");
        require(idToAuctionItem[itemId].endTimestamp > block.timestamp, "Auction ended");
        require(msg.value >= idToAuctionItem[itemId].minBid, "Bid smaller minBid");
        require(msg.value > idToAuctionItem[itemId].highestBid, "Bid smaller highest Bid");

        address lastBidder = idToAuctionItem[itemId].highestBidderAddress;
        uint256 lastBid = idToAuctionItem[itemId].highestBid;
        idToAuctionItem[itemId].highestBid = msg.value;
        idToAuctionItem[itemId].highestBidderAddress = msg.sender;
        // payback previous highest bidder
        if (lastBid > 0) {
            (bool success,) = payable(lastBidder).call{value : lastBid}("");
            require(success, "Transfer to seller failed.");
        }
        emit BidPlaced(itemId, nftContract, idToAuctionItem[itemId].tokenId, msg.sender, msg.value);
    }

    /**
    * @notice calculates the current price of a dutch auction
    * @param itemId the id of the auction
    * @return price calculated by the function
    */
    function getCurrentPrice(uint256 itemId) public view returns (uint256) {
        AuctionItem memory auction = idToAuctionItem[itemId];
        require(auction.auctionType == AuctionType.DUTCH, "Only for Dutch auctions");
        if (block.timestamp < auction.startTimestamp) {
            return auction.maxBid;
        }
        if (block.timestamp > auction.endTimestamp) {
            return auction.minBid;
        } else {
            // maxBid - (maxBid-MinBid)/(EndTime-StartTime)*(currentTime - Starttime)
            uint256 diffBid = auction.maxBid - auction.minBid;
            uint256 diffTime = auction.endTimestamp - auction.startTimestamp;
            uint256 res = diffBid / diffTime * (block.timestamp - auction.startTimestamp);
            return auction.maxBid - res;
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
        require(auction.auctionType == AuctionType.DUTCH, "Only for dutch auction available");
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
        (bool successUser,) = payable(auction.userAddress).call{value : UserPayout}("");
        require(successUser, "Transfer to seller failed.");

        // Send NFT to highest bidder
        IERC721(auction.nftContract).transferFrom(address(this), msg.sender, auction.tokenId);
        emit FeeSplit(UserPayout, auction.userAddress, feePayout, feeAddress, creatorPayout, creatorData.creator);
        emit AuctionSold(itemId, auction.nftContract, auction.tokenId,
            auction.endTimestamp, msg.sender, msg.value, auction.userAddress);
    }

    /**
    * @notice create either a dutch auction or a simple auction
    * @param nftContract the contract address of the auctioned NFT
    * @param tokenId token id of the auctioned NFT
    * @param maxBid if bigger then zero, its a Dutch auction and indicates the start price
    * @param minBid the minimum amount that needs to be bid (simple auction) or the end price of the dutch auction
    * @param startTimestamp indicates when the auction starts
    * @param endTimestamp indicates when the auction ends, has to be higher then startTimestamp and in the future
    */
    function createAuction(address nftContract, uint256 tokenId, uint256 maxBid, uint256 minBid, uint256 startTimestamp,
        uint256 endTimestamp) external payable {
        require(minBid > 0, "No item for free here");
        require(endTimestamp > block.timestamp, "Auction can't end in the past");
        require(startTimestamp < endTimestamp, "Can't start after end");
        require(msg.value >= auctionFeeTFuel, "Not the fee amount");

        if (auctionFeeTFuel > 0) {
            (bool successFee,) = payable(feeAddress).call{value : msg.value}("");
            require(successFee, "Transfer to seller failed.");
        }

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        if (maxBid == 0) {
            idToAuctionItem[itemId] = AuctionItem(
                itemId,
                AuctionType.SIMPLE,
                nftContract,
                tokenId,
                maxBid,
                minBid,
                startTimestamp,
                endTimestamp,
                payable(address(0)),
                0, // No bid
                false,
                msg.sender
            );
            IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
            emit SimpleAuctionCreated(itemId, nftContract, tokenId, minBid, startTimestamp, endTimestamp, msg.sender);
        } else {
            require(maxBid > minBid, "Price needs to fall");
            idToAuctionItem[itemId] = AuctionItem(
                itemId,
                AuctionType.DUTCH,
                nftContract,
                tokenId,
                maxBid,
                minBid,
                startTimestamp,
                endTimestamp,
                payable(address(0)),
                0, // No bid
                false,
                msg.sender
            );
            IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
            emit DutchAuctionCreated(itemId, nftContract, tokenId, maxBid, minBid, startTimestamp, endTimestamp, msg.sender);
        }
    }

    /**
    * @notice Admin can change the auction parameters as long as it has not sold (even if there was already a bid)
    * @param itemId the id of the auction
    * @param maxBid if bigger then zero, its a Dutch auction and indicates the start price
    * @param minBid the minimum amount that needs to be bid (simple auction) or the end price of the dutch auction
    * @param startTimestamp indicates when the auction starts
    * @param endTimestamp indicates when the auction ends, has to be higher then startTimestamp and in the future
    */
    function updateAuctionAdmin(uint256 itemId, uint256 maxBid, uint256 minBid, uint256 startTimestamp,
        uint256 endTimestamp) onlyAdmin external {
        require(idToAuctionItem[itemId].sold == false, "Item sold");
        require(minBid > 0, "No item for free here");
        require(endTimestamp > block.timestamp, "Auction can end in the past");
        require(startTimestamp < endTimestamp, "Can't start after end");

        if (maxBid == 0) {
            idToAuctionItem[itemId].minBid = minBid;
            idToAuctionItem[itemId].maxBid = maxBid;
            idToAuctionItem[itemId].startTimestamp = startTimestamp;
            idToAuctionItem[itemId].endTimestamp = endTimestamp;
            emit SimpleAuctionUpdated(itemId, idToAuctionItem[itemId].nftContract, idToAuctionItem[itemId].tokenId,
                minBid, startTimestamp, endTimestamp, idToAuctionItem[itemId].userAddress);
        } else {
            idToAuctionItem[itemId].minBid = minBid;
            idToAuctionItem[itemId].maxBid = maxBid;
            idToAuctionItem[itemId].startTimestamp = startTimestamp;
            idToAuctionItem[itemId].endTimestamp = endTimestamp;
            emit DutchAuctionUpdated(itemId, idToAuctionItem[itemId].nftContract, idToAuctionItem[itemId].tokenId,
                maxBid, minBid, startTimestamp, endTimestamp, idToAuctionItem[itemId].userAddress);
        }
    }

    /**
    * @notice Creator of the auction can change the auction parameters as long as it has not sold or bid on
    * @param itemId the id of the auction
    * @param maxBid if bigger then zero, its a Dutch auction and indicates the start price
    * @param minBid the minimum amount that needs to be bid (simple auction) or the end price of the dutch auction
    * @param startTimestamp indicates when the auction starts
    * @param endTimestamp indicates when the auction ends, has to be higher then startTimestamp and in the future
    */
    function updateAuctionUser(uint256 itemId, uint256 maxBid, uint256 minBid, uint256 startTimestamp,
        uint256 endTimestamp) external {
        require(idToAuctionItem[itemId].sold == false, "Item sold");
        require(minBid > 0, "No item for free here");
        require(idToAuctionItem[itemId].highestBid == 0, "First bid already placed");
        require(endTimestamp > block.timestamp, "Auction can end in the past");
        require(startTimestamp < endTimestamp, "Can't start after end");

        if (maxBid == 0) {
            idToAuctionItem[itemId].minBid = minBid;
            idToAuctionItem[itemId].maxBid = maxBid;
            idToAuctionItem[itemId].startTimestamp = startTimestamp;
            idToAuctionItem[itemId].endTimestamp = endTimestamp;
            emit SimpleAuctionUpdated(itemId, idToAuctionItem[itemId].nftContract, idToAuctionItem[itemId].tokenId,
                minBid, startTimestamp, endTimestamp, idToAuctionItem[itemId].userAddress);
        } else {
            idToAuctionItem[itemId].minBid = minBid;
            idToAuctionItem[itemId].maxBid = maxBid;
            idToAuctionItem[itemId].startTimestamp = startTimestamp;
            idToAuctionItem[itemId].endTimestamp = endTimestamp;
            emit DutchAuctionUpdated(itemId, idToAuctionItem[itemId].nftContract, idToAuctionItem[itemId].tokenId,
                maxBid, minBid, startTimestamp, endTimestamp, idToAuctionItem[itemId].userAddress);
        }
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
        // payback previous highest bidder
        if (idToAuctionItem[itemId].highestBid > 0) {
            (bool success,) = payable(idToAuctionItem[itemId].highestBidderAddress).call{value : idToAuctionItem[itemId].highestBid}("");
            require(success, "Transfer to seller failed.");
            idToAuctionItem[itemId].highestBidderAddress = address(0);
            idToAuctionItem[itemId].highestBid = 0;
        }
        IERC721(idToAuctionItem[itemId].nftContract).transferFrom(address(this), idToAuctionItem[itemId].userAddress,
            idToAuctionItem[itemId].tokenId);
        emit AuctionCanceled(itemId, idToAuctionItem[itemId].nftContract, idToAuctionItem[itemId].tokenId,
            idToAuctionItem[itemId].userAddress);
    }

    /**
    * @notice cancel auction by user, only the creator can cancel an auction if it has no bids yet
    * @param itemId the id of the auction
    */
    function cancelAuctionUser(uint256 itemId) external nonReentrant {
        require(idToAuctionItem[itemId].sold == false, "Item sold");
        require(msg.sender == idToAuctionItem[itemId].userAddress, "Only creator can cancel");
        require(idToAuctionItem[itemId].highestBid == 0, "Action already started");
        idToAuctionItem[itemId].sold = true;
        idToAuctionItem[itemId].endTimestamp = 0;
        idToAuctionItem[itemId].startTimestamp = 0;
        IERC721(idToAuctionItem[itemId].nftContract).transferFrom(address(this), idToAuctionItem[itemId].userAddress,
            idToAuctionItem[itemId].tokenId);
        emit AuctionCanceled(itemId, idToAuctionItem[itemId].nftContract, idToAuctionItem[itemId].tokenId,
            idToAuctionItem[itemId].userAddress);
    }

    /**
    * @notice finishAuction settles the auction. If it has a bid the bidder gets the NFT and the seller the TFuel minus the fees.
    * if it has no bids, the seller gets the NFT returned to his wallet.
    * @param itemId the id of the auction
    */
    function finishAuction(uint256 itemId) external nonReentrant {
        AuctionItem memory auction = idToAuctionItem[itemId];
        require(auction.endTimestamp < block.timestamp, "Auction can end in the past");
        require(auction.sold == false, "Item sold");
        idToAuctionItem[itemId].sold = true;
        if (auction.highestBid > 0) {
            // Get Creator Fee
            uint256 creatorPayout;
            MARKET.Creator memory creatorData = MARKET(OTMarketAddress).getCreatorFeeBasisPoints(auction.nftContract);
            if (creatorData.creator != address(0x0)) {
                // if creator is set
                creatorPayout = (auction.highestBid / 10000) * creatorData.feeBasisPoints / 100;
                (bool successCreator,) = payable(creatorData.creator).call{value : creatorPayout}("");
                require(successCreator, "Transfer failed.");
            }
            // OpenTheta Fee
            uint256 feePayout = (auction.highestBid / 10000) * MARKET(OTMarketAddress).getSalesFee() / 100;
            (bool successFee,) = payable(feeAddress).call{value : feePayout}("");
            require(successFee, "Transfer to seller failed.");
            // User Payout
            uint256 UserPayout = auction.highestBid - creatorPayout - feePayout;
            (bool successUser,) = payable(auction.userAddress).call{value : UserPayout}("");
            require(successUser, "Transfer to seller failed.");
            // Send NFT to highest bidder
            IERC721(auction.nftContract).transferFrom(address(this), auction.highestBidderAddress, auction.tokenId);
            emit FeeSplit(UserPayout, auction.userAddress, feePayout, feeAddress, creatorPayout, creatorData.creator);
            emit AuctionSold(itemId, auction.nftContract, auction.tokenId, auction.endTimestamp,
                auction.highestBidderAddress, auction.highestBid, auction.userAddress);
        } else {
            // send NFT back to User
            IERC721(auction.nftContract).transferFrom(address(this), auction.userAddress, auction.tokenId);
            emit AuctionSold(itemId, auction.nftContract, auction.tokenId, auction.endTimestamp,
                auction.highestBidderAddress, auction.highestBid, auction.userAddress);
        }
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