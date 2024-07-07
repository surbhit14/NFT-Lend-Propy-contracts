// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title INFTLendPropy
 * @dev Interface for the NFTLendPropy contract.
 */
interface INFTLendPropy {
    /**
     * @dev Struct to represent an NFT.
     * @param nftContract The address of the NFT contract.
     * @param tokenId The ID of the NFT.
     * @param listed A boolean indicating if the NFT is listed.
     */
    struct NFT {
        address nftContract;
        uint256 tokenId;
        bool listed;
    }

    /**
     * @dev Struct to represent a lending offer.
     * @param nftContract The address of the NFT contract.
     * @param tokenId The ID of the NFT.
     * @param lender The address of the lender.
     * @param borrower The address of the borrower.
     * @param interestRate The interest rate for the loan.
     * @param duration The duration of the loan.
     * @param amount The amount of tokens to be lent.
     * @param startTime The start time of the loan.
     * @param endTime The end time of the loan.
     * @param active A boolean indicating if the offer is active.
     */
    struct Offer {
        address nftContract;
        uint256 tokenId;
        address lender;
        address borrower;
        uint256 interestRate;
        uint256 duration;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }

    // Events to log various actions in the contract
    event LendOfferCreated(uint256 offerId, address lender, address nftContract, uint256 tokenId, uint256 amount);
    event NFTListed(address nftContract, uint256 tokenId, address owner);
    event OfferAccepted(uint256 offerId, address borrower);
    event LendRepaid(uint256 offerId, address borrower);
    event NFTClaimed(uint256 offerId, address lender);
    event OfferCancelled(uint256 offerId, address lender);
    event DepositMade(address indexed provider, uint256 amount);
    event WithdrawalMade(address indexed provider, uint256 amount);

    /**
     * @dev Creates a lending offer for a listed NFT.
     * @param _nftContract The address of the NFT contract.
     * @param _tokenId The ID of the NFT.
     * @param _interestRate The interest rate for the loan.
     * @param _duration The duration of the loan.
     * @param _amount The amount of tokens to be lent.
     * @return offerId The ID of the created offer.
     */
    function createOffer(
        address _nftContract,
        uint256 _tokenId,
        uint256 _interestRate,
        uint256 _duration,
        uint256 _amount
    ) external returns (uint256 offerId);

    /**
     * @dev Lists an NFT for lending.
     * @param _nftContract The address of the NFT contract.
     * @param _tokenId The ID of the NFT.
     */
    function listNft(address _nftContract, uint256 _tokenId) external;

    /**
     * @dev Gets the list of listed NFTs.
     * @return The list of listed NFTs.
     */
    function getListedNfts() external view returns (NFT[] memory);

    /**
     * @dev Accepts a lending offer.
     * @param _offerId The ID of the offer.
     */
    function acceptOffer(uint256 _offerId) external;

    /**
     * @dev Repays the loan.
     * @param _offerId The ID of the offer.
     */
    function repayLend(uint256 _offerId) external;

    /**
     * @dev Redeems the collateral if the loan is not repaid.
     * @param _offerId The ID of the offer.
     */
    function redeemCollateral(uint256 _offerId) external;

    /**
     * @dev Cancels a lending offer.
     * @param _offerId The ID of the offer.
     */
    function cancelOffer(uint256 _offerId) external;

    /**
     * @dev Gets the details of a lending offer.
     * @param _offerId The ID of the offer.
     * @return The details of the offer.
     */
    function getOffer(uint256 _offerId) external view returns (Offer memory);

    /**
     * @dev Gets the offers for a specific NFT.
     * @param _nftContract The address of the NFT contract.
     * @param _tokenId The ID of the NFT.
     * @return The offers for the NFT.
     */
    function getOffersByNft(address _nftContract, uint256 _tokenId) external view returns (Offer[] memory);

    /**
     * @dev Calculates the interest for a loan.
     * @param _offerId The ID of the offer.
     * @param startTime The start time of the loan.
     * @param endTime The end time of the loan.
     * @return The interest for the loan.
     */
    function getInterest(uint256 _offerId, uint256 startTime, uint256 endTime) external view returns (uint256);
}
