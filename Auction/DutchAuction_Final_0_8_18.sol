// SPDX-License-Identifier: MIT
// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts/token/ERC721/IERC721.sol


// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;


/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// File: @openzeppelin/contracts/utils/Counters.sol


// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
    unchecked {
        counter._value += 1;
    }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
    unchecked {
        counter._value = value - 1;
    }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// File: contracts/DutchAuction.sol


pragma solidity ^0.8.10;




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
            creatorPayout = (msg.value / 10000) * creatorData.feeBasisPoints;
            (bool successCreator,) = payable(creatorData.creator).call{value : creatorPayout}("");
            require(successCreator, "Transfer failed.");
        }

        // OpenTheta Fee
        uint256 feePayout = (msg.value / 10000) * MARKET(OTMarketAddress).getSalesFee();
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