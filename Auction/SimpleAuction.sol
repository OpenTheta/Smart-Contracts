// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)
// File: @openzeppelin/contracts/utils/Counters.sol
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


// OpenZeppelin Contracts v4.3.2 (utils/introspection/IERC165.sol)
// File: @openzeppelin/contracts/utils/introspection/IERC165.sol
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


// OpenZeppelin Contracts v4.3.2 (token/ERC721/IERC721.sol)
// File: @openzeppelin/contracts/token/ERC721/IERC721.sol
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
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

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
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

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
}


//import "@openzeppelin/contracts/utils/Counters.sol";
//import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract SimpleAuction {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds; // Id for each individual item

    address public superAdmin;
    address public admin;
    address public feeAddress;

    uint maxCreatorBasePoints = 9000;

    constructor() {
        superAdmin = payable(msg.sender);
    }

    struct AuctionItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        uint256 minBid;
        uint256 startTimestamp;
        uint256 endTimestamp;
        address highestBidderAddress;
        uint256 highestBid;
        bool sold;
        address creatorAddress;
        uint creatorBasePoints;
    }

    mapping(uint256 => AuctionItem) private idToAuctionItem;
    mapping(address => bool) private creatorAccess;

    // Event called when a new Item is created
    event AuctionCreated(uint256 indexed itemId, address indexed nftContract, uint256 indexed tokenId, uint256 minBid,
        uint256 startTimestamp, uint256 endTimestamp, address creatorAddress, uint creatorBasePoints);

    // Event called when a new Item is updated
    event AuctionUpdated(uint256 indexed itemId, address indexed nftContract, uint256 indexed tokenId, uint256 minBid,
        uint256 startTimestamp, uint256 endTimestamp, address creatorAddress, uint creatorBasePoints);

    // Event called when an Item is sold
    event AuctionSold(uint256 indexed itemId, address nftContract, uint256 tokenId,
        uint256 endTimestamp, address indexed bidder, uint256 indexed bid);

    // Event called when an Item gets canceld
    event AuctionCanceled(uint256 indexed itemId, address nftContract, uint256 tokenId, address indexed receiverAddress);

    // Event when someone places a bid
    event BidPlaced(uint256 indexed itemId, address nftContract, uint256 tokenId, address indexed bidder,
        uint256 indexed bid);

    // Event called TFuel is spit into creator fee and opentheta fee
    event FeeSplit(uint256 creatorPayout, address indexed creatorAddress, uint256 feePayout, address indexed feeAddress);

    // Event called when creator max base fee points are changed
    event MaxCreatorBasePointsChanged(uint256 BasisFeePoints);

    // Event called when creator gets access to create auctions
    event creatorChanged(address indexed creator, bool indexed access);


    /**
    * @notice modifiers
    */
    modifier onlySuperAdmin {
        require(msg.sender == superAdmin, "only the super admin can perform this action");
        _;
    }

    modifier onlyAdmin {
        require(msg.sender == admin || msg.sender == superAdmin, "only the admin/superAdmin can perform this action");
        _;
    }

    modifier onlyCreator {
        require(msg.sender == admin || msg.sender == superAdmin || creatorAccess[msg.sender], "only the admin/superAdmin/creator can perform this action");
        _;
    }

    function getByAuctionId(uint256 id) public view returns (AuctionItem memory){
        require(id <= _itemIds.current(), "id doesn't exist");
        return idToAuctionItem[id];
    }

    function placeBid(uint256 itemId, address nftContract, uint256 bid) external payable {
        require(idToAuctionItem[itemId].sold == false, "Item sold");
        require(idToAuctionItem[itemId].startTimestamp < block.timestamp, "Auction not live");
        require(idToAuctionItem[itemId].endTimestamp > block.timestamp, "Auction ended");
        require(bid == msg.value, "Bid unequal value send");
        require(bid >= idToAuctionItem[itemId].minBid, "Bid smaller minBid");
        require(bid > idToAuctionItem[itemId].highestBid, "Bid smaller highest Bid");


        // payback previous highest bidder
        if(idToAuctionItem[itemId].highestBid > 0) {
            (bool success,) = payable(idToAuctionItem[itemId].highestBidderAddress).call{value : idToAuctionItem[itemId].highestBid}("");
            require(success, "Transfer to seller failed.");
        }

        idToAuctionItem[itemId].highestBid = bid;
        idToAuctionItem[itemId].highestBidderAddress = msg.sender;

        emit BidPlaced(itemId, nftContract, idToAuctionItem[itemId].tokenId, msg.sender , bid);
    }

    function createAuction(address nftContract, uint256 tokenId, uint256 minBid, uint256 startTimestamp, uint256 endTimestamp, address creatorAddress, uint creatorBasePoints) onlyCreator external returns(uint256){
        require(minBid > 0, "No item for free here");
        require(endTimestamp > block.timestamp, "Auction can't end in the past");
        require(startTimestamp < endTimestamp, "Can't start after end");
        require(creatorBasePoints <= 10000, "Cant get more then 100%");

        if(msg.sender != admin && msg.sender != superAdmin) {
            require(creatorBasePoints <= maxCreatorBasePoints, "Cant get more then maxCreatorBasePoints");
        }

        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        idToAuctionItem[itemId] = AuctionItem(
            itemId,
            nftContract,
            tokenId,
            minBid,
            startTimestamp,
            endTimestamp,
            payable(address(0)),
            0, // No bid
            false,
            creatorAddress,
            creatorBasePoints
        );
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit AuctionCreated(itemId, nftContract, tokenId, minBid, startTimestamp, endTimestamp, creatorAddress, creatorBasePoints);

        return itemId;
    }

    function updateAuction(uint256 itemId, address nftContract, uint256 minBid, uint256 startTimestamp,
        uint256 endTimestamp, address creatorAddress, uint creatorBasePoints) onlyAdmin external {
        require(minBid > 0, "No item for free here");
        require(endTimestamp > block.timestamp, "Auction can end in the past");
        require(startTimestamp < endTimestamp, "Can't start after end");
        require(creatorBasePoints <= 10000, "Cant get more then 100%");
        require(idToAuctionItem[itemId].sold == false, "Item sold");

        idToAuctionItem[itemId].minBid = minBid;
        idToAuctionItem[itemId].startTimestamp = startTimestamp;
        idToAuctionItem[itemId].endTimestamp = endTimestamp;
        idToAuctionItem[itemId].creatorAddress = creatorAddress;
        idToAuctionItem[itemId].creatorBasePoints = creatorBasePoints;

        emit AuctionUpdated(itemId, nftContract, idToAuctionItem[itemId].tokenId, minBid, startTimestamp, endTimestamp,
            creatorAddress, creatorBasePoints);
    }

    function cancelAuction(uint256 itemId, address receiverAddress) onlyAdmin external {
        require(idToAuctionItem[itemId].sold == false, "Item sold");

        idToAuctionItem[itemId].sold = true;
        idToAuctionItem[itemId].endTimestamp = 0;
        idToAuctionItem[itemId].startTimestamp = 0;
        // payback previous highest bidder
        if(idToAuctionItem[itemId].highestBid > 0) {
            (bool success,) = payable(idToAuctionItem[itemId].highestBidderAddress).call{value : idToAuctionItem[itemId].highestBid}("");
            require(success, "Transfer to seller failed.");
            idToAuctionItem[itemId].highestBidderAddress = address(0);
            idToAuctionItem[itemId].highestBid = 0;
        }

        IERC721(idToAuctionItem[itemId].nftContract).transferFrom(address(this), receiverAddress, idToAuctionItem[itemId].tokenId);

        emit AuctionCanceled(itemId, idToAuctionItem[itemId].nftContract, idToAuctionItem[itemId].tokenId, receiverAddress);
    }

    function finishAuction(uint256 itemId) external {
        require(idToAuctionItem[itemId].endTimestamp < block.timestamp, "Auction can end in the past");
        require(idToAuctionItem[itemId].sold == false, "Item sold");
        require(idToAuctionItem[itemId].highestBid > 0, "No bid placed");

        idToAuctionItem[itemId].sold = true;
        uint256 highestBid = idToAuctionItem[itemId].highestBid;
        uint256 creatorPayout = (highestBid/10000) * idToAuctionItem[itemId].creatorBasePoints;
        (bool successCreator,) = payable(idToAuctionItem[itemId].creatorAddress).call{value : creatorPayout}("");
        require(successCreator, "Transfer to seller failed.");

        uint256 feePayout = highestBid - creatorPayout;
        (bool successFee,) = payable(feeAddress).call{value : feePayout}("");
        require(successFee, "Transfer to seller failed.");

        IERC721(idToAuctionItem[itemId].nftContract).transferFrom(address(this), idToAuctionItem[itemId].highestBidderAddress, idToAuctionItem[itemId].tokenId);

        emit AuctionSold(itemId, idToAuctionItem[itemId].nftContract, idToAuctionItem[itemId].tokenId,
            idToAuctionItem[itemId].endTimestamp, idToAuctionItem[itemId].highestBidderAddress, idToAuctionItem[itemId].highestBid);

        emit FeeSplit(creatorPayout, idToAuctionItem[itemId].creatorAddress, feePayout, feeAddress);
    }

    function setCreator(address creatorAddress, bool access) onlyAdmin external {
        creatorAccess[creatorAddress] = access;
        emit creatorChanged(creatorAddress, access);
    }

    function setMaxCreatorBasePoints(uint maxCreatorBasePoints_) onlySuperAdmin external {
        maxCreatorBasePoints = maxCreatorBasePoints_;
        emit MaxCreatorBasePointsChanged(maxCreatorBasePoints_);
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

    // get creator fee
    function getCreator(address creatorAddress) public view returns (bool){
        return creatorAccess[creatorAddress];
    }
}
