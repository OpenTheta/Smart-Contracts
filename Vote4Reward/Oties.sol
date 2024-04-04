// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

abstract contract TNT721Votes is ERC721 {
    //  Main Information
    address public superAdmin;
    address public admin;
    address public v4rContract;

    mapping(address => bool) public userToVoteActive;
    struct Voting {
        uint votes;
        uint8 option;
    }
    struct Proposal {
        // Proposal details
        mapping(address => bool) userToVoted;
        uint startTimestamp;
        uint endTimestamp;
        uint256 totalVotes;
        uint8 numberOfOptions;
        mapping(uint8 => uint256) optionToVotes;
        mapping(address => Voting) userToVoting; // Voter address => Votes
    }
    mapping(uint256 => Proposal) public proposals;
    uint public currentProposalID;

    enum ProposalState {
        Pending,
        Active,
        Ended,
        Canceled
    }



    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal override virtual {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
        _transferVotingUnits(from, to, batchSize);
    }

//    function _transferVotingUnits(address _previousOwner, address _to, uint _amount) internal {
//        if(proposalState(currentProposalID) == ProposalState.Active) {
//            if(proposals[currentProposalID].userToVoted[_previousOwner]) {
//                proposals[currentProposalID].totalVotes -= _amount;
//                proposals[currentProposalID].optionToVotes[proposals[currentProposalID].userToVoting[_previousOwner].option] -= _amount;
//            }
//            if(proposals[currentProposalID].userToVoted[_to]) {
//                proposals[currentProposalID].totalVotes += _amount;
//                proposals[currentProposalID].optionToVotes[proposals[currentProposalID].userToVoting[_to].option] += _amount;
//            }
//        }
//    }
    function _transferVotingUnits(address _previousOwner, address _to, uint _amount) internal {
        // Check the proposal state once and store it
        ProposalState currentState = proposalState(currentProposalID);

        if (currentState != ProposalState.Active) {
            return; // Exit early if the proposal is not active
        }

        // Cache proposal in memory to reduce state reads
        Proposal storage currentProposal = proposals[currentProposalID];

        if (currentProposal.userToVoted[_previousOwner]) {
            uint8 previousOwnerOption = currentProposal.userToVoting[_previousOwner].option;
            currentProposal.totalVotes -= _amount;
            currentProposal.optionToVotes[previousOwnerOption] -= _amount;
        }
        if (currentProposal.userToVoted[_to]) {
            uint8 toOption = currentProposal.userToVoting[_to].option;
            currentProposal.totalVotes += _amount;
            currentProposal.optionToVotes[toOption] += _amount;
        }
    }

    function createProposal(uint _proposalID, uint _startTimestamp, uint _endTimestamp, uint8 _numberOfOptions) onlyV4R external {
        require(proposalState(currentProposalID) == ProposalState.Ended, "Proposal hasn't ended");
        proposals[_proposalID].startTimestamp = _startTimestamp;
        proposals[_proposalID].endTimestamp = _endTimestamp;
        proposals[_proposalID].numberOfOptions = _numberOfOptions;
        currentProposalID = _proposalID;
    }

    function updateProposal(uint _proposalID, uint _startTimestamp, uint _endTimestamp, uint8 _numberOfOptions) onlyV4R external {
        require(currentProposalID == _proposalID, "only current Proposal can be updated");
        require(proposalState(_proposalID) == ProposalState.Pending, "Proposal already active");
        proposals[_proposalID].startTimestamp = _startTimestamp;
        proposals[_proposalID].endTimestamp = _endTimestamp;
        proposals[_proposalID].numberOfOptions = _numberOfOptions;
    }

    /**
     * @notice Delete the current proposal only V4R contract is allowed
     * @param _proposalID the current proposal ID to get deleted
     * @param _oldProposalID The old proposal ID which becomes the current one
     */
    function deleteProposal(uint _proposalID, uint _oldProposalID) onlyV4R external {
        require(currentProposalID == _proposalID, "only current Proposal can be deleted");
        require(proposalState(_proposalID) == ProposalState.Pending, "Proposal already active");
        currentProposalID = _oldProposalID;
        // Delete info from mapping
        delete proposals[_proposalID];
    }

    function voteForUser(address _user, uint8 _option) onlyV4R external {
        require(proposals[currentProposalID].numberOfOptions >= _option, "option does not exist");
        // check if Proposal active
        require(proposalState(currentProposalID) == ProposalState.Active, "Proposal not active");
        require(!proposals[currentProposalID].userToVoted[_user], "user already voted");
        // check if User has votes
        uint userVotes = balanceOf(_user);
        if(userVotes > 0) {
            proposals[currentProposalID].userToVoting[_user].option = _option;
            proposals[currentProposalID].userToVoting[_user].votes = balanceOf(_user);
            proposals[currentProposalID].optionToVotes[_option] += balanceOf(_user);
            proposals[currentProposalID].totalVotes += balanceOf(_user);
        }
        proposals[currentProposalID].userToVoted[_user] = true;
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

    modifier onlyV4R {
        require(msg.sender == v4rContract, "onlyV4R: only the v4r contract can perform this action");
        _;
    }
}


contract Oties is TNT721Votes {
    constructor() ERC721("Oties", "Oties") {}

    function mint(address to, uint256 tokenID) public {
        super._mint(to, tokenID);
    }

}