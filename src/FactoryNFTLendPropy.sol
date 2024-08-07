// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./NFTLendPropy.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title FactoryNFTLendPropy
 * @dev This contract is a factory for creating new instances of NFTLendPropy contracts.
 */
contract FactoryNFTLendPropy is ReentrancyGuard {
    // Array to store all created NFTLendPropy contract addresses
    address[] public allLends;

    // Event emitted when a new NFTLendPropy contract is created
    event LendContractCreated(address indexed lendContract);

    /**
     * @dev Creates a new instance of NFTLendPropy with a specified ERC20 token.
     * @param _token The address of the ERC20 token to be used for lends.
     */
    function createLendContract(address _token) external nonReentrant {
        // Create a new instance of NFTLendPropy contract
        NFTLendPropy lend = new NFTLendPropy(_token);
        // Add the address of the new lend contract to the array
        allLends.push(address(lend));
        // Emit an event to log the creation of the new lend contract
        emit LendContractCreated(address(lend));
    }

    /**
     * @dev Returns the number of lend contracts deployed.
     * @return The number of lend contracts deployed.
     */
    function getLendContractCount() external view returns (uint256) {
        return allLends.length;
    }

    /**
     * @dev Returns the address of a lend contract by index.
     * @param index The index of the lend contract in the array.
     * @return The address of the lend contract.
     */
    function getLendContract(uint256 index) external view returns (address) {
        require(index < allLends.length, "Index out of bounds");
        return allLends[index];
    }
}
