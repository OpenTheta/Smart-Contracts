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


contract OpenThetaNFTLending is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds; // Id for each individual item
    Counters.Counter private _itemsLend; // Number of items sold

    /// @notice The super admin address / owner
    address public superAdmin;

    /// @notice The admin address
    address public admin;

    address public feeAddress;

    uint256 lendingFeeBasisPoints = 1000;
    uint256 borrowPlatformFeeTFuel = 10 * 10**18;
    bool public lendingIsActive = true;
    bool public tiersAreActive = false;
    address public openThetaToken;
    address public stableCoinAddress;

    struct Tier {
        uint256 tokenBalance;
        uint lendingFeeMultiplier;
        uint borrowFeeTFuelMultiplier;
    }

    Tier[3] public sellerTiers;

    struct LendingItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable lender;
        address payable borrower;
        uint256 initialWorth;
        uint256 dailyFee;
        uint256 latestReturnTimestamp;
        uint256 borrowedAtTimestamp;
        bool available;
        bool lenderClaimedCollateral;
        bool stableCoin;
    }

    //    mapping that keeps all items ever placed on the for lending
    mapping(uint256 => LendingItem) private idToLendingItem;




    constructor(address feeAddress_) {
        superAdmin = payable(msg.sender);
        feeAddress = payable(feeAddress_);
    }

    fallback() payable external {}

    receive() external payable {}


    // Event called when a new Item is created
    event ItemCreated(uint256 indexed itemId, address indexed nftContract, uint256 tokenId, address indexed lender,
        uint256 initialWorth, uint256 dailyFee, uint256 latestReturnTimestamp, bool stableCoin);

    // Event called when a new Item is updated
    event ItemUpdated(uint256 indexed itemId, address indexed nftContract, uint256 tokenId, address indexed lender,
        uint256 initialWorth, uint256 blockFee, uint256 latestReturnTimestamp, bool stableCoin);

    // Event called when an Item is borrowed
    event ItemBorrowed(uint256 indexed itemId, address indexed nftContract, uint256 tokenId,
        address lender, address indexed borrower, uint256 borrowTimestamp, bool stableCoin);

    // Event when item canceled
    event ItemCanceled(uint256 indexed itemId, address indexed nftContract, uint256 tokenId,
        address indexed lender);

    // Event when item canceled
    event ItemReturned(uint256 indexed itemId, address indexed nftContract, uint256 tokenId,
        address indexed lender, bool available);

    // Event when item canceled
    event claimCollateral(uint256 indexed itemId, address indexed nftContract, uint256 tokenId,
        address indexed lender, uint256 initialWorth, bool stableCoin);

    // Event called when platform fee changes
    event PlatformFeeChanged(uint256 indexed BasisFeePoints);

    // Event called when tier is changed
    event TierChanged(uint indexed tier, uint256 tokenBalance, uint lendingFeeMultiplier,
        uint borrowFeeTFuelMultiplier);


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


    function setTier(uint tier, uint256 tokenBalance, uint lendingFeeMultiplier, uint borrowFeeTFuelMultiplier) onlySuperAdmin external {
        require(tier >= 0, "Tier is not in range");
        require(tier < 3, "Tier is not in range");
        uint256 tokenBalance;
        uint lendingFeeMultiplier;
        uint borrowFeeTFuelMultiplier;
        require(lendingFeeMultiplier <= 100 && borrowFeeTFuelMultiplier <= 100, "Fee multiplier to big");
        sellerTiers[tier].tokenBalance = tokenBalance;
        sellerTiers[tier].lendingFeeMultiplier = lendingFeeMultiplier;
        sellerTiers[tier].borrowFeeTFuelMultiplier = borrowFeeTFuelMultiplier;

        emit TierChanged(tier, tokenBalance, lendingFeeMultiplier, borrowFeeTFuelMultiplier);
    }

    function setlendingFeeBasisPoints(uint256 feeBasisPoints) onlySuperAdmin external {
        require(feeBasisPoints <= 1000, "Sales Fee cant be higher than 10%");
        lendingFeeBasisPoints = feeBasisPoints;
        emit PlatformFeeChanged(lendingFeeBasisPoints);
    }

    function setOpenThetaTokenAddress(address OTToken) onlySuperAdmin external {
        openThetaToken = OTToken;
    }

    function setStableCoinAddress(address stableCoin) onlySuperAdmin external {
        stableCoinAddress = stableCoin;
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

    // Lending functions
    function createLendingItem(address nftContract, uint256 tokenId, uint256 initialWorth, uint256 dailyFee, uint256 latestReturnTimestamp, bool stableCoin)
    public nonReentrant {
        require(lendingIsActive == true, "Lending disabled");
        require(initialWorth > 0, "Item has to be worth something");
        require(dailyFee > 0, "no items lending for free");

        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        idToLendingItem[itemId] = LendingItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)), // No owner for the item
            initialWorth, // Collateral
            dailyFee,
            latestReturnTimestamp,
            0,
            true,
            false,
            stableCoin
        );
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit ItemCreated(itemId, nftContract, tokenId, msg.sender, initialWorth, dailyFee, latestReturnTimestamp, stableCoin);
    }

    function updateLendingItem(uint256 itemId, address nftContract, uint256 tokenId, uint256 initialWorth, uint256 dailyFee, uint256 latestReturnTimestamp, bool stableCoin)
    public nonReentrant {
        require(lendingIsActive == true, "Lending disabled");
        require(initialWorth > 0, "No item for free here");
        require(idToLendingItem[itemId].available == true, "Item is canceled or lend out");
        require(idToLendingItem[itemId].nftContract == nftContract, "Not correct NFT address");
        require(idToLendingItem[itemId].tokenId == tokenId, "Not correct tokenId");
        require(msg.sender == idToLendingItem[itemId].lender, "You have to be the lender to update");

        idToLendingItem[itemId].initialWorth = initialWorth;
        idToLendingItem[itemId].dailyFee = dailyFee;
        idToLendingItem[itemId].latestReturnTimestamp = latestReturnTimestamp;
        idToLendingItem[itemId].stableCoin = stableCoin;

        emit ItemUpdated(itemId, nftContract, tokenId, msg.sender, initialWorth, dailyFee, latestReturnTimestamp,
            stableCoin);
    }

    function createLendingItemBorrowTFuel(uint256 itemId, address nftContract) public payable nonReentrant {
        require(idToLendingItem[itemId].available == true, "Item is not available");
        require(idToLendingItem[itemId].stableCoin == false, "Payment in stable Coin");
        require((idToLendingItem[itemId].latestReturnTimestamp - now - 3600) > 0, "latest return time lower than 1h");

        uint borrowFeeTFuelMultiplier = getBorrowFeeTFuelMultiplier(msg.sender);

        uint256 collateral = idToLendingItem[itemId].initialWorth;
        require(collateral > 0, "Item is already canceled");

        uint256 initialPlatformFee = (borrowPlatformFeeTFuel / 100) * borrowFeeTFuelMultiplier;
        uint256 estimatedCosts = collateral + initialPlatformFee;

        require(msg.value == estimatedCosts, "Send value not enough");
        // set in lendingItem
        idToLendingItem[itemId].available = false;
        idToLendingItem[itemId].borrower = payable(msg.sender);
        idToLendingItem[itemId].borrowedAtTimestamp = now;

        _itemsLend.increment();

        IERC721(nftContract).transferFrom(address(this), msg.sender, idToLendingItem[itemId].tokenId);

        (bool success,) = payable(feeAddress).call{value : initialPlatformFee}("");
        require(success, "Transfer to fee address failed.");

        LendingItem memory item = idToLendingItem[itemId];

        // Through events
        emit ItemBorrowed(item.itemId, item.nftContract, item.tokenId, item.lender, item.borrower, item.borrowTimestamp,
            item.stableCoin);
    }

    function createLendingItemBorrowStableCoin(uint256 itemId, address nftContract) public payable nonReentrant {
        require(idToLendingItem[itemId].available == true, "Item is not available");
        require(idToLendingItem[itemId].stableCoin == true, "Payment not in stable Coin");
        require((idToLendingItem[itemId].latestReturnTimestamp - now - 3600) > 0, "latest return time lower than 1h");

        uint borrowFeeTFuelMultiplier = getBorrowFeeTFuelMultiplier(msg.sender);

        uint256 collateral = idToLendingItem[itemId].initialWorth;
        require(IERC20(stableCoinAddress).allowance(msg.sender, address(this)) >= collateral);
        require(collateral > 0, "Item is already canceled");

        uint256 initialPlatformFee = (borrowPlatformFeeTFuel / 100) * borrowFeeTFuelMultiplier;

        require(msg.value == initialPlatformFee, "Send value not enough");

        // transfer stable coin
        require(IERC20(stableCoinAddress).transferFrom(msg.sender, address(this), collateral));
        // set in lendingItem
        idToLendingItem[itemId].available = false;
        idToLendingItem[itemId].borrower = payable(msg.sender);
        idToLendingItem[itemId].borrowedAtTimestamp = now;

        _itemsLend.increment();

        IERC721(nftContract).transferFrom(address(this), msg.sender, idToLendingItem[itemId].tokenId);

        (bool success,) = payable(feeAddress).call{value : initialPlatformFee}("");
        require(success, "Transfer to fee address failed.");

        LendingItem memory item = idToLendingItem[itemId];

        // Through events
        emit ItemBorrowed(item.itemId, item.nftContract, item.tokenId, item.lender, item.borrower, item.borrowTimestamp,
            item.stableCoin);
    }

    function createLendingItemCancel(uint256 itemId, address nftContract) public nonReentrant {
        require(msg.sender == idToLendingItem[itemId].lender, "You have to be the lender to cancel");
        require(idToLendingItem[itemId].available == true, "Item is canceled or lend out");

        // Read data from mappings
        uint256 tokenId = idToLendingItem[itemId].tokenId;

        // set in marketItem
        idToLendingItem[itemId].initialWorth = 0;
        idToLendingItem[itemId].available = false;

        IERC721(nftContract).transferFrom(address(this), idToLendingItem[itemId].lender, tokenId);

        // Through event
        emit ItemCanceled(itemId, nftContract, tokenId, lender);
    }

    function createLendingItemCancelAdmin(uint256 itemId, address nftContract) public nonReentrant onlyAdmin {
        require(idToLendingItem[itemId].available == true, "Item is canceled or lend out");

        // Read data from mappings
        uint256 tokenId = idToLendingItem[itemId].tokenId;

        // set in marketItem
        idToLendingItem[itemId].initialWorth = 0;
        idToLendingItem[itemId].available = false;

        IERC721(nftContract).transferFrom(address(this), idToLendingItem[itemId].lender, tokenId);

        // Through event
        emit ItemCanceled(itemId, nftContract, tokenId, lender);
    }

    function claimLendingItemCollateral(uint256 itemId, address nftContract) public nonReentrant {
        require(msg.sender == idToLendingItem[itemId].lender, "You have to be the lender to cancel");
        require(idToLendingItem[itemId].available == true, "Item is canceled or lend out");
        require(idToLendingItem[itemId].nftContract == nftContract, "Not correct NFT address");
        require((idToLendingItem[itemId].latestReturnTimestamp - now) < 0, "Still can be returned");

        // Read data from mappings
        uint256 tokenId = idToLendingItem[itemId].tokenId;
        uint256 collateral = idToLendingItem[itemId].initialWorth;
        bool stableCoin = idToLendingItem[itemId].stableCoin;

        // set in marketItem
        idToLendingItem[itemId].initialWorth = 0;
        idToLendingItem[itemId].available = false;
        idToLendingItem[itemId].lenderClaimedCollateral = true;

        if(stableCoin){
            // transfer stable coin
            require(IERC20(stableCoinAddress).transferFrom(address(this), msg.sender, collateral));
        } else {
            (bool success,) = payable(msg.sender).call{value : collateral}("");
            require(success, "Transfer to fee address failed.");
        }

        // Through event
        emit claimCollateral(itemId, nftContract, tokenId, lender, collateral, stableCoin);
    }

    function createLendingItemReturn(uint256 itemId, address nftContract) public payable nonReentrant {
        require(idToLendingItem[itemId].available == true, "Item is not available");
        require(idToLendingItem[itemId].stableCoin == false, "Payment in stable Coin");
        require((idToLendingItem[itemId].latestReturnTimestamp - now - 3600) > 0, "latest return time lower than 1h");

        uint borrowFeeTFuelMultiplier = getBorrowFeeTFuelMultiplier(msg.sender);

        uint256 collateral = idToLendingItem[itemId].initialWorth;
        require(collateral > 0, "Item is already canceled");

        uint256 initialPlatformFee = (borrowPlatformFeeTFuel / 100) * borrowFeeTFuelMultiplier;
        uint256 estimatedCosts = collateral + initialPlatformFee;

        require(msg.value == estimatedCosts, "Send value not enough");
        // set in lendingItem
        idToLendingItem[itemId].available = false;
        idToLendingItem[itemId].borrower = payable(msg.sender);
        idToLendingItem[itemId].borrowedAtTimestamp = now;

        _itemsLend.increment();

        IERC721(nftContract).transferFrom(address(this), msg.sender, idToLendingItem[itemId].tokenId);

        (bool success,) = payable(feeAddress).call{value : initialPlatformFee}("");
        require(success, "Transfer to fee address failed.");

        LendingItem memory item = idToLendingItem[itemId];

        // Through events
        emit ItemBorrowed(item.itemId, item.nftContract, item.tokenId, item.lender, item.borrower, item.borrowTimestamp,
            item.stableCoin);
    }
    /*
    * Pause listings if active
    */
    function flipListingState() onlySuperAdmin public {
        listingIsActive = !listingIsActive;
    }

    function getTier(uint tier) public view returns (Tier memory) {
        require(tier < 3, "Tier number to big");
        return sellerTiers[tier];
    }

    function getByMarketId(uint256 id) public view returns (MarketItem memory){
        require(id <= _itemIds.current(), "id doesn't exist");
        return idToLendingItem[id];
    }

    function getLendingFee() public view returns (uint256) {
        return lendingFeeBasisPoints;
    }

    function getBorrowPlatformFeeTFuel() public view returns (uint256) {
        return borrowPlatformFeeTFuel;
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