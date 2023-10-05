// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";

import { Secrets } from "../src/Secrets.sol";
import "qns/src/QNSRegistry.sol";

import { WETH } from "solmate/tokens/WETH.sol";

contract QNSScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address payable weth = payable(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9);
        // QNSRegistry qns = QNSRegistry(address(0x9e5ed0e7873E0d7f10eEb6dE72E87fE087A12776));

        vm.startBroadcast(deployerPrivateKey);

        Secrets secrets = new Secrets(
            QNSRegistry(0x9e5ed0e7873E0d7f10eEb6dE72E87fE087A12776),
            WETH(weth)
        );
    }
}
