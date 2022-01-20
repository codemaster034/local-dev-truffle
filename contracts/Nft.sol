// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Nft is ERC721 {
    constructor() ERC721("NFT Token", "NFT") {
        _mint(msg.sender, 56);
        _mint(msg.sender, 23);
    }
}
