// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title INFTLendPropy
 * @dev Interface for the NFTLendPropy contract.
 */
interface INFTLendPropy {
    struct NFT {
        address nftContract;
        uint256 tokenId;
        bool listed;
    }

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

    struct Pool {
        uint256 totalDeposits;
        uint256 totalInterestPaid;
        mapping(address => uint256) deposits;
        address[] depositors;
    }

    event LendOfferCreated(uint256 offerId, address lender, address nftContract, uint256 tokenId, uint256 amount);
    event NFTListed(address nftContract, uint256 tokenId, address owner);
    event OfferAccepted(uint256 offerId, address borrower);
    event LendRepaid(uint256 offerId, address borrower);
    event NFTClaimed(uint256 offerId, address lender);
    event OfferCancelled(uint256 offerId, address lender);
    event DepositMade(address indexed provider, uint256 amount);
    event WithdrawalMade(address indexed provider, uint256 amount);

    function createOffer(
        address _nftContract,
        uint256 _tokenId,
        uint256 _interestRate,
        uint256 _duration,
        uint256 _amount
    ) external returns (uint256 offerId);

    function listNft(address _nftContract, uint256 _tokenId) external;

    function getListedNfts() external view returns (NFT[] memory);

    function delistNft(address _nftContract, uint256 _tokenId) external;

    function acceptOffer(uint256 _offerId) external;

    function repayLend(uint256 _offerId) external;

    function claimNFT(uint256 _offerId) external;

    function cancelOffer(uint256 _offerId) external;

    function getOffer(uint256 _offerId) external view returns (Offer memory);

    function getOffersByNft(address _nftContract, uint256 _tokenId) external view returns (Offer[] memory);

    function getInterest(uint256 _offerId, uint256 startTime, uint256 endTime) external view returns (uint256);

    function deposit(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function distributeInterest(uint256 _interest) external;
}
