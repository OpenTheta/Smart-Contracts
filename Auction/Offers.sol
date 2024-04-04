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

contract Offers is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds; // Id for each individual item

    address public admin;
    address public feeAddress;
    address public OTMarketAddress = 0xbB5f35D40132A0478f6aa91e79962e9F752167EA;
    uint256 private offerFeeTFuel;

    constructor() {
        admin = payable(msg.sender);
    }

    struct Creator {
        address creator;
        uint256 feeBasisPoints;
    }


    mapping(address => mapping(uint256 => mapping(address => uint256))) private tokenToOfferItem;
    //    mapping(uint256 => AuctionItem) private idToAuctionItem;


    // Event called when new Offer placed
    event OfferPlaced(address indexed nftContract, uint256 indexed tokenId, address indexed userAddress, uint256 offer);

    // Event called when an Offer is updated
    event OfferUpdated(address indexed nftContract, uint256 indexed tokenId, address indexed userAddress, uint256 offer);

    // Event called when an offer is accepted
    event OfferAccepted(address indexed nftContract, uint256 indexed tokenId, address indexed userAddress, uint256 offer, address seller);

    // Event called when an Offer gets canceled
    event OfferCanceled(address indexed nftContract, uint256 indexed tokenId, address indexed userAddress, uint256 offer);

    // Event called TFuel is spit into creator fee, opentheta fee and payment to seller
    event FeeSplit(uint256 userPayout, address indexed userAddress, uint256 feePayout, address indexed feeAddress,
        uint256 creatorPayout, address indexed creatorAddress);

    // Event shows to whom tfuel gets payed back because overbid or canceled
    event UserPayback(uint256 userPayback, address indexed userAddress);


    /**
    * @notice modifiers
    */
    modifier onlyAdmin {
        require(msg.sender == admin, "only the admin can perform this action");
        _;
    }


    function getOffer(address nftContract, uint256 tokenId, address userAddress) public view returns (uint256){
        return tokenToOfferItem[nftContract][tokenId][userAddress];
    }

    function getOfferFeeTFuel() public view returns (uint256){
        return offerFeeTFuel;
    }

    function placeOffer(address nftContract, uint256 tokenId, uint256 offer) external payable {
        require(tokenToOfferItem[nftContract][tokenId][msg.sender] == 0, "Offer already set");
        require(offer+offerFeeTFuel == msg.value, "Bid unequal value send");

        tokenToOfferItem[nftContract][tokenId][msg.sender] = offer;

        if(offerFeeTFuel > 0) {
            (bool successFee,) = payable(feeAddress).call{value : offerFeeTFuel}("");
            require(successFee, "Transfer to seller failed.");
        }

        emit OfferPlaced(nftContract, tokenId, msg.sender, offer);
    }

    function updateOffer(address nftContract, uint256 tokenId, uint256 offer) external payable nonReentrant {
        require(tokenToOfferItem[nftContract][tokenId][msg.sender] > 0, "No offer set");
        require(offer+offerFeeTFuel == msg.value, "Bid unequal value send");

        uint256 UserPayout = tokenToOfferItem[nftContract][tokenId][msg.sender];
        tokenToOfferItem[nftContract][tokenId][msg.sender] = offer;
        (bool successUser,) = payable(msg.sender).call{value : UserPayout}("");
        require(successUser, "Transfer to seller failed.");

        if(offerFeeTFuel > 0) {
            (bool successFee,) = payable(feeAddress).call{value : offerFeeTFuel}("");
            require(successFee, "Transfer to seller failed.");
        }

        emit UserPayback(UserPayout, msg.sender);
        emit OfferUpdated(nftContract, tokenId, msg.sender, offer);
    }

    function cancelOffer(address nftContract, uint256 tokenId) external nonReentrant {
        require(tokenToOfferItem[nftContract][tokenId][msg.sender] > 0, "No offer exists");

        uint256 UserPayout = tokenToOfferItem[nftContract][tokenId][msg.sender];
        tokenToOfferItem[nftContract][tokenId][msg.sender] = 0;
        (bool successUser,) = payable(msg.sender).call{value : UserPayout}("");
        require(successUser, "Transfer to seller failed.");

        emit UserPayback(UserPayout, msg.sender);
        emit OfferCanceled(nftContract, tokenId, msg.sender, UserPayout);
    }

    function cancelOfferAdmin(address nftContract, uint256 tokenId, address user) external onlyAdmin nonReentrant {
        require(tokenToOfferItem[nftContract][tokenId][user] > 0, "No offer exists");

        uint256 UserPayout = tokenToOfferItem[nftContract][tokenId][user];
        tokenToOfferItem[nftContract][tokenId][user] = 0;
        (bool successUser,) = payable(user).call{value : UserPayout}("");
        require(successUser, "Transfer to seller failed.");

        emit UserPayback(UserPayout, user);
        emit OfferCanceled(nftContract, tokenId, user, UserPayout);
    }

    function acceptOffer(address nftContract, uint256 tokenId, address user, uint256 offered) external nonReentrant {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender,"You do not own this NFT");
        uint256 offer = tokenToOfferItem[nftContract][tokenId][user];
        require(offer > 0, "No offer exists");
        require(offered == offer, "This offer doesn't exist");
        tokenToOfferItem[nftContract][tokenId][user] = 0;
        // Get Creator Fee
        uint256 creatorPayout;
        MARKET.Creator memory creatorData = MARKET(OTMarketAddress).getCreatorFeeBasisPoints(nftContract);
        if (creatorData.creator != address(0x0)) {
            // if creator is set
            creatorPayout = (offer / 10000) * creatorData.feeBasisPoints;
            (bool successCreator,) = payable(creatorData.creator).call{value : creatorPayout}("");
            require(successCreator, "Transfer failed.");
        }
        // OpenTheta Fee
        uint256 feePayout = (offer / 10000) * MARKET(OTMarketAddress).getSalesFee();
        (bool successFee,) = payable(feeAddress).call{value : feePayout}("");
        require(successFee, "Transfer to seller failed.");
        // User Payout
        uint256 UserPayout = offer - creatorPayout - feePayout;
        (bool successUser,) = payable(msg.sender).call{value : UserPayout}("");
        require(successUser, "Transfer to seller failed.");
        // Send NFT to highest bidder
        IERC721(nftContract).transferFrom(msg.sender, user, tokenId);
        emit FeeSplit(UserPayout, msg.sender, feePayout, feeAddress, creatorPayout, creatorData.creator);
        emit OfferAccepted(nftContract, tokenId, user, offer, msg.sender);
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
    * @notice Change offerFeeTFuel that is payed to create a new offer
     * @param offerFeeTFuel_ The amount to pay
     */
    function setOfferFeeTFuel(uint256 offerFeeTFuel_) onlyAdmin external {
        offerFeeTFuel = offerFeeTFuel_;
    }

    /**
     * @notice Change the admin address
     * @param admin_ The address of the new admin
     */
    function setAdmin(address admin_) onlyAdmin external {
        admin = admin_;
    }
}