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

// File: contracts/offers.sol


pragma solidity ^0.8.10;




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