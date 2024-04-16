// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface ITNT721 {
    function safeMint(address to, string memory uri) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract Nitro is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    uint public transactionFeeBasisPoints = 0;
    address public ReferralNFT;
    mapping(address => bool) public whitelistedWallets;
    mapping(uint => address) public referralIdToAddress;
    uint256[] public FeeBasisPoints = [100, 130, 160, 190, 220, 250, 280, 310, 340, 370, 400, 430, 460, 490];
    uint256[] public  MintDays = [0, 3, 8, 15, 24, 35, 48, 63, 80, 99, 120, 143, 168, 195, 224];

    //Dates
    uint public startTimestamp = 175434;

    constructor(address defaultAdmin, address manager, address referralNFT)
    ERC20("Theta Nitro Token", "TNT")
    {
        ReferralNFT = referralNFT;
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MANAGER_ROLE, manager);
    }

    function getMintFeeBasisPoints() public view returns(uint256) {
        uint timeElapsed = block.timestamp - startTimestamp;
        if(timeElapsed < 16934400) { // 196 days
            uint daysElapsed = timeElapsed / 1 days;
            for(uint i = 0; i < 14; i++) {
                if(daysElapsed <= MintDays[i]) {
                    return FeeBasisPoints[i];
                }
            }
        } else {
            return 500;
        }
        return 500;
    }

    function mintingIsActive() public view returns(bool) {
        uint timeElapsed = block.timestamp - startTimestamp;
        uint daysElapsed = timeElapsed / 1 days;
        if(timeElapsed < 19440000) { // 225 days
            for(uint i = 0; i < 15; i++) {
                if(daysElapsed == MintDays[i]) {
                    return true;
                }
                if(daysElapsed < MintDays[i]) {
                    return false;
                }
            }
        } else {
            return (daysElapsed - 224) % 31 < 1;
        }
        return false;
    }

    function setWhitelistedWallet(address wallet, bool whitelist) public onlyRole(MANAGER_ROLE) {
        whitelistedWallets[wallet] = whitelist;
    }

    function setTransactionFeeBasisPoints(uint basisPoints) public onlyRole(MANAGER_ROLE) {
        require(basisPoints <= 500, "Not allowed, to high fee");
        transactionFeeBasisPoints = basisPoints;
    }

    function mint(address to) public payable {
        require(mintingIsActive(), "Minting is not active");
        uint256 amount = 10 * msg.value;
        uint256 oldBalance = address(this).balance - amount;
        if(oldBalance != 0 && totalSupply() != 0) {
            amount = (oldBalance * amount) / totalSupply();
        }
        // Calculate transaction fee
        uint256 fee = (amount * getMintFeeBasisPoints()) / 10000;
        // Deduct the fee from the transferred amount
        amount = amount - fee;

        _mint(to, amount);
        // Todo through event of newly minted tokens and to which ration
    }

    // Todo check if still fare because of higher minting gas cost
    function mintWithReferral(address to, uint referralId) public payable {
        require(mintingIsActive(), "Minting is not active");
        address referrer = referralIdToAddress[referralId];
        require(referrer != address(0), "Zero Address is not valid");
        uint256 amount = msg.value;
        uint256 oldBalance = address(this).balance - amount;
        if(oldBalance != 0 && totalSupply() != 0) {
            amount = (oldBalance * amount) / totalSupply();
        }
        // Calculate transaction fee
        uint256 fee = (amount * getMintFeeBasisPoints()) / 10000;
        // Deduct the fee from the transferred amount
        amount = amount - fee;
        _mint(to, amount);

        // split fee and transfer
        uint referralReward = fee * 2000 / 10000;
        payable(referrer).transfer(referralReward);
        // Todo through event of newly minted tokens and to which ration
    }

    function burn(uint256 amount) public virtual override {
        if(mintingIsActive()) {
            uint256 supply = totalSupply();
            super.burn(amount);
            uint tfuel = (amount * address(this).balance) / supply;
            payable(msg.sender).transfer(tfuel);
        } else {
            uint256 supply = totalSupply();
            super.burn(amount);
            uint tfuel = (amount * address(this).balance) / supply;
            uint fee = tfuel * transactionFeeBasisPoints / 10000;
            tfuel -= fee;
            payable(msg.sender).transfer(tfuel);
        }

    }

    function setReferralIdToAddress(uint tokenId, address wallet) public {
        require(ITNT721(ReferralNFT).ownerOf(tokenId) == msg.sender, "Not holding NFT");
        referralIdToAddress[tokenId] = wallet;
    }

//    function transfer(address to, uint256 value) public virtual override returns (bool) {
//        uint256 fee;
//        // Check if either sender or recipient is whitelisted, but not both
//        if(whitelistedWallets[msg.sender] && whitelistedWallets[to]) {
//            fee = 0;
//        } else if (whitelistedWallets[msg.sender] || whitelistedWallets[to]) {
//            // Calculate 50% of the transaction fee
//            fee = (value * transactionFeeBasisPoints) / 20000;
//        } else if (!whitelistedWallets[msg.sender] && !whitelistedWallets[to]) {
//            // Calculate full transaction fee if neither is whitelisted
//            fee = (value * transactionFeeBasisPoints) / 10000;
//        }
//
//        // Deduct the fee from the transferred amount
//        uint256 amountAfterFee = value - fee;
//
//        // Transfer the adjusted amount
//        _transfer(_msgSender(), to, amountAfterFee);
//
//        // Burn the transaction fee only if there is a fee
//        if (fee > 0) {
//            _burn(_msgSender(), fee);
//        }
//
//        return true;
//    }

    function _transfer(address from, address to, uint256 amount) internal virtual override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fee;
        if(whitelistedWallets[msg.sender] && whitelistedWallets[to]) {
            fee = 0;
        } else if (whitelistedWallets[msg.sender] || whitelistedWallets[to]) {
            // Calculate 50% of the transaction fee
            fee = (amount * transactionFeeBasisPoints) / 20000;
        } else if (!whitelistedWallets[msg.sender] && !whitelistedWallets[to]) {
            // Calculate full transaction fee if neither is whitelisted
            fee = (amount * transactionFeeBasisPoints) / 10000;
        }

        uint256 amountAfterFee = amount - fee;

        super._transfer(from, to, amountAfterFee);
        if (fee > 0) {
            super._burn(from, fee);
        }
    }

//    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
//        if (!whitelistedWallets[msg.sender] && !whitelistedWallets[recipient]) {
//            // Calculate transaction fee
//            uint256 fee = (amount * transactionFeeBasisPoints) / 10000;
//            // Deduct the fee from the transferred amount
//            uint256 amountAfterFee = amount - fee;
//            // Transfer the adjusted amount
//            _transfer(_msgSender(), recipient, amountAfterFee);
//            // Burn the transaction fee
//            _burn(_msgSender(), fee);
//        } else {
//            // Transfer without any fee
//            _transfer(_msgSender(), recipient, amount);
//        }
//        return true;
//    }

    function getTFuelPerToken() public view returns(uint) {
        return address(this).balance * 10^18 / totalSupply();
    }

    receive() external payable {}
}