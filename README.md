# NFT Lending Smart Contracts

This project consists of a set of smart contracts that facilitate the lending and borrowing of funds using NFTs (Non-Fungible Tokens) as collateral. The primary objective is to create a secure and efficient mechanism for users to leverage their NFT assets to obtain liquidity without having to sell their valuable collectibles. The platform allows borrowers to lock up their NFTs in exchange for a loan of a specified amount of USDC (or other ERC20 tokens), with clearly defined interest rates and loan terms. This approach provides both borrowers and lenders with a transparent and decentralized way to engage in NFT-backed lending.

![image](https://github.com/surbhit14/NFT-Lend-Propy-contracts/assets/82264758/ff981524-07a6-4b4f-946b-b7f6e8dab9c0)


## Project Overview
In the rapidly growing world of digital assets, NFTs have emerged as a significant asset class, representing ownership of unique items such as digital art, collectibles, and virtual real estate. However, the liquidity of NFTs remains a challenge as they are typically illiquid assets, meaning it can be difficult to quickly convert them into cash without selling them. This project addresses this issue by enabling NFT owners to borrow against their NFTs, unlocking liquidity while still retaining ownership of their assets.

### Components
![Architechture diagram 2](https://github.com/surbhit14/NFT-Lend-Propy-contracts/assets/82264758/48177a79-80fd-4ed0-9cb8-c3211fc9dd87)

1. **FactoryNFTLendPropy**: This contract acts as a factory for creating new instances of `NFTLendPropy` contracts. It simplifies the deployment of multiple lending contracts, each handling different ERC20 tokens for loans.

2. **NFTLendPropy**: This is the core contract that handles the lending and borrowing logic. It manages the listing of NFTs, creation of loan offers, acceptance of offers, loan repayment, and collateral management.

3. **INFTLendPropy**: This interface defines the structures and functions used in the `NFTLendPropy` contract, ensuring consistency and modularity in the contract design.

### Workflow
![Untitled-2024-07-07-1917](https://github.com/surbhit14/NFT-Lend-Propy-contracts/assets/82264758/73e9d2e9-7cfb-43a8-a110-c3ef2cbd286e)


1. **Borrower Lists NFT**: The borrower initiates the process by listing their NFT as collateral. This involves approving the NFT to the `NFTLendPropy` contract and calling the `listNft` function.

2. **Lender Creates Offer**: Interested lenders can create loan offers by specifying the terms, including the interest rate, loan duration, and amount. They approve the specified amount of ERC20 tokens to the `NFTLendPropy` contract and call the `createOffer` function.

3. **Borrower Accepts Offer**: The borrower reviews the offers and accepts a suitable one by calling the `acceptOffer` function. This transfers the NFT to the contract and the loan amount to the borrower.

4. **Borrower Repays Loan**: To reclaim their NFT, the borrower repays the loan amount along with the accrued interest by calling the `repayLend` function.

5. **Lender Claims Collateral**: If the borrower fails to repay the loan within the specified duration, the lender can claim the collateral by calling the `redeemCollateral` function.

6. **Lender Cancels Offer**: If the offer has not been accepted by any borrower, the lender can cancel the offer and retrieve their approved tokens by calling the `cancelOffer` function.

### Key Features

1. **Decentralized Lending and Borrowing**: The platform operates on smart contracts deployed on the Ethereum blockchain, ensuring a decentralized and trustless environment for lending and borrowing.

2. **NFT Collateralization**: Users can use their NFTs as collateral to secure loans. This allows NFT owners to access liquidity without having to sell their NFTs.

3. **Transparent Loan Terms**: Interest rates, loan durations, and amounts are clearly defined and agreed upon by both parties before initiating the loan, ensuring transparency and fairness.

4. **Interest Calculation**: The contracts automatically calculate the interest based on the agreed-upon rate and duration, providing an accurate and fair repayment amount.

5. **Collateral Management**: The smart contracts manage the transfer and return of collateral (NFTs) securely, ensuring that NFTs are only transferred when loan conditions are met or default occurs.

6. **Automated Loan Repayment and Collateral Release**: Upon repayment of the loan and interest, the collateralized NFT is automatically returned to the borrower. If the borrower defaults, the collateral is transferred to the lender.

### Security and Efficiency

The smart contracts are designed with security and efficiency in mind:

- **Reentrancy Guard**: The contracts utilize the `ReentrancyGuard` from OpenZeppelin to prevent reentrancy attacks.
- **Data Validation**: Various checks are implemented to validate data inputs, ensuring the correctness and integrity of operations.
- **Transparent Transactions**: All transactions and state changes are recorded on the blockchain, providing a transparent and immutable record of all activities.

This project aims to provide a robust and reliable platform for NFT-backed lending, offering users a new way to unlock liquidity from their NFT assets while maintaining ownership and control.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

