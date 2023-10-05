// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "qns/src/QNSRegistry.sol";

import { WETH } from "solmate/tokens/WETH.sol";

contract Secrets {

    using ECDSA for bytes32;

    struct Bid {
        uint256 amount;
        address bidder;
        bytes signature;
        // TODO bool revealed;
    }

    event NewSecret(bytes32 indexed messageHash, string uqname);
    event BidPlaced(bytes32 indexed messageHash, address indexed who, uint256 amount);
    event SecretRevealed(bytes32 indexed messageHash, address indexed who, bytes uqname, string secret);

    QNSRegistry public qns;
    WETH public weth;
    mapping(bytes32 => Bid) public bids;

    constructor(QNSRegistry _qns, WETH _weth) {
        qns = _qns;
        weth = _weth;
    }

    function commitSecret(string calldata message, bytes calldata _signature) public {
        bytes32 messageHash = keccak256(abi.encodePacked(message));
        Bid storage bid = bids[messageHash];
        require(bid.signature.length == 0, "Secrets: Already posted");
        bid.signature = _signature;
        emit NewSecret(messageHash, message);
    }

    function placeBid(uint256 amount, bytes32 messageHash, bytes calldata uqname) public {
        Bid storage bid = bids[messageHash];
        require(bid.signature.length >= 0, "Secrets: Secret doesn't exist");
        require(bid.amount < amount, "Secrets: Bid too low");
        require(weth.allowance(msg.sender, address(this)) >= amount, "Secrets: Insufficient allowance");
        require(weth.balanceOf(msg.sender) >= amount, "Secrets: Insufficient balance");
        require(qns.resolve(uqname) == msg.sender, "Secrets: Not owner"); // shoe-horned in here, don't need this
        bid.amount = amount;
        bid.bidder = msg.sender;

        emit BidPlaced(messageHash, msg.sender, amount);
    }

    // NOTE: you can NEVER recover the money if
    //    1. you lose the secret (duh)
    //    2. you transfer your QNS NFT
    function revealSecret(string calldata message, string calldata secret, bytes calldata uqname) public {
        bytes32 messageHash = keccak256(abi.encodePacked(message));
        Bid storage bid = bids[messageHash]; 
        
        bytes32 commitHash = keccak256(abi.encodePacked(message, secret));
        address signer = commitHash.recover(bid.signature);
        require(signer == qns.resolve(uqname), "Secrets: Not signed by owner");

        assert(weth.transferFrom(bid.bidder, signer, bids[messageHash].amount));

        emit SecretRevealed(messageHash, signer, uqname, secret);
    }
}