// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { WETH } from "solmate/tokens/WETH.sol";
import { QNSRegistry } from "qns/src/QNSRegistry.sol";
import { UqNFT } from "qns/src/UqNFT.sol";
import { Secrets } from "../src/Secrets.sol";

import "forge-std/console.sol";
import { TestUtils } from "./Utils.sol";

contract QNSTest is TestUtils {
    // structs
    struct Bid {
        uint256 amount;
        address bidder;
        bytes signature;
    }

    // events
    event NewSecret(bytes32 indexed messageHash, string uqname);
    event BidPlaced(bytes32 indexed messageHash, address indexed who, uint256 amount);
    event SecretRevealed(bytes32 indexed messageHash, address indexed who, bytes uqname, string secret);


    // addresses
    address public deployer = address(2);
    address public alice = address(3);
    address public bob;
    uint256 public bob_key;

    // contracts
    QNSRegistry public qnsRegistry;
    UqNFT public uqNft;
    WETH public weth;
    Secrets public secrets;

    function setUp() public {
        (bob, bob_key) = makeAddrAndKey("alice");

        vm.prank(deployer);
        QNSRegistry qnsRegistryImpl = new QNSRegistry();
        
        vm.prank(deployer);
        qnsRegistry = QNSRegistry(
            address(
                new ERC1967Proxy(
                    address(qnsRegistryImpl),
                    abi.encodeWithSelector(
                        QNSRegistry.initialize.selector
                    )
                )
            )
        );

        assertEq(qnsRegistry.owner(), address(deployer));

        vm.prank(deployer);
        UqNFT uqNftImpl = new UqNFT();

        vm.prank(deployer);
        uqNft = UqNFT(
            address(
                new ERC1967Proxy(
                    address(uqNftImpl),
                    abi.encodeWithSelector(
                        UqNFT.initialize.selector,
                        qnsRegistry
                    )
                )
            )
        );

        vm.prank(deployer);
        qnsRegistry.registerSubdomainContract(
            getDNSWire("uq"),
            uqNft
        );

        assertEq(uqNft.baseNode(), getNodeId("uq"));

        (address actualNft, uint96 actualProtocols) = qnsRegistry.records(getNodeId("uq."));

        assertEq(actualNft, address(uqNft));
        assertEq(actualProtocols, 0);

        vm.prank(alice);
        uqNft.register(getDNSWire("alices-node.uq"), alice);

        vm.prank(bob);
        uqNft.register(getDNSWire("bobs-node.uq"), bob);

        vm.prank(deployer);
        weth = new WETH();

        hoax(alice, 100 ether);
        weth.deposit{value: 100 ether}();
        
        hoax(bob, 100 ether);
        weth.deposit{value: 100 ether}();

        assertEq(weth.balanceOf(alice), 100 ether);
        assertEq(weth.balanceOf(bob), 100 ether);

        vm.prank(deployer);
        secrets = new Secrets(qnsRegistry, weth);

        assertEq(address(secrets.qns()), address(qnsRegistry));
        assertEq(address(secrets.weth()), address(weth));
    }

    function test_all() public {
        // commitSecret tests
        string memory message = "a message";
        string memory secret = "a secret";
        bytes32 messageHash = keccak256(abi.encodePacked(message));
        bytes32 commitHash = keccak256(abi.encodePacked(message, secret));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bob_key, commitHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        vm.prank(bob);
        vm.expectEmit(true, false, false, true);
        emit NewSecret(messageHash, message);
        secrets.commitSecret(message, signature);

        (uint256 amount, address bidder, bytes memory actualSig) = secrets.bids(messageHash);
        assertEq(amount, 0);
        assertEq(bidder, address(0));
        assertEq(actualSig, signature);

        /// placeBid tests
        vm.prank(alice);
        weth.approve(address(secrets), 100 ether);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit BidPlaced(messageHash, alice, 5 ether);
        secrets.placeBid(5 ether, messageHash, getDNSWire("alices-node.uq"));
    
        (uint256 amount2, address bidder2, bytes memory actualSig2) = secrets.bids(messageHash);
        assertEq(amount2, 5 ether);
        assertEq(bidder2, alice);
        assertEq(actualSig2, signature);

        // revealSecret tests
        vm.prank(bob);
        uint256 beforeAlice = weth.balanceOf(alice);
        uint256 beforeBob = weth.balanceOf(bob);
        vm.expectEmit(true, true, false, true);
        emit SecretRevealed(messageHash, bob, getDNSWire("bobs-node.uq"), secret);
        secrets.revealSecret(message, secret, getDNSWire("bobs-node.uq"));
        uint256 afterAlice = weth.balanceOf(alice);
        uint256 afterBob = weth.balanceOf(bob);
        assertEq(beforeBob + 5 ether, afterBob);
        assertEq(beforeAlice - 5 ether, afterAlice);
    }
}
