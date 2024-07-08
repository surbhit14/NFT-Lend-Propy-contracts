// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "../src/NFTLendPropy.sol";
import "../src/FactoryNFTLendPropy.sol";

contract DeployContracts is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the FactoryNFTLendPropy contract
        FactoryNFTLendPropy factory = new FactoryNFTLendPropy();
        console.log("FactoryNFTLendPropy deployed at:", address(factory));

        // Create a new lending contract using the factory
        factory.createLendContract(usdcAddress);

        address lendContractAddress = factory.getLendContract(0);
        console.log("NFTLendPropy deployed at:", lendContractAddress);

        vm.stopBroadcast();
    }
}
