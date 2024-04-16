// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.2/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts@5.0.2/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@5.0.2/access/Ownable.sol";

contract NitroNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {

    uint private MAX_NFT_SUPPLY = 100;
    string public BASEURI;
    constructor(string memory baseURI) ERC721("Nitro Referral", "TNT-Ref") Ownable(msg.sender) {
        BASEURI = baseURI;
    }

    /**
    * Set some NFTs aside
    */
    function reserveNFTS(uint256 numberOfNfts, address _senderAddress) public onlyOwner {
        require(totalSupply() + numberOfNfts <= MAX_NFT_SUPPLY, "Not Enough NFTs available");
        for (uint i = 0; i < numberOfNfts; i++) {
            uint256 tokenId = totalSupply();
            _safeMint(_senderAddress, tokenId);
            string memory id = Strings.toString(tokenId);
            _setTokenURI(tokenId, string(abi.encodePacked(id, ".json")));
        }
    }

    /**
     * send specific addresses free NFTs
    */
    function reserveToAddresses(address[] memory _senderAddress) public onlyOwner {
        require(totalSupply()+_senderAddress.length <= MAX_NFT_SUPPLY, "Not enough NFTs available");
        for (uint i = 0; i < _senderAddress.length; i++) {
            uint256 tokenId = totalSupply();
            _safeMint(_senderAddress[i], tokenId);
            string memory id = Strings.toString(tokenId);
            _setTokenURI(tokenId, string(abi.encodePacked(id, ".json")));
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return BASEURI;
    }

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
