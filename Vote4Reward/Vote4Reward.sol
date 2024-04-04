pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ITNT20Pot {

    function createNewPot(uint256 potID) external returns (uint256 tokenAmount);

//    function getSalesFee() external view returns (uint256);
}

interface ITNT20LockupAndReward {
    struct Voting {
        bool payed;
        uint votes;
        uint8 option;
    }
    // External functions
    function createProposal(uint proposalID_, uint startTimestamp_, uint endTimestamp_, uint8 numberOfOptions_) external;
    function updateProposal(uint proposalID_, uint startTimestamp_, uint endTimestamp_, uint8 numberOfOptions_) external;
    function deleteProposal(uint proposalID_, uint oldProposalID_) external;
    function payoutUser(uint proposalID_, address user_, uint totalVotes_, uint userVotes_) external;
    function relockUserPayout(uint proposalID_, address user_, uint totalVotes_, uint userVotes_) external;
    function payoutUser(uint[] calldata proposalIDs_, address user_, uint[] calldata totalVotes_, uint[] calldata userVotes_) external;
    function relockUserPayout(uint[] calldata proposalIDs_, address user_, uint[] calldata totalVotes_, uint[] calldata userVotes_) external;
    function voteForUser(address user_, uint8 option_) external;
    function getUserVotesOnProposal(uint proposalID_, address user_) external view returns (Voting memory userVoting);
    function getTotalVotesProposal(uint proposalID_) external view returns (uint256 totalVotes);
    function getOptionVotesProposal(uint proposalID_, uint8 option_) external view returns (uint256 optionVotes);
}


interface IVOTE {

}

contract Vote4Reward is Ownable, ReentrancyGuard {
//  Main Information
    address public superAdmin;
    address public admin;

    address public feeAddress;
    uint256 public feePermil = 5000; // percentage that is used as fee (5000 = 50%)

    uint256 public mainPot; // current TFuel amount
    uint8 public mainPotDivider = 10;
    uint256 public distributedAmount;

    address public TNT721Collection;
//    mapping(address => mapping(address => uint256)) public ownerToTNT20TokenAmount;

//  TNT20 Token Information
    struct TokenInfo {
        IERC20 token; // contract address of Token
        uint256 tokensPerVote; // tokens per vote
        bool isEligible; // isEligible to vote
        bool rewardIsActive; // also rewards in TNT20 tokens activated
        ITNT20Pot managingContract; // contract that manages the TNT20 tokens
    }
    mapping(address => TokenInfo) public votingTokens; // TNT20 Token address => TokenInfo
    address[] public TNT20tokens;

//  Proposal Information
    struct VoteOptions {
        bytes32 name;
        uint256 votes;
    }

    struct Proposal {
        // Proposal details
        bytes32 name;
        uint256 totalVotes;
        uint8 numberOfOptions;
        mapping(uint8 => VoteOptions) optionToVotes; // OptionID => Votes
        mapping(address => uint256) userToVotes; // Voter address => Votes
        mapping(uint16 => address) TNT721ToVoter;
        uint256 TFuelPot;
        mapping(address => uint256) TNT20ToPot; // Allocated Amount per TNT20 Token
        address[] TNT20tokenPots;
    }

    mapping(uint256 => Proposal) public proposals;
    using Counters for Counters.Counter;
    Counters.Counter private nextProposalId; // Id for each individual proposal
//    Proposer Information
    mapping(address => bool) public isProposer;
    address[] public proposers;

//  Voter Information
    struct VoterInfo {
        mapping(uint256 => uint256) proposalToVotes;
    }

    mapping(address => mapping(address => uint256)) public ownerToTNT20TokenAmount;

//  Constructor
    constructor(address _nftCollection, address _rewardsWallet) {
        nftCollection = IERC721(_nftCollection);
        erc20Token = IERC20(_erc20Token);
        rewardsWallet = _rewardsWallet;
    }

//  Event called when a new Item is created
    // Event to log received Ethers
    event Received(address sender, uint amount);

    event DutchAuctionCreated(uint256 indexed itemId, address indexed nftContract, uint256 indexed tokenId,
        uint256 startPrice, uint256 endPrice, uint256 startTimestamp, uint256 endTimestamp, address sellerAddress);

//  Write Functions

    function addProposer(address proposer) external onlyOwner {
        require(!isProposer[proposer], "Already a proposer");
        isProposer[proposer] = true;
        proposers.push(proposer);
    }

    function removeProposer(address proposer) external onlyOwner {
        require(isProposer[proposer], "Not a proposer");
        isProposer[proposer] = false;
        proposers.pop(proposer);
    }

    function createProposal(string memory _name, string[] memory _options, address[] _TNT20tokenPots) external {
        require(isProposer[msg.sender], "Not a proposer");
        // Handle TFuel transfer and pot allocation logic
        uint256 newTFuel = address(this).balance + distributedAmount - mainPot;
        if(rewardsWallet != address(0)) {
            mainPot += (newTFuel / 2);
            uint256 payout = newTFuel - (newTFuel / 2);
            (bool success,) = payable(rewardsWallet).call{value : payout}("");
            require(success, "Transfer failed.");
        } else {
            mainPot += newTFuel;
        }
        // Initialize and store the new proposal
        proposals[nextProposalId].name = _name;
        proposals[nextProposalId].numberOfOptions = _options.length;
        proposals[nextProposalId].TFuelPot = mainPot / mainPotDivider;
        proposals[nextProposalId].TNT20tokenPots = _TNT20tokenPots;
        for(uint8 i; i=0; i<_TNT20tokenPots.length) {
            TNT20ToPot[_TNT20tokenPots[i]] = TNT20Pot(_TNT20tokenPots[i]).createNewPot(nextProposalId);
        }
        for(uint8 i; i=0; i<_options.length) {
            proposals[nextProposalId].optionToVotes[i].name = stringToBytes32(_options[i]);
        }

    }

    function vote(uint256 proposalId, uint256 optionId, address contractAddress) external {
        // Ensure voter owns the NFT or required ERC20 tokens
        // Record the vote
    }

    function claimReward(uint256 proposalId) external {
        // Calculate the reward based on votes and claim logic
    }

    // Splits the TFuel that newly got send to this contract into the mainPot and OpenTheta's part
    function splitNewTFuel() public nonReentrant {
        require(feeAddress != address(0), "Fee address can't be zero address");
        uint256 newTFuel = address(this).balance - (mainPot - distributedAmount);
        require(newTFuel > 0, "No TFuel to split");
        uint256 feeTFuel = newTFuel/2;
        mainPot += (newTFuel - feeTFuel);
        (bool sent, bytes memory data) = _to.call{value: feeTFuel}("");
        require(sent, "Failed to send TFuel to fee address");
    }

    // Additional helper functions as needed
    function stringToBytes32(string memory source) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }

    // The receive function
    receive() external payable {
        // Emit an event for logging
        emit Received(msg.sender, msg.value);
    }

    // Fallback function in case receive is not triggered
    fallback() external payable {
        // Fallback logic or simply revert/ignore the transaction
    }

//  Read Functions
    // Returns the amount of TFuel that is newly in the smart contract and wasn't split yet
    function getNewTFuelToSplit() public view returns(uint256) {
        return address(this).balance - (mainPot - distributedAmount);
    }
}