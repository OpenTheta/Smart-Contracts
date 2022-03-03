// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract BulkSend {

    address admin;

    constructor() {
        admin = payable(msg.sender);
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "only the admin can perform this action");
        _;
    }

    function bulkSendTFuel(address[] calldata addresses, uint256 amount) onlyAdmin public payable returns(bool success){
        uint total = addresses.length * amount;

        require(address(this).balance >= (total * 10**18));

        //transfer to each address
        for (uint8 j = 0; j < addresses.length; j++) {
            payable(addresses[j]).transfer(amount * 10**18);
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
