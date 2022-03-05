// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)
// File: @openzeppelin/contracts/token/ERC20/IERC20.sol
pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface ITNT20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
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
interface ITNT165 {
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
interface ITNT721 is ITNT165 {
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

contract MultiSend {

    address public admin;
    uint public TNT20SendFee; // in basis points
    uint public tFuelSendFee; // in wei
    uint public TNT721SendFee; // in wei
    bool public tiersAreActive = false;
    address public openThetaToken;

    struct Tier {
        uint256 tokenBalance;
        uint feeMultiplier;
    }

    Tier[3] public tiers;

    constructor() {
        admin = payable(msg.sender);
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "only the admin can perform this action");
        _;
    }

    function bulkSendTFuel(address[] calldata addresses, uint256[] calldata amounts) public payable returns(bool success){
        uint total = 0;
        for(uint8 i = 0; i < amounts.length; i++){
            total = total + amounts[i];
        }

        //ensure that the TFuel is enough to complete the transaction
        uint256 fee = tFuelSendFee * getFeeMultiplier(msg.sender)/100;
        uint256 requiredAmount = total + fee * 1 wei;
        require(msg.value >= (requiredAmount * 1 wei));

        //transfer to each address
        for (uint8 j = 0; j < addresses.length; j++) {
            payable(addresses[j]).transfer(amounts[j] * 1 wei);
        }
        return true;
    }

    function bulkSendTFuelFixed(address[] calldata addresses, uint256 amount) public payable returns(bool success){
        uint total = addresses.length * amount;

        //ensure that the TFuel is enough to complete the transaction
        uint256 fee = tFuelSendFee * getFeeMultiplier(msg.sender)/100;
        uint256 requiredAmount = total + fee * 1 wei;
        require(msg.value >= (requiredAmount * 1 wei));

        //transfer to each address
        for (uint8 j = 0; j < addresses.length; j++) {
            payable(addresses[j]).transfer(amount * 1 wei);
        }
        return true;
    }

    function bulkSendTNT20(address tokenAddr, address[] calldata addresses, uint256[] calldata amounts) public returns(bool success){
        uint total = 0;
        for(uint8 i = 0; i < amounts.length; i++){
            total = total + amounts[i];
        }

        //ensure that the TFuel is enough to complete the transaction
        uint fee = (TNT20SendFee/10000) * getFeeMultiplier(msg.sender)/100;
        uint requiredAmount = total * (100 + fee);
        require(ITNT20(tokenAddr).allowance(msg.sender, address(this)) >= requiredAmount, "Allowance to low");

        //transfer to each address
        for (uint8 j = 0; j < addresses.length; j++) {
            ITNT20(tokenAddr).transferFrom(msg.sender, addresses[j], amounts[j]);
        }
        ITNT20(tokenAddr).transferFrom(msg.sender, address(this), total * fee);
        return true;
    }

    function bulkSendTNT20Fixed(address tokenAddr, address[] calldata addresses, uint256 amount) public returns(bool success){
        uint total = addresses.length * amount;

        //ensure that the TFuel is enough to complete the transaction
        uint fee = (TNT20SendFee/10000) * getFeeMultiplier(msg.sender)/100;
        uint requiredAmount = total * (100 + fee);
        require(ITNT20(tokenAddr).allowance(msg.sender, address(this)) >= requiredAmount, "Allowance to low");

        //transfer to each address
        for (uint8 j = 0; j < addresses.length; j++) {
            ITNT20(tokenAddr).transferFrom(msg.sender, addresses[j], amount);
        }
        ITNT20(tokenAddr).transferFrom(msg.sender, address(this), total * fee);
        return true;
    }

    function bulkSendTNT721(address[] calldata nftContracts, address[] calldata addresses, uint256[] calldata tokenIds) public payable returns(bool success){

        //ensure that the TFuel is enough to complete the transaction
        uint256 fee = TNT721SendFee * getFeeMultiplier(msg.sender)/100;
        require(msg.value >= fee, "Fee not fully payed");

        //transfer to each address
        for (uint8 j = 0; j < nftContracts.length; j++) {
            ITNT721(nftContracts[j]).transferFrom(msg.sender, addresses[j], tokenIds[j]);
        }
        return true;
    }

    function bulkSendTNT721Fixed(address nftContract, address[] calldata addresses, uint256[] calldata tokenIds) public payable returns(bool success){

        //ensure that the TFuel is enough to complete the transaction
        require(msg.value >= TNT721SendFee, "Fee not fully payed");

        //transfer to each address
        for (uint8 j = 0; j < addresses.length; j++) {
            ITNT721(nftContract).transferFrom(msg.sender, addresses[j], tokenIds[j]);
        }
        return true;
    }

    function setTNT20SendFeeBasisPoints(uint256 feeBasisPoints) onlyAdmin external {
        require(feeBasisPoints <= 1000, "Sales Fee cant be higher than 10%");
        TNT20SendFee = feeBasisPoints;
    }

    function setTFuelSendFee(uint256 fee) onlyAdmin external {
        tFuelSendFee = fee;
    }

    function setTNT721SendFee(uint256 fee) onlyAdmin external {
        TNT721SendFee = fee;
    }

    function setTier(uint tier, uint256 tokenBalance, uint feeMultiplier) onlyAdmin external {
        require(tier >= 0, "Tier is not in range");
        require(tier < 3, "Tier is not in range");
        require(feeMultiplier <= 100, "Fee multiplier to big");
        tiers[tier].tokenBalance = tokenBalance;
        tiers[tier].feeMultiplier = feeMultiplier;
    }

    function setOpenThetaTokenAddress(address OTToken) onlyAdmin external {
        openThetaToken = OTToken;
    }

    function flipTiersState() onlyAdmin public {
        tiersAreActive = !tiersAreActive;
    }

    function getTier(uint tier) public view returns (Tier memory) {
        require(tier < 3, "Tier number to big");
        return tiers[tier];
    }

    // Set Tiers and get internal fee multiplier
    function getFeeMultiplier(address seller) internal view returns (uint) {
        if (tiersAreActive && openThetaToken != address(0x0)) {
            uint256 userTokenBalance = ITNT20(openThetaToken).balanceOf(seller);
            if (userTokenBalance >= tiers[2].tokenBalance) {
                return tiers[2].feeMultiplier;
            } else if (userTokenBalance >= tiers[1].tokenBalance) {
                return tiers[1].feeMultiplier;
            } else if (userTokenBalance >= tiers[0].tokenBalance) {
                return tiers[0].feeMultiplier;
            } else {
                return 100;
            }
        } else {
            return 100;
        }
    }

    /**
 * @notice Change the admin address
     * @param admin_ The address of the new admin
     */
    function setAdmin(address admin_) onlyAdmin external {
        admin = admin_;
    }

    receive() external payable {}

    function withdrawTFuel(address _to, uint256 _amount) onlyAdmin external {
        require(_amount <= address(this).balance, "You can not withdraw more money than there is");
        payable(_to).transfer(_amount);
    }

    function withdrawTNT20(address _tokenAddr, address _to, uint256 _amount) onlyAdmin external {
        require(_amount <= ITNT20(_tokenAddr).balanceOf(address(this)), "You can not withdraw more money than there is");
        ITNT20(_tokenAddr).transfer(_to, _amount);
    }
}
