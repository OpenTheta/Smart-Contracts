// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract Token {

    uint8 public decimals;

    function transfer(address _to, uint256 _value) public returns (bool success) {}

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {}

    function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {}
}

contract MultiSend {

    address public admin;
    uint public tokenSendFee; // in wei
    uint public tFuelSendFee; // in wei

    constructor() {
        admin = payable(msg.sender);
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "only the admin can perform this action");
        _;
    }

    function bulkSendTFuel(address[] addresses, uint256[] amounts) public payable returns(bool success){
        uint total = 0;
        for(uint8 i = 0; i < amounts.length; i++){
            total = total + amounts[i];
        }

        //ensure that the TFuel is enough to complete the transaction
        uint requiredAmount = total + tFuelSendFee * 1 wei; //.add(total.div(100));
        require(msg.value >= (requiredAmount * 1 wei));

        //transfer to each address
        for (uint8 j = 0; j < addresses.length; j++) {
            addresses[j].transfer(amounts[j] * 1 wei);
        }

        //return change to the sender
        if(msg.value * 1 wei > requiredAmount * 1 wei){
            uint change = msg.value - requiredAmount;
            msg.sender.transfer(change * 1 wei);
        }
        return true;
    }

    function bulkSendTFuelFixed(address[] addresses, uint256 amount) public payable returns(bool success){
        uint total = addresses.length * amount;

        //ensure that the TFuel is enough to complete the transaction
        uint requiredAmount = total + tFuelSendFee * 1 wei; //.add(total.div(100));
        require(msg.value >= (requiredAmount * 1 wei));

        //transfer to each address
        for (uint8 j = 0; j < addresses.length; j++) {
            addresses[j].transfer(amount * 1 wei);
        }

        //return change to the sender
        if(msg.value * 1 wei > requiredAmount * 1 wei){
            uint change = msg.value - requiredAmount;
            msg.sender.transfer(change * 1 wei);
        }
        return true;
    }

    /**
 * @notice Change the admin address
     * @param admin_ The address of the new admin
     */
    function setAdmin(address admin_) onlyAdmin external {
        admin = admin_;
    }

    receive() external payable {}

    function retrieveMoney(uint256 amount) onlyAdmin external {
        require(amount <= address(this).balance, "You can not withdraw more money than there is");
        payable(msg.sender).transfer(amount);
    }
}
