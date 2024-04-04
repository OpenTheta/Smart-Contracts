// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface Market {
    function createMarketSale(address nftContract, uint256 itemId) external payable;
    function getByMarketId(uint256 id) external view returns(MarketItem memory);
    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 highestOffer;
        address bidder;
        string category;
        uint256 price;
        bool isSold;
    }
}

contract SweepMarket is Ownable {

    address public MARKET;

    constructor(address _market) {
        MARKET = _market;
    }

    function buyNFTs(uint256[] memory itemIds) public payable {
        require(itemIds.length <= 50, "To long");
        uint256 totalPrice = 0;
        uint256[] memory NFTprices = new uint256[](itemIds.length);
        address[] memory NFTaddresses = new address[](itemIds.length);
        uint256[] memory NFTtokenIds = new uint256[](itemIds.length);
        for(uint16 c=0; c<itemIds.length; c++) {
            Market.MarketItem memory item = Market(MARKET).getByMarketId(itemIds[c]);
            totalPrice += item.price;
            NFTprices[c] = item.price;
            NFTaddresses[c] = item.nftContract;
            NFTtokenIds[c] = item.tokenId;
            require(!item.isSold, "NFT sold");
        }
        require(msg.value == totalPrice, "Wrong amount of TFuel");
        for(uint16 c=0; c<itemIds.length; c++) {
            (bool success, ) = MARKET.call{value: NFTprices[c]}(abi.encodeWithSignature("createMarketSale(address,uint256)", NFTaddresses[c], itemIds[c]));
            require(success, "Failed to execute Market sale");
            IERC721(NFTaddresses[c]).transferFrom(address(this), msg.sender, NFTtokenIds[c]);
        }
    }
}