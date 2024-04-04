// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ITDrop {
    function balanceOf(address account) external view returns (uint);
    function transfer(address dst, uint rawAmount) external returns (bool);
    function transferFrom(address src, address dst, uint rawAmount) external returns (bool);
    function stakeReward(address dst, uint rawAmount) external;
    function approve(address spender, uint amount) external returns (bool);
}

interface ITDropParams {
    function stakingRewardPerBlock() external view returns (uint);
}

interface ITDropStaking {
    // External functions
    function stake(uint rawAmount) external returns (uint);
    function unstake(uint rawShares) external returns (uint);
    function estimatedTDropOwnedBy(address account) external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function delegate(address delegatee) external;
    function paused() external view returns (bool);
    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

pragma solidity ^0.8.0;

/**
 * Todo:
 * Add proper commends to each function
 * Add proper events (lock, unlock deposit should hold the total amount if it can be different)
 * add TDrop lock needs to be done before proposal created, otherwise you can't vote (active not active?)
 */

contract TDropLockupAndReward {
    ITDropStaking public tDropStaking;
    ITDrop public tDropToken;
    uint public minimumStakeAmount;
    uint public minStakingTime; // in seconds

    /// @notice The super admin address
    address public superAdmin;

    /// @notice The admin address
    address public admin;

    /// @notice The admin address
    address public v4rContract;

    /// @notice if the token is allowed to be transferred
    bool public paused;

    mapping(address => uint) public userLockedTDrop;
    uint public totalUserAmount;
    uint public totalPotAmount;
    uint public allocatedPotAmount;
    uint8 public mainPotDivider = 10;

    struct Voting {
        bool payed;
        uint votes;
        uint8 option;
    }

    struct Proposal {
        // Proposal details
        uint startTimestamp;
        uint endTimestamp;
        uint256 totalVotes;
        uint8 numberOfOptions;
        mapping(uint8 => uint256) optionToVotes;
        mapping(address => Voting) userToVoting; // Voter address => Votes
        uint256 tDropPot; // Allocated Amount per TNT20 Token
        uint256 distributedAmount;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public currentProposalID;

    enum ProposalState {
        Pending,
        Active,
        Ended,
        Canceled
    }

    event Staked(address indexed user, uint amount);
    event Lock(address indexed user, uint amount);
    event Deposit(address indexed user, uint amount);
    event Unstaked(address indexed user, uint amount);
    event Unlock(address indexed user, uint amount);
    event V4RContractChanged(address indexed oldAddress, address indexed newAddress);
    event MainPotDividerChanged(uint indexed oldMainPotDivider, uint indexed newMainPotDivider);

    /// @notice An event thats emitted when the super admin address is changed
    event SuperAdminChanged(address superAdmin, address newSuperAdmin);

    /// @notice An event thats emitted when the admin address is changed
    event AdminChanged(address admin, address newAdmin);

    /// @notice An event thats emitted when the token contract is paused
    event Paused();

    /// @notice An event thats emitted when the token contract is unpaused
    event Unpaused();

    constructor(address _superAdmin, address _admin, address _tDropStaking, address _tDropToken, uint _minimumStakeAmount) {
        require( _superAdmin != address(0), "superAdmin_ is address 0");
        require( _admin != address(0), "admin_ is address 0");
        require( _tDropStaking != address(0), "tdrop_ is address 0");
        require( _tDropToken != address(0), "tdropParams_ is address 0");
        superAdmin = _superAdmin;
        admin = _admin;
        tDropStaking = ITDropStaking(_tDropStaking);
        tDropToken = ITDrop(_tDropToken);
        minimumStakeAmount = _minimumStakeAmount;
    }

    /**
     * @notice Change the admin address
     * @param _superAdmin The address of the new super admin
     */
    function setSuperAdmin(address _superAdmin) onlySuperAdmin external {
        emit SuperAdminChanged(superAdmin, _superAdmin);
        superAdmin = _superAdmin;
    }

    /**
     * @notice Change the admin address
     * @param _admin The address of the new admin
     *
     * Only superAdmin can change the admin to avoid potential mistakes. For example,
     * consider a senario where the admin can call both setAdmin() and setAirdropper().
     * The admin might want to call setAirdropper(0x0) to temporarily disable airdrop. However,
     * due to some implementation bugs, the admin could mistakenly call setAdmin(0x0), which
     * puts the contract into an irrecoverable state.
     */
    function setAdmin(address _admin) onlySuperAdmin external {
        emit AdminChanged(admin, _admin);
        admin = _admin;
    }

    /**
     * @notice Change the V4R Contract address
     * @param _v4rContract The address of the new V4R Contract
     */
    function setV4RContract(address _v4rContract) onlySuperAdmin external {
        emit V4RContractChanged(v4rContract, _v4rContract);
        v4rContract = _v4rContract;
    }

    /**
     * @notice Change the MainPotDivider
     * @param _mainPotDivider The the new mainPotDivider
     */
    function setMainPotDivider(uint8 _mainPotDivider) onlySuperAdmin external {
        emit MainPotDividerChanged(mainPotDivider, _mainPotDivider);
        mainPotDivider = _mainPotDivider;
    }

    /**
     * @notice Change the MainPotDivider
     * @param _mainPotDivider The the new mainPotDivider
     */
    function setMinStakingTime(uint8 _minStakingTime) onlySuperAdmin external {
        minStakingTime = _minStakingTime;
    }

    /**
     * @notice Change the minimumStakeAmount
     * @param _minimumStakeAmount The the new mainPotDivider
     */
    function setMinimumStakeAmount(uint8 _minimumStakeAmount) onlySuperAdmin external {
        minimumStakeAmount = _minimumStakeAmount;
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

    /**
     * @notice Create a new proposal only V4R contract is allowed
     * @param _proposalID The address of the new V4R Contract
     * @param _startTimestamp The start Timestamp of the proposal
     * @param _endTimestamp The end Timestamp of the proposal
     * @param _numberOfOptions How many options to vote exist
     */
    function createProposal(uint _proposalID, uint _startTimestamp, uint _endTimestamp, uint8 _numberOfOptions) onlyWhenUnpaused external onlyV4R {
        require(_startTimestamp > block.timestamp && _startTimestamp < _endTimestamp, "Proposal already started");
        require(_endTimestamp > block.timestamp, "Proposal already ended");
        require(proposals[currentProposalID].endTimestamp < block.timestamp, "Last proposal must end first");
        currentProposalID = _proposalID;
        proposals[_proposalID].startTimestamp = _startTimestamp;
        proposals[_proposalID].endTimestamp = _endTimestamp;
        proposals[_proposalID].numberOfOptions = _numberOfOptions;
        // Get info to totalPot and stake unstaked TDrop
        uint holdingTDrop = tDropToken.balanceOf(address(this));
        uint stakedTDrop = tDropStaking.balanceOf(address(this));
        uint totalTDrop = holdingTDrop + stakedTDrop;
        totalPotAmount = totalTDrop - totalUserAmount - allocatedPotAmount;
        if(holdingTDrop > 0 && !tDropStaking.paused()) {
            tDropToken.approve(address(tDropStaking), holdingTDrop);
            tDropStaking.stake(holdingTDrop);
        }
        proposals[_proposalID].tDropPot = totalPotAmount / mainPotDivider;
        allocatedPotAmount += proposals[_proposalID].tDropPot;
    }

    /**
     * @notice Update the current proposal only V4R contract is allowed
     * @param _proposalID The address of the new V4R Contract
     * @param _startTimestamp The start Timestamp of the proposal
     * @param _endTimestamp The end Timestamp of the proposal
     * @param _numberOfOptions How many options to vote exist
     */
    function updateProposal(uint _proposalID, uint _startTimestamp, uint _endTimestamp, uint8 _numberOfOptions) onlyWhenUnpaused external onlyV4R {
        require(currentProposalID == _proposalID, "only current Proposal can be updated");
        require(proposals[_proposalID].startTimestamp > block.timestamp && _startTimestamp > block.timestamp && _startTimestamp < _endTimestamp, "Proposal already started");
        currentProposalID = _proposalID;
        proposals[_proposalID].startTimestamp = _startTimestamp;
        proposals[_proposalID].endTimestamp = _endTimestamp;
        proposals[_proposalID].numberOfOptions = _numberOfOptions;
        // reset Pot
        allocatedPotAmount -= proposals[_proposalID].tDropPot;
        // Get info to totalPot and stake unstaked TDrop
        uint holdingTDrop = tDropToken.balanceOf(address(this));
        uint stakedTDrop = tDropStaking.balanceOf(address(this));
        uint totalTDrop = holdingTDrop + stakedTDrop;
        totalPotAmount = totalTDrop - totalUserAmount - allocatedPotAmount;
        if(holdingTDrop > 0 && !tDropStaking.paused()) {
            tDropToken.approve(address(tDropStaking), holdingTDrop);
            tDropStaking.stake(holdingTDrop);
        }
        proposals[_proposalID].tDropPot = totalPotAmount / mainPotDivider;
        allocatedPotAmount += proposals[_proposalID].tDropPot;
    }

    /**
     * @notice Delete the current proposal only V4R contract is allowed
     * @param _proposalID the current proposal ID to get deleted
     * @param _oldProposalID The old proposal ID which becomes the current one
     */
    function deleteProposal(uint _proposalID, uint _oldProposalID) onlyWhenUnpaused external onlyV4R {
        require(currentProposalID == _proposalID, "only current Proposal can be deleted");
        require(proposals[_proposalID].startTimestamp > block.timestamp, "Proposal already active");
        currentProposalID = _oldProposalID;
        // reset Pot
        allocatedPotAmount -= proposals[_proposalID].tDropPot;
        // Delete info from mapping
        delete proposals[_proposalID];
    }

    /**
     * @notice Payout User TDrop for Voting
     * @param _proposalID The Proposal ID the user wants to get his payout for
     * @param _user The address of the user that wants to get payed out
     * @param _totalVotes The total amount of Votes that where cast in this proposal (includes TNT721 & TNT20 Votes)
     * @param _userVotes The amount of Votes that the user cast in this proposal (includes TNT721 & TNT20 Votes)
     */
    function payoutUser(uint _proposalID, address _user, uint _totalVotes, uint _userVotes) onlyV4R public {
        // Check if User already got payoutUser
        require(!proposals[_proposalID].userToVoting[_user].payed, "Already payed out TDrop");
        // Get proposal proposalPot
        uint proposalPot = proposals[_proposalID].tDropPot;
        // payout reward (proposalPot * (_userVotes / _totalVotes))
        uint rewardAmount = proposalPot * (_userVotes / _totalVotes);
        // if this is thrown there is an error in the contract
        require(proposals[_proposalID].distributedAmount + rewardAmount <= proposals[_proposalID].tDropPot, "ERROR: No TDrop left!");
        // Set user to payed
        proposals[_proposalID].userToVoting[_user].payed = true;
        uint toUnstake = rewardAmount - tDropToken.balanceOf(address(this));
        tDropStaking.unstake(toUnstake);
        require(tDropToken.transfer(_user, rewardAmount), "StakingHandler: transfer failed");
        // reduce Allocated Amount
        allocatedPotAmount -= rewardAmount;
    }

    /**
     * @notice Payout User TDrop for Voting
     * @param _user The address of the user that wants to get payed out
     */
    function relockUserPayout(uint _proposalID, address _user, uint _totalVotes, uint _userVotes) onlyV4R public {
        // Check if User already got payoutUser
        require(!proposals[_proposalID].userToVoting[_user].payed, "Already payed out TDrop");
        // Get proposal proposalPot
        uint proposalPot = proposals[_proposalID].tDropPot;
        // payout reward (proposalPot * (_userVotes / _totalVotes))
        uint rewardAmount = proposalPot * (_userVotes / _totalVotes);
        // if this is thrown there is an error in the contract
        require(proposals[_proposalID].distributedAmount + rewardAmount <= proposals[_proposalID].tDropPot, "ERROR: No TDrop left!");
        proposals[_proposalID].distributedAmount += rewardAmount;
        // Set user to payed
        proposals[_proposalID].userToVoting[_user].payed = true;
        // add to User balance
        userLockedTDrop[_user] += rewardAmount;
        totalUserAmount += rewardAmount;
        emit Lock(_user, rewardAmount);
        // reduce Allocated Amount
        allocatedPotAmount -= rewardAmount;
    }

    /**
     * @notice Multi payout User TDrop for Voting
     * @param _proposalIDs The proposalIDs the user wants to get a payout for
     * @param _user The address of the user that wants to get payed out
     * @param _totalVotes The total amount of Votes that where cast in this proposal (includes TNT721 & TNT20 Votes)
     * @param _userVotes The amount of Votes that the user cast in this proposal (includes TNT721 & TNT20 Votes)
     */
    function payoutUser(uint[] memory _proposalIDs, address _user, uint[] memory _totalVotes, uint[] memory _userVotes) onlyV4R public {
        require(_totalVotes.length == _userVotes.length && _userVotes.length == _proposalIDs.length, "Length not matching");
        uint totalPayout = 0;
        for(uint8 i = 0; i < _proposalIDs.length; i++) {
            // Check if User already got payoutUser
            if(!proposals[_proposalIDs[i]].userToVoting[_user].payed) {
                // Get proposal proposalPot
                uint proposalPot = proposals[_proposalIDs[i]].tDropPot;
                // payout reward (proposalPot * (_userVotes / _totalVotes))
                uint rewardAmount = proposalPot * (_userVotes[i] / _totalVotes[i]);
                // if this is thrown there is an error in the contract
                require(proposals[_proposalIDs[i]].distributedAmount + rewardAmount <= proposals[_proposalIDs[i]].tDropPot, "ERROR: No TDrop left!");
                // Set user to payed
                proposals[_proposalIDs[i]].userToVoting[_user].payed = true;
                totalPayout += rewardAmount;
            }
        }
        uint toUnstake = totalPayout - tDropToken.balanceOf(address(this));
        tDropStaking.unstake(toUnstake);
        require(tDropToken.transfer(_user, totalPayout), "StakingHandler: transfer failed");
        // reduce Allocated Amount
        allocatedPotAmount -= totalPayout;
    }

    /**
     * @notice Payout User TDrop for Voting
     * @param _user The address of the user that wants to get payed out
     */
    function relockUserPayout(uint[] memory _proposalIDs, address _user, uint[] memory _totalVotes, uint[] memory _userVotes) onlyV4R public {
        require(_totalVotes.length == _userVotes.length && _userVotes.length == _proposalIDs.length, "Length not matching");
        uint totalPayout = 0;
        for(uint8 i = 0; i < _proposalIDs.length; i++) {
            // Check if User already got payoutUser
            if(!proposals[_proposalIDs[i]].userToVoting[_user].payed) {
                // Get proposal proposalPot
                uint proposalPot = proposals[_proposalIDs[i]].tDropPot;
                // payout reward (proposalPot * (_userVotes / _totalVotes))
                uint rewardAmount = proposalPot * (_userVotes[i] / _totalVotes[i]);
                // if this is thrown there is an error in the contract
                require(proposals[_proposalIDs[i]].distributedAmount + rewardAmount <= proposals[_proposalIDs[i]].tDropPot, "ERROR: No TDrop left!");
                proposals[_proposalIDs[i]].distributedAmount += rewardAmount;
                // Set user to payed
                proposals[_proposalIDs[i]].userToVoting[_user].payed = true;
                totalPayout += rewardAmount;
            }
        }
        // add to User balance
        userLockedTDrop[_user] += totalPayout;
        totalUserAmount += totalPayout;
        emit Lock(_user, totalPayout);
        // reduce Allocated Amount
        allocatedPotAmount -= totalPayout;
    }

    function depositIntoPot(uint _amount) onlyWhenUnpaused public {
        require(proposals[currentProposalID].endTimestamp - minStakingTime > block.timestamp, "Deposit: currently not possible");
        require(tDropToken.transferFrom(msg.sender, address(this), _amount), "Deposit: transfer failed");

        tDropToken.approve(address(tDropStaking), _amount);
        tDropStaking.stake(_amount);

        totalPotAmount += _amount;
        emit Deposit(msg.sender, _amount);
    }

    function lock(uint _amount) onlyWhenUnpaused public {
        require(_amount >= minimumStakeAmount, "StakingHandler: amount is less than the minimum required");
        require(tDropToken.transferFrom(msg.sender, address(this), _amount), "StakingHandler: transfer failed");

        if(!tDropStaking.paused()) {
            tDropToken.approve(address(tDropStaking), _amount);
            tDropStaking.stake(_amount);
            emit Staked(msg.sender, _amount);
        }

        userLockedTDrop[msg.sender] += _amount;
        totalUserAmount += _amount;
        emit Lock(msg.sender, _amount);
    }

    function stake() public onlyAdmin {
        require(!tDropStaking.paused(), "Staking is paused");
        uint unstakedAmount = tDropToken.balanceOf(address(this));
        require(unstakedAmount > 0, "All TDrop are staked");

        tDropToken.approve(address(tDropStaking), unstakedAmount);
        tDropStaking.stake(unstakedAmount);

        emit Staked(msg.sender, unstakedAmount);
    }

    function unstake() public onlyAdmin {
        require(!tDropStaking.paused(), "Staking is paused");
        uint stakedAmount = tDropStaking.balanceOf(address(this));
        require(stakedAmount > 0, "All TDrop are staked");

        tDropStaking.unstake(stakedAmount);

        emit Unstaked(msg.sender, stakedAmount);
    }

    function unlock() public {
        uint lockedAmount = userLockedTDrop[msg.sender];
        require(lockedAmount > 0, "StakingHandler: no amount staked");
        // check if proposal active and person voted -> rest
        if(proposals[currentProposalID].endTimestamp > block.timestamp && proposals[currentProposalID].userToVoting[msg.sender].votes > 0) {
            uint userVotes = proposals[currentProposalID].userToVoting[msg.sender].votes;
            proposals[currentProposalID].optionToVotes[proposals[currentProposalID].userToVoting[msg.sender].option] -= userVotes;
            proposals[currentProposalID].totalVotes -= userVotes;
            proposals[currentProposalID].userToVoting[msg.sender].votes = 0;
        }

        uint toUnstake = lockedAmount - tDropToken.balanceOf(address(this));
        tDropStaking.unstake(toUnstake);

        require(tDropToken.transfer(msg.sender, lockedAmount), "StakingHandler: transfer failed");
        userLockedTDrop[msg.sender] = 0;
        totalUserAmount -= lockedAmount;
        emit Unstaked(msg.sender, toUnstake);
        emit Unlock(msg.sender, lockedAmount);
    }

    /**
     * @notice User Votes called by V4R contract
     * @param _user The address of the user that wants to get payed out
     * @param _option option that the user chooses
     */
    function voteForUser(address _user, uint8 _option) onlyV4R public {
        require(proposals[currentProposalID].numberOfOptions >= _option, "option does not exist");
        // check if Proposal active
        require(proposals[currentProposalID].startTimestamp < block.timestamp && proposals[currentProposalID].endTimestamp > block.timestamp, "Proposal not active");
        // check if User has votes
        uint userVotes = userLockedTDrop[_user];
        if(userVotes > 0) {
            if(proposals[currentProposalID].userToVoting[_user].votes > 0) {
                // reset already voted votes from user
                uint votedVotes = proposals[currentProposalID].userToVoting[_user].votes;
                proposals[currentProposalID].totalVotes -= votedVotes;
                proposals[currentProposalID].optionToVotes[_option] -= votedVotes;

            }
            // set votes
            proposals[currentProposalID].userToVoting[_user].votes = userVotes;
            proposals[currentProposalID].userToVoting[_user].option = _option;
            proposals[currentProposalID].totalVotes += userVotes;
            proposals[currentProposalID].optionToVotes[_option] += userVotes;
        }
    }

    /**
     * @notice Payout User TDrop for Voting
     * @param _delegatee The address of the user that wants to get payed out
     */
    function delegateStakingPower(address _delegatee) onlyAdmin public {
        tDropStaking.delegate(_delegatee);
    }

    // Getter Functions
    function getUserVotesOnProposal(uint _proposalID, address _user) public view returns(Voting memory userVoting) {
        return proposals[_proposalID].userToVoting[_user];
    }

    function getUserVotesProposal(uint _proposalID, address _user) public view returns(uint totalVotes, uint userVotes) {
        return (proposals[_proposalID].totalVotes, proposals[_proposalID].userToVoting[_user].votes);
    }

    function getTotalVotesProposal(uint _proposalID) public view returns(uint256 totalVotes) {
        return proposals[_proposalID].totalVotes;
    }

    // Todo: Do Options start at 0 or 1 change to >= if needed
    function getOptionVotesProposal(uint _proposalID, uint8 _option) public view returns(uint256 optionVotes) {
        require(proposals[_proposalID].numberOfOptions > _option, "this option did not exist");
        return proposals[_proposalID].optionToVotes[_option];
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

    modifier onlyV4R {
        require(msg.sender == v4rContract, "onlyV4R: only the v4r contract can perform this action");
        _;
    }

    modifier onlyWhenUnpaused {
        require(!paused, "TDropStaking::onlyWhenUnpaused: staking is paused");
        _;
    }
}