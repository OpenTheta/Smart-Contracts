// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

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
    function getUserVotesProposal(uint proposalID_, address user_) external view returns(uint totalVotes, uint userVotes);
    function getTotalVotesProposal(uint proposalID_) external view returns (uint256 totalVotes);
    function getOptionVotesProposal(uint proposalID_, uint8 option_) external view returns (uint256 optionVotes);
}

// Todo: Problem when tokenInfo gets changed (not eligible) could call function but nothing happens?
// maybe check if eligible in token contract instead of this contract?
// would it make sense to change if rewards are possible?

contract Vote4Reward is ReentrancyGuard {
//  Main Information
    address public superAdmin;
    address public admin;

    address public feeAddress;
    uint256 public feePermil = 5000; // percentage that is used as fee (5000 = 50%)

    uint256 public mainPot; // current TFuel amount
    uint8 public mainPotDivider = 10;
    uint256 public distributedAmount;

    /// @notice if the token is allowed to be transferred
    bool public paused;

    /// @notice Possible states that a proposal may be in
    enum TokenType {
        TNT721,
        TNT20
    }


//  TNT20 Token Information
    struct TokenInfo {
        TokenType tokenType;
        uint256 votesPerToken; // tokens per vote
        bool isEligible; // isEligible to vote
        bool rewardIsActive; // also rewards in TNT20 tokens activated (contract pays out TNT20 tokens)
        ITNT20LockupAndReward managingContract; // contract that manages the TNT20 tokens
    }
    mapping(address => TokenInfo) public votingTokens; // TNT20 Token address => TokenInfo
    address[] public tokens;

//  Proposal Information

    struct Proposal {
        // Proposal details
        bytes32 name;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 totalVotes;
        uint8 numberOfOptions;
        mapping(uint8 => bytes32) optionToName; // OptionID => Votes
        mapping(address => bool) userToPayed;
        uint256 TFuelPot;
        address[] tokens;
    }

    mapping(uint256 => Proposal) public proposals;
    using Counters for Counters.Counter;
    Counters.Counter private currentProposalId; // Id for each individual proposal
//    Proposer Information
    mapping(address => bool) public isProposer;


    /// @notice An event thats emitted when the super admin address is changed
    event SuperAdminChanged(address superAdmin, address newSuperAdmin);

    /// @notice An event thats emitted when the admin address is changed
    event AdminChanged(address admin, address newAdmin);

    /// @notice An event thats emitted when the token contract is paused
    event Paused();

    /// @notice An event thats emitted when the token contract is unpaused
    event Unpaused();

    event Received(address sender, uint amount);

    event MainPotDividerChanged(uint indexed oldMainPotDivider, uint indexed newMainPotDivider);

    //  Constructor
    constructor(address _superAdmin, address _admin, address _feeAddress) {
        require( _superAdmin != address(0), "_superAdmin is address 0");
        require( _admin != address(0), "_admin is address 0");
        require( _feeAddress != address(0), "_feeAddress is address 0");
        superAdmin = _superAdmin;
        admin = _admin;
        feeAddress = _feeAddress;
    }

    /**
     * @notice Change the admin address
     * @param superAdmin_ The address of the new super admin
     */
    function setSuperAdmin(address superAdmin_) onlySuperAdmin external {
        emit SuperAdminChanged(superAdmin, superAdmin_);
        superAdmin = superAdmin_;
    }

    /**
     * @notice Change the admin address
     * @param admin_ The address of the new admin
     *
     * Only superAdmin can change the admin to avoid potential mistakes. For example,
     * consider a senario where the admin can call both setAdmin() and setAirdropper().
     * The admin might want to call setAirdropper(0x0) to temporarily disable airdrop. However,
     * due to some implementation bugs, the admin could mistakenly call setAdmin(0x0), which
     * puts the contract into an irrecoverable state.
     */
    function setAdmin(address admin_) onlySuperAdmin external {
        emit AdminChanged(admin, admin_);
        admin = admin_;
    }

    /**
     * @notice Change the MainPotDivider
     * @param mainPotDivider_ The the new mainPotDivider
     */
    function setMainPotDivider(uint8 mainPotDivider_) onlySuperAdmin external {
        emit MainPotDividerChanged(mainPotDivider, mainPotDivider_);
        mainPotDivider = mainPotDivider_;
    }

    /**
     * @notice Pause token transfer
     */
    function pause() onlyAdmin external {
        paused = true;
        emit Paused();
    }

    /**
     * @notice Unpause token transfer
     */
    function unpause() onlyAdmin external {
        paused = false;
        emit Unpaused();
    }

//    Set Functions
    function setToken(address _tokenAddress, uint _votesPerToken, bool _isEligible, TokenType _tokenType, ITNT20LockupAndReward _managingContract, bool _rewardActive) external onlyAdmin {
        require(proposals[currentProposalId.current()].startTimestamp > block.timestamp || proposals[currentProposalId.current()].endTimestamp < block.timestamp, "Tokens can only be edited when no Proposal is active");
        bool inTokens = false;
        for(uint i=0; i<tokens.length; i++) {
            if(tokens[i] == _tokenAddress) inTokens = true;
        }
        if(_isEligible) {
            if(!inTokens) {
                tokens.push(_tokenAddress);
            }
        } else {
            if(inTokens) {
                for(uint i = 0; i < tokens.length; i++) {
                    if(tokens[i] == _tokenAddress) {
                        // Swap the element with the last element in the array
                        tokens[i] = tokens[tokens.length - 1];
                        // Remove the last element
                        tokens.pop();
                        break;
                    }
                }
            }
        }
        votingTokens[_tokenAddress] = TokenInfo({
            tokenType: _tokenType,
            votesPerToken: _votesPerToken,
            isEligible: _isEligible,
            rewardIsActive: _rewardActive,
            managingContract: _managingContract
        });
    }

//  Write Functions
    function addProposer(address proposer) external onlyAdmin {
        require(!isProposer[proposer], "Already a proposer");
        isProposer[proposer] = true;
    }

    function removeProposer(address proposer) external onlyAdmin {
        require(isProposer[proposer], "Not a proposer");
        isProposer[proposer] = false;
    }

    function createProposal(string memory _name, uint _startTimestamp, uint _endTimestamp, string[] memory _options, address[] memory _tokens) onlyProposers external {
        require(_options.length < 255, "Not Uint8");
        currentProposalId.increment();
        // Handle TFuel transfer and pot allocation logic
        uint256 newTFuel = address(this).balance + distributedAmount - mainPot;
        if(feeAddress != address(0)) {
            mainPot += (newTFuel / 2);
            uint256 payout = newTFuel - (newTFuel / 2);
            (bool success,) = payable(feeAddress).call{value : payout}("");
            require(success, "Transfer failed.");
        } else {
            mainPot += newTFuel;
        }
        // Initialize and store the new proposal
        proposals[currentProposalId.current()].name = stringToBytes32(_name);
        proposals[currentProposalId.current()].numberOfOptions = uint8(_options.length);
        proposals[currentProposalId.current()].TFuelPot = mainPot / mainPotDivider;
        proposals[currentProposalId.current()].tokens = _tokens;
        for(uint8 i=0; i < _tokens.length; i++) {
            require(_tokens[i] != address(0), "Token not set");
            require(votingTokens[_tokens[i]].managingContract != ITNT20LockupAndReward(address(0)), "ManagingContract not set");
            votingTokens[_tokens[i]].managingContract.createProposal(currentProposalId.current(), _startTimestamp, _endTimestamp, uint8(_options.length));
        }
        for(uint8 i=0; i<_options.length; i++) {
            proposals[currentProposalId.current()].optionToName[i] = stringToBytes32(_options[i]);
        }

    }

    function vote(uint256 _optionId, address[] memory _contractAddresses) external {
        require(proposals[currentProposalId.current()].startTimestamp < block.timestamp && proposals[_proposalId].endTimestamp > block.timestamp, "Proposal voting not active");
        require(proposals[currentProposalId.current()].numberOfOptions >= _option, "option does not exist");

        // Ensure voter owns the NFT or required ERC20 tokens
        for(uint8 i=0; i<_contractAddresses.length; i++) {
            address[] storage proposalTokens = proposals[currentProposalId.current()].tokens;
            bool isEligible;
            for(uint8 j=0; j<proposalTokens.length; j++) {
                if(proposalTokens[j] == _contractAddresses[i]) isEligible = true;
            }
            require(isEligible, "Not eligible to vote with token"); // checking if voting is available
            ITNT20LockupAndReward(votingTokens[_contractAddresses[i]].managingContract).voteForUser(msg.sender, uint8(_optionId));
        }
    }

    /**
     * @notice Claim Reward from voting (of all tokens). The actual voting amount is calculated here
     * @param _proposalId The the proposal ID to get the reward from
     * @param _restake Tells us to payout or restake the tokens
     */
    function claimRewards(uint256 _proposalId, bool _restake) external nonReentrant {
        require(!proposals[_proposalId].userToPayed[msg.sender], "already payed out");
        require(proposals[_proposalId].startTimestamp < block.timestamp && proposals[_proposalId].endTimestamp < block.timestamp, "Proposal has not ended");
        uint userVotes = 0;
        uint totalVotes = 0;
        address[] memory proposalTokens = proposals[_proposalId].tokens;

        for(uint8 i=0; i<proposalTokens.length; i++) {
            (uint totalTokenVotes, uint userTokenVotes) = votingTokens[proposalTokens[i]].managingContract.getUserVotesProposal(_proposalId, msg.sender);
            totalVotes += votingTokens[proposalTokens[i]].votesPerToken * totalTokenVotes;
            userVotes += votingTokens[proposalTokens[i]].votesPerToken * userTokenVotes;
        }
        // payout or restake TNT20 tokens
        if(_restake) {
            for(uint8 i=0; i<proposalTokens.length; i++) {
                if(votingTokens[proposalTokens[i]].rewardIsActive) {
                    if(votingTokens[proposalTokens[i]].tokenType == TokenType.TNT20) {
                        votingTokens[proposalTokens[i]].managingContract.relockUserPayout(_proposalId, msg.sender, totalVotes, userVotes);

                    } else {
                        votingTokens[proposalTokens[i]].managingContract.payoutUser(_proposalId, msg.sender, totalVotes, userVotes);
                    }
                }
            }
        } else {
            for(uint8 i=0; i<proposalTokens.length; i++) {
                if(votingTokens[proposalTokens[i]].rewardIsActive) {
                    votingTokens[proposalTokens[i]].managingContract.payoutUser(_proposalId, msg.sender, totalVotes, userVotes);
                }
            }
        }
        // Calculate the reward based on votes and claim logic
        uint TFuelReward = proposals[_proposalId].TFuelPot * userVotes/totalVotes;

        // payout TFuel
        mainPot -= TFuelReward;
        distributedAmount += TFuelReward;
        proposals[_proposalId].userToPayed[msg.sender] = true;
        (bool sent, ) = payable(msg.sender).call{value: TFuelReward}("");
        require(sent, "Failed to send TFuel to fee address");
    }

    /**
 * @notice Claim Reward from voting (of all tokens). The actual voting amount is calculated here
     * @param _proposalId The the proposal ID to get the reward from
     */
    function claimTFuelReward(uint256 _proposalId) external nonReentrant {
        require(!proposals[_proposalId].userToPayed[msg.sender], "already payed out");
        require(proposals[_proposalId].startTimestamp < block.timestamp && proposals[_proposalId].endTimestamp < block.timestamp, "Proposal has not ended");
        uint userVotes = 0;
        uint totalVotes = 0;
        address[] memory proposalTokens = proposals[_proposalId].tokens;

        for(uint8 i=0; i<proposalTokens.length; i++) {
            (uint totalTokenVotes, uint userTokenVotes) = votingTokens[proposalTokens[i]].managingContract.getUserVotesProposal(_proposalId, msg.sender);
            totalVotes += votingTokens[proposalTokens[i]].votesPerToken * totalTokenVotes;
            userVotes += votingTokens[proposalTokens[i]].votesPerToken * userTokenVotes;
        }
        // Calculate the reward based on votes and claim logic
        uint TFuelReward = proposals[_proposalId].TFuelPot * userVotes/totalVotes;

        // payout TFuel
        mainPot -= TFuelReward;
        distributedAmount += TFuelReward;
        proposals[_proposalId].userToPayed[msg.sender] = true;
        (bool sent, ) = payable(msg.sender).call{value: TFuelReward}("");
        require(sent, "Failed to send TFuel to fee address");
    }

    /**
 * @notice Claim Reward from voting (of all tokens). The actual voting amount is calculated here
     * @param _proposalId The the proposal ID to get the reward from
     * @param _restake Tells us to payout or restake the tokens
     */
    function claimTNT20RewardByAddresses(uint256 _proposalId, address _token, bool _restake) external nonReentrant {
        require(!proposals[_proposalId].userToPayed[msg.sender], "already payed out");
        require(proposals[_proposalId].startTimestamp < block.timestamp && proposals[_proposalId].endTimestamp < block.timestamp, "Proposal has not ended");
        uint userVotes = 0;
        uint totalVotes = 0;
        address[] memory proposalTokens = proposals[_proposalId].tokens;
        bool tokenExists = false;
        // check if _token exist
        for(uint8 i=0; i<proposalTokens.length; i++) {
            if(_token == proposalTokens[i]) tokenExists = true;
            (uint totalTokenVotes, uint userTokenVotes) = votingTokens[proposalTokens[i]].managingContract.getUserVotesProposal(_proposalId, msg.sender);
            totalVotes += votingTokens[proposalTokens[i]].votesPerToken * totalTokenVotes;
            userVotes += votingTokens[proposalTokens[i]].votesPerToken * userTokenVotes;
        }
        require(tokenExists, "Token not eligible to claim rewards");
        // payout or restake TNT20 tokens
        if(_restake) {
            if(votingTokens[_token].rewardIsActive) {
                if(votingTokens[_token].tokenType == TokenType.TNT20) {
                    votingTokens[_token].managingContract.relockUserPayout(_proposalId, msg.sender, totalVotes, userVotes);

                } else {
                    votingTokens[_token].managingContract.payoutUser(_proposalId, msg.sender, totalVotes, userVotes);
                }
            }
        } else {
            if(votingTokens[_token].rewardIsActive) {
                votingTokens[_token].managingContract.payoutUser(_proposalId, msg.sender, totalVotes, userVotes);
            }
        }
    }

    // Splits the TFuel that newly got send to this contract into the mainPot and OpenTheta's part
    function splitNewTFuel() public nonReentrant {
        require(feeAddress != address(0), "Fee address can't be zero address");
        uint256 newTFuel = address(this).balance - (mainPot - distributedAmount);
        require(newTFuel > 0, "No TFuel to split");
        uint256 feeTFuel = newTFuel/2;
        mainPot += (newTFuel - feeTFuel);
        (bool sent, ) = feeAddress.call{value: feeTFuel}("");
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

    function proposalState(uint _proposalID) public view returns (ProposalState state) {
        uint currentTime = block.timestamp;
        if(proposals[_proposalID].startTimestamp > currentTime) return ProposalState.Pending;
        if(proposals[_proposalID].endTimestamp < currentTime) return ProposalState.Ended;
        return ProposalState.Active;
    }

    // Modifiers
    modifier onlySuperAdmin {
        require(msg.sender == superAdmin, "onlySuperAdmin: only the super admin can perform this action");
        _;
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "onlyAdmin: only the admin can perform this action");
        _;
    }

    modifier onlyProposers {
        require(isProposer[msg.sender], "onlyProposers: only the proposers can perform this action");
        _;
    }

    modifier onlyWhenUnpaused {
        require(!paused, "TDropStaking::onlyWhenUnpaused: staking is paused");
        _;
    }
}