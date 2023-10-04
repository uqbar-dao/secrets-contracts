// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract RumorsPlus {

    using ECDSA for bytes32;

    event RumorRevealed(bytes32 indexed messageHash, address indexed who, string uqname);
    event NewRumor(bytes32 indexed messageHash, string uqname);

    // ERC721 public uqNft; // TODO this should be QNS and more general
    mapping(bytes32 => bytes) public signatures;

    // constructor(ERC721 _uqNft) {
    //     uqNft = _uqNft;
    // }

    function tattle(string calldata message, bytes calldata signature) public {
        bytes32 messageHash = keccak256(abi.encodePacked(message));
        bytes storage sig = signatures[messageHash]; // TODO gas efficiency?
        require(sig.length == 0, "Already posted");
        signatures[keccak256(abi.encodePacked(message))] = signature;
        emit NewRumor(messageHash, message);
    }

    // NOTE: you can NEVER recover the money IF
    //    1. you reveal the secret (someone can brute force all uqnames)
    //    2. you lose the secret (obvious)
    //    3. you transfer your QNS NFT
    function verifyTattle(string calldata message, bytes32 secret, string calldata uqname) public {
        bytes32 messageHash = keccak256(abi.encodePacked(message));
        bytes storage signature = signatures[messageHash]; 
        
        bytes32 commitHash = keccak256(abi.encodePacked(message, secret));
        address signer = commitHash.recover(signature);
        // require(signer == uqNft.ownerOf(uqNft.idOf(uqname)), "Not signed by owner");
        // TODO transfer ETH
        RumorRevealed(messageHash, signer, uqname);
    }
}