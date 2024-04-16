// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.2/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts@5.0.2/access/Ownable.sol";

contract NitroNFT is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable {

    uint private MAX_NFT_SUPPLY = 1000;
    uint public PRICE = 500000000000000000000;
    address public ThetaNitroTokenAddress;
    string public BASEURI;
    bool public saleIsActive;
    uint public Minted = 0;

    constructor(string memory baseURI) ERC721("NitroNFT", "TNT721") Ownable(msg.sender) {
        BASEURI = baseURI;
    }

    /**
    * @dev Gets current Price
    */
    function getNFTPrice() public view returns (uint256) {
        return PRICE;
    }

    /*
    * Mint token if sale is active and total supply < max supply
    */
    function safeMint(address to) public payable {
        require(saleIsActive, "Sale must be active to mint");
        require(Minted < MAX_NFT_SUPPLY, "Already all NFTs Minted");
        require(getNFTPrice() <= msg.value, "Wrong value");
        Minted++;
        _safeMint(to, Minted);
        string memory id = Strings.toString(Minted);
        _setTokenURI(Minted, string(abi.encodePacked(id, ".json")));
    }

    /*
    * Mint token if sale is active and total supply < max supply
    */
    function safeMintQuantity(address to, uint8 quantity) public payable {
        require(saleIsActive, "Sale must be active to mint");
        require(Minted + quantity <= MAX_NFT_SUPPLY, "Purchase would exceed max supply");
        require(getNFTPrice() * quantity <= msg.value, "Wrong value");
        for (uint i = 0; i < quantity; i++) {
            Minted++;
            _safeMint(to, Minted);
            string memory id = Strings.toString(Minted);
            _setTokenURI(Minted, string(abi.encodePacked(id, ".json")));
        }
    }

    /*
    * Pause sale if active, make active if paused
    */
    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function burn(uint256[] memory tokenIds, address owner) public virtual {
        require(msg.sender == ThetaNitroTokenAddress,"Only Nitro Contract Allowed");
        uint ts = totalSupply();
        uint payout = (address(this).balance * tokenIds.length) / ts;
        for (uint i = 0; i < tokenIds.length; i++) {
            require(owner == this.ownerOf(tokenIds[i]), "Not owner of NFT");
            super.burn(tokenIds[i]);
        }

        if(totalSupply() == 0) {
            payout = address(this).balance;
        }
        payable(ThetaNitroTokenAddress).transfer(payout);
    }

    function setNitroAddress(address nitro) public onlyOwner {
        ThetaNitroTokenAddress = nitro;
    }

    function _baseURI() internal view override returns (string memory) {
        return BASEURI;
    }

    receive() external payable {}

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
    internal
    override(ERC721, ERC721Enumerable)
    returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
    internal
    override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable, ERC721URIStorage)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
