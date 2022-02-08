// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract OpenThetaNFTMarket is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds; // Id for each individual item
    Counters.Counter private _itemsSold; // Number of items sold

    /// @notice The super admin address / owner
    address public superAdmin;

    /// @notice The admin address
    address public admin;

    address public feeAddress;

    uint256 salesFeeBasisPoints = 400;
    bool public listingIsActive = true;
    bool public tiersAreActive = false;
    address public WTFuel;
    address public openThetaToken;

    struct Tier {
        uint256 tokenBalance;
        uint marketFeeMultiplierSale;
        uint creatorFeeMultiplierSale;
        uint marketFeeMultiplierOffer;
        uint creatorFeeMultiplierOffer;
    }

    Tier[3] public sellerTiers;

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 highestOffer;
        address bidder;
        string category;
        uint256 price;
        bool isSold;
    }

    struct Creator {
        address creator;
        uint256 feeBasisPoints;
    }

    //    mapping that keeps all items ever placed on the marketplace
    mapping(uint256 => MarketItem) private idToMarketItem;

    //    mapping NFT address to creators address
    mapping(address => Creator) private AddressToCreatorFeeItem;




    constructor(address feeAddress_, address WTFuelAddress) {
        superAdmin = payable(msg.sender);
        feeAddress = payable(feeAddress_);
        WTFuel = WTFuelAddress;
    }

    fallback() payable external {}

    receive() external payable {}


    // Event called when a new Item is created
    event MarketItemCreated(uint256 indexed itemId, address indexed nftContract, uint256 tokenId,
        address indexed seller, address owner, string category, uint256 price, bool isSold);

    // Event called when a new Item is updated
    event MarketItemUpdated(uint256 indexed itemId, address indexed nftContract, uint256 tokenId,
        address indexed seller, address owner, string category, uint256 price, bool isSold);

    // Event called when an Item is sold
    event MarketItemSale(uint256 indexed itemId, address nftContract, uint256 tokenId, address indexed seller,
        address indexed owner, string category, uint256 price, bool isSold);

    // Event when someone places a offer
    event OfferPlaced(uint256 indexed itemId, address nftContract, uint256 tokenId, address indexed seller,
        uint256 highestOffer, address indexed bidder, string category, uint256 price);

    // Event when someone cancels a offer
    event OfferCanceled(uint256 indexed itemId, address nftContract, uint256 tokenId, address indexed seller,
        address indexed previousBidder, uint256 price);

    // Event called TFuel is spit into creator fee, opentheta fee and payment to seller
    event FeeSplit(uint256 userPayout, address indexed userAddress, uint256 feePayout, address indexed feeAddress,
        uint256 creatorPayout, address indexed creatorAddress);

    // Event called when creator base fee points are changed or set
    event CreatorFeeChanged(address indexed nftContract, address indexed creatorAddress, uint256 BasisFeePoints);

    // Event called when platform fee changes
    event PlatformFeeChanged(uint256 indexed BasisFeePoints);

    // Event called when tier is changed
    event TierChanged(uint indexed tier, uint256 tokenBalance, uint marketFeeMultiplierSale,
        uint creatorFeeMultiplierSale, uint marketFeeMultiplierOffer, uint creatorFeeMultiplierOffer);


    /**
    * @notice modifiers
    */
    modifier onlySuperAdmin {
        require(msg.sender == superAdmin, "only the super admin can perform this action");
        _;
    }

    modifier onlyAdmin {
        require(msg.sender == admin || msg.sender == superAdmin, "only the admin can perform this action");
        _;
    }


    function setTier(uint tier, uint256 tokenBalance, uint marketFeeMultiplierSale, uint creatorFeeMultiplierSale,
        uint marketFeeMultiplierOffer, uint creatorFeeMultiplierOffer) onlySuperAdmin external {
        require(tier >= 0, "Tier is not in range");
        require(tier < 3, "Tier is not in range");
        require(marketFeeMultiplierSale <= 100 && creatorFeeMultiplierSale <= 100 && marketFeeMultiplierOffer <= 100 && creatorFeeMultiplierOffer <= 100, "Fee multiplier to big");
        sellerTiers[tier].tokenBalance = tokenBalance;
        sellerTiers[tier].marketFeeMultiplierSale = marketFeeMultiplierSale;
        sellerTiers[tier].creatorFeeMultiplierSale = creatorFeeMultiplierSale;
        sellerTiers[tier].marketFeeMultiplierOffer = marketFeeMultiplierOffer;
        sellerTiers[tier].creatorFeeMultiplierOffer = creatorFeeMultiplierOffer;

        emit TierChanged(tier, tokenBalance, marketFeeMultiplierSale, creatorFeeMultiplierSale, marketFeeMultiplierOffer, creatorFeeMultiplierOffer);
    }

    function retrieveMoney(uint256 amount) onlySuperAdmin external {
        require(amount <= address(this).balance, "You can not withdraw more money than there is");
        payable(feeAddress).transfer(amount);
    }

    function setSalesFeeBasisPoints(uint256 feeBasisPoints) onlySuperAdmin external {
        require(feeBasisPoints <= 1000, "Sales Fee cant be higher than 10%");
        salesFeeBasisPoints = feeBasisPoints;
        emit PlatformFeeChanged(salesFeeBasisPoints);
    }

    function setWTFuelAddress(address wTFuel) onlySuperAdmin external {
        WTFuel = wTFuel;
    }

    function setOpenThetaTokenAddress(address OTToken) onlySuperAdmin external {
        openThetaToken = OTToken;
    }

    /**
    * @notice Change the fee address
     * @param feeAddress_ The address of the new fee address
     */
    function setFeeAddress(address feeAddress_) onlySuperAdmin external {
        feeAddress = feeAddress_;
    }

    /**
     * @notice Change the admin address
     * @param superAdmin_ The address of the new super admin
     */
    function setSuperAdmin(address superAdmin_) onlySuperAdmin external {
        superAdmin = superAdmin_;
    }

    /**
     * @notice Change the admin address
     * @param admin_ The address of the new admin
     */
    function setAdmin(address admin_) onlySuperAdmin external {
        admin = admin_;
    }

    // Marketplace functions
    function createMarketItem(address nftContract, uint256 tokenId, uint256 price, string calldata category)
    public nonReentrant {
        require(listingIsActive == true, "Listing disabled");
        require(price > 0, "No item for free here");

        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)), // No owner for the item
            0, // No offer
            payable(address(0)), // No bidder
            category,
            price,
            false
        );
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(itemId, nftContract, tokenId, msg.sender, address(0), category, price, false);
    }

    function updateMarketItem(address nftContract, uint256 tokenId, uint256 price, uint256 itemId)
    public nonReentrant {
        require(listingIsActive == true, "Listing disabled");
        require(price > 0, "No item for free here");
        require(idToMarketItem[itemId].isSold == false, "Item is already sold");
        require(idToMarketItem[itemId].nftContract == nftContract, "Not correct NFT address");
        require(idToMarketItem[itemId].tokenId == tokenId, "Not correct tokenId");
        require(idToMarketItem[itemId].seller == msg.sender, "Only seller can update Item");

        idToMarketItem[itemId].price = price;

        emit MarketItemUpdated(itemId, nftContract, tokenId, msg.sender, address(0), idToMarketItem[itemId].category,
            price, false);
    }

    function createMarketSale(address nftContract, uint256 itemId) public payable nonReentrant {
        require(idToMarketItem[itemId].isSold == false, "Item is already sold");

        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        address addressNFT = idToMarketItem[itemId].nftContract;

        require(addressNFT == nftContract, "Not correct NFT address");
        require(msg.value == price, "Please make the price to be same as listing price");
        require(price > 0, "Item is already canceled");

        address sellerAddress = idToMarketItem[itemId].seller;
        (uint marketFeeMultiplier, uint creatorFeeMultiplier) = getFeeMultiplier(sellerAddress, false);

        // Read data from mappings
        uint256 creatorPayout = 0;
        address creator = AddressToCreatorFeeItem[addressNFT].creator;
        if (creator != address(0x0)) {
            // if creator is set
            creatorPayout = (msg.value / 10000) * AddressToCreatorFeeItem[addressNFT].feeBasisPoints * creatorFeeMultiplier / 100;
            //            payable(creator).transfer(creatorPayout);
            (bool success,) = payable(creator).call{value : creatorPayout}("");
            require(success, "Transfer failed.");
        }

        // set in marketItem
        idToMarketItem[itemId].isSold = true;
        idToMarketItem[itemId].owner = payable(msg.sender);

        _itemsSold.increment();

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        // Calculate Payouts
        uint256 feePayout = (msg.value / 10000) * salesFeeBasisPoints * marketFeeMultiplier / 100;
        uint256 userPayout = msg.value - creatorPayout - feePayout;

        // Payout to user and owner (opentheta)
        //        payable(sellerAddress).transfer(userPayout);
        //        payable(feeAddress).transfer(feePayout);

        (bool successSeller,) = payable(sellerAddress).call{value : userPayout}("");
        require(successSeller, "Transfer to seller failed.");

        (bool successOwner,) = payable(feeAddress).call{value : feePayout}("");
        require(successOwner, "Transfer Fee failed.");

        MarketItem memory item = idToMarketItem[itemId];

        // Through events
        emit MarketItemSale(item.itemId, item.nftContract, item.tokenId, item.seller, item.owner, item.category,
            item.price, true);

        emit FeeSplit(userPayout, sellerAddress, feePayout, feeAddress, creatorPayout, creator);
    }

    function createMarketCancel(address nftContract, uint256 itemId) public nonReentrant {
        require(msg.sender == idToMarketItem[itemId].seller, "You have to be the seller to cancel");
        require(idToMarketItem[itemId].isSold == false, "Item is already sold");

        // Read data from mappings
        uint256 tokenId = idToMarketItem[itemId].tokenId;

        // set in marketItem
        idToMarketItem[itemId].price = 0;
        idToMarketItem[itemId].isSold = true;
        idToMarketItem[itemId].owner = payable(idToMarketItem[itemId].seller);

        IERC721(nftContract).transferFrom(address(this), idToMarketItem[itemId].seller, tokenId);

        _itemsSold.increment();

        // Through event
        emit MarketItemSale(itemId, idToMarketItem[itemId].nftContract, idToMarketItem[itemId].tokenId,
            idToMarketItem[itemId].seller, idToMarketItem[itemId].owner, idToMarketItem[itemId].category, 0, true);
    }

    function createMarketCancelAdmin(address nftContract, uint256 itemId) public nonReentrant onlyAdmin {
        require(idToMarketItem[itemId].isSold == false, "Item is already sold");

        // Read data from mappings
        uint256 tokenId = idToMarketItem[itemId].tokenId;

        // set in marketItem
        idToMarketItem[itemId].price = 0;
        idToMarketItem[itemId].isSold = true;
        idToMarketItem[itemId].owner = payable(idToMarketItem[itemId].seller);

        IERC721(nftContract).transferFrom(address(this), idToMarketItem[itemId].seller, tokenId);

        _itemsSold.increment();

        // Through event
        emit MarketItemSale(itemId, idToMarketItem[itemId].nftContract, idToMarketItem[itemId].tokenId,
            idToMarketItem[itemId].seller, idToMarketItem[itemId].owner, idToMarketItem[itemId].category, 0, true);
    }

    // For TNT20 token (WrapedTFuel)
    function createMarketItemOfferTNT20(address nftContract, uint256 itemId, uint256 offerPrice) public nonReentrant {
        require(idToMarketItem[itemId].isSold == false, "Item is already sold");
        require(idToMarketItem[itemId].nftContract == nftContract, "Not correct NFT address");

        uint256 allowance = IERC20(WTFuel).allowance(msg.sender, address(this));
        uint256 highestOffer = idToMarketItem[itemId].highestOffer;

        require(allowance >= offerPrice, "Allowance of TNT20 token is not big enough");
        if (IERC20(WTFuel).allowance(idToMarketItem[itemId].bidder, address(this)) >= highestOffer) {
            require(highestOffer < offerPrice, "Not highest offer");
        }

        // set in marketItem
        idToMarketItem[itemId].highestOffer = offerPrice;
        idToMarketItem[itemId].bidder = payable(msg.sender);

        emit OfferPlaced(itemId, nftContract, idToMarketItem[itemId].tokenId, idToMarketItem[itemId].seller, offerPrice, idToMarketItem[itemId].bidder, idToMarketItem[itemId].category, idToMarketItem[itemId].price);
    }

    function acceptMarketItemOfferTNT20(address nftContract, uint256 itemId, uint256 price) public payable nonReentrant {
        require(msg.sender == idToMarketItem[itemId].seller, "You have to be the seller to cancel");
        require(idToMarketItem[itemId].isSold == false, "Item is already sold");

        uint256 offer = idToMarketItem[itemId].highestOffer;
        require(offer >= price, "offer is smaller as expected");

        address bidder = idToMarketItem[itemId].bidder;

        if (IERC20(WTFuel).allowance(bidder, address(this)) < idToMarketItem[itemId].highestOffer) {
            // delete offer, bidder has not enough TNT20 tokens
            // set in marketItem
            idToMarketItem[itemId].highestOffer = 0;
            idToMarketItem[itemId].bidder = address(0x0);
            return;
        }


        idToMarketItem[itemId].price = offer;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        address addressNFT = idToMarketItem[itemId].nftContract;

        require(addressNFT == nftContract, "Not correct NFT address");

        (uint marketFeeMultiplier, uint creatorFeeMultiplier) = getFeeMultiplier(idToMarketItem[itemId].seller, true);
        //        (uint marketFeeMultiplier, uint creatorFeeMultiplier) = (100,100);
        // Read data from mappings
        uint256 creatorPayout = 0;
        address creator = AddressToCreatorFeeItem[addressNFT].creator;
        if (creator != address(0x0)) {
            // if creator is set
            creatorPayout = (offer / 10000) * AddressToCreatorFeeItem[addressNFT].feeBasisPoints * creatorFeeMultiplier / 100;
            IERC20(WTFuel).transferFrom(bidder, creator, creatorPayout);
        }

        // set in marketItem
        idToMarketItem[itemId].isSold = true;
        idToMarketItem[itemId].owner = payable(bidder);

        _itemsSold.increment();

        IERC721(nftContract).transferFrom(address(this), bidder, tokenId);

        // Calculate Payouts
        uint256 feePayout = (offer / 10000) * salesFeeBasisPoints * marketFeeMultiplier / 100;
        uint256 userPayout = offer - creatorPayout - feePayout;

        MarketItem memory item = idToMarketItem[itemId];
        // Payout to user and feeAddress (opentheta)
        require(IERC20(WTFuel).transferFrom(bidder, item.seller, userPayout));
        require(IERC20(WTFuel).transferFrom(bidder, feeAddress, feePayout));

        // Through events
        emit MarketItemSale(itemId, item.nftContract, item.tokenId, item.seller, item.owner, item.category, item.price, true);

        emit FeeSplit(userPayout, item.seller, feePayout, feeAddress, creatorPayout, creator);
    }

    function cancelMarketItemOfferTNT20(uint256 itemId) public nonReentrant {
        require(msg.sender == idToMarketItem[itemId].bidder, "You have to be the bidder to cancel");
        require(idToMarketItem[itemId].isSold == false, "Item is already sold");

        idToMarketItem[itemId].highestOffer = 0;
        idToMarketItem[itemId].bidder = address(0x0);

        emit OfferCanceled(itemId, idToMarketItem[itemId].nftContract, idToMarketItem[itemId].tokenId, idToMarketItem[itemId].seller, msg.sender, idToMarketItem[itemId].price);
    }

    /*
    * Pause listings if active
    */
    function flipListingState() onlySuperAdmin public {
        listingIsActive = !listingIsActive;
    }

    // set creator fee
    function setCreatorFeeBasisPoints(uint256 feeBasisPoints, address creatorAddress, address NFTAddress)
    public onlyAdmin {
        require(feeBasisPoints <= 1000, "Sales Fee cant be higher than 10%");
        AddressToCreatorFeeItem[NFTAddress].feeBasisPoints = feeBasisPoints;
        AddressToCreatorFeeItem[NFTAddress].creator = payable(creatorAddress);

        emit CreatorFeeChanged(NFTAddress, creatorAddress, feeBasisPoints);
    }

    function flipTiersState() onlySuperAdmin public {
        tiersAreActive = !tiersAreActive;
    }

    // get creator fee
    function getCreatorFeeBasisPoints(address NFTAddress) public view returns (Creator memory){
        return AddressToCreatorFeeItem[NFTAddress];
    }

    function getTier(uint tier) public view returns (Tier memory) {
        require(tier < 3, "Tier number to big");
        return sellerTiers[tier];
    }

    function getByMarketId(uint256 id) public view returns (MarketItem memory){
        require(id <= _itemIds.current(), "id doesn't exist");
        return idToMarketItem[id];
    }

    function getSalesFee() public view returns (uint256) {
        return salesFeeBasisPoints;
    }

    // Set Tiers and get internal fee multiplier
    function getFeeMultiplier(address seller, bool offer) internal view returns (uint, uint) {
        if (tiersAreActive && openThetaToken != address(0x0)) {
            uint256 userTokenBalance = IERC20(openThetaToken).balanceOf(seller);
            if (offer) {
                if (userTokenBalance >= sellerTiers[2].tokenBalance) {
                    return (sellerTiers[2].marketFeeMultiplierOffer, sellerTiers[2].creatorFeeMultiplierOffer);
                } else if (userTokenBalance >= sellerTiers[1].tokenBalance) {
                    return (sellerTiers[1].marketFeeMultiplierOffer, sellerTiers[1].creatorFeeMultiplierOffer);
                } else if (userTokenBalance >= sellerTiers[0].tokenBalance) {
                    return (sellerTiers[0].marketFeeMultiplierOffer, sellerTiers[0].creatorFeeMultiplierOffer);
                } else {
                    return (100, 100);
                }
            } else {
                if (userTokenBalance >= sellerTiers[2].tokenBalance) {
                    return (sellerTiers[2].marketFeeMultiplierSale, sellerTiers[2].creatorFeeMultiplierSale);
                } else if (userTokenBalance >= sellerTiers[1].tokenBalance) {
                    return (sellerTiers[1].marketFeeMultiplierSale, sellerTiers[1].creatorFeeMultiplierSale);
                } else if (userTokenBalance >= sellerTiers[0].tokenBalance) {
                    return (sellerTiers[0].marketFeeMultiplierSale, sellerTiers[0].creatorFeeMultiplierSale);
                } else {
                    return (100, 100);
                }
            }
        } else {
            return (100, 100);
        }
    }
}