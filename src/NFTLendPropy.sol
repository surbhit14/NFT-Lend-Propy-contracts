// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {INFTLendPropy} from "./interface/INFTLendPropy.sol";

/**
 * @title NFTLendPropy
 * @dev Implementation of the NFT lending contract.
 */
contract NFTLendPropy is ReentrancyGuard, INFTLendPropy {
    IERC20 public token;

    NFT[] public listedNfts;
    uint256 public lastOfferId;
    mapping(uint256 => Offer) public offers;
    mapping(address => mapping(uint256 => Offer[])) public offersByNft;
    mapping(address => mapping(uint256 => bool)) public nftListings; // New mapping to track listed NFTs

    constructor(address _token) {
        token = IERC20(_token);
    }

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
    ) external override returns (uint256 offerId) {
        require(_interestRate > 0, "Interest rate must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        require(_amount > 0, "Amount must be greater than 0");
        require(nftListings[_nftContract][_tokenId], "NFT must be listed");

        require(_amount <= token.balanceOf(msg.sender), "Insufficient balance");
        token.transferFrom(msg.sender, address(this), _amount);
        
        offerId = lastOfferId++;

        offers[offerId] = Offer({
            nftContract: _nftContract,
            tokenId: _tokenId,
            lender: msg.sender,
            borrower: address(0),
            interestRate: _interestRate,
            duration: _duration,
            amount: _amount,
            startTime: 0,
            endTime: 0,
            active: true
        });
        offersByNft[_nftContract][_tokenId].push(offers[offerId]);
        emit LendOfferCreated(offerId, msg.sender, _nftContract, _tokenId, _amount);
    }

    /**
     * @dev Lists an NFT for lending.
     * @param _nftContract The address of the NFT contract.
     * @param _tokenId The ID of the NFT.
     */
    function listNft(address _nftContract, uint256 _tokenId) external override {
        require(IERC721(_nftContract).ownerOf(_tokenId) == msg.sender, "You do not own this NFT");
        listedNfts.push(NFT({nftContract: _nftContract, tokenId: _tokenId, listed: true}));
        nftListings[_nftContract][_tokenId] = true;

        emit NFTListed(_nftContract, _tokenId, msg.sender);
    }

    /**
     * @dev Gets the list of listed NFTs.
     * @return The list of listed NFTs.
     */
    function getListedNfts() external view override returns (NFT[] memory) {
        return listedNfts;
    }

    /**
     * @dev Delists an NFT.
     * @param _nftContract The address of the NFT contract.
     * @param _tokenId The ID of the NFT.
     */
    function delistNft(address _nftContract, uint256 _tokenId) private {
        for (uint i = 0; i < listedNfts.length; i++) {
            if (listedNfts[i].nftContract == _nftContract && listedNfts[i].tokenId == _tokenId) {
                listedNfts[i].listed = false;
                break;
            }
        }
        nftListings[_nftContract][_tokenId] = false;
    }

    function acceptOffer(uint256 _offerId) external override nonReentrant {
        Offer storage offer = offers[_offerId];
        require(offer.active, "Offer does not exist or is inactive");
        require(offer.borrower == address(0), "Offer already accepted");
        address _nftContract = offer.nftContract;
        uint256 _tokenId = offer.tokenId;

        require(IERC721(_nftContract).ownerOf(_tokenId) == msg.sender, "You do not own this NFT");

        offer.borrower = msg.sender;
        offer.startTime = block.timestamp;
        offer.endTime = block.timestamp + offer.duration;

        IERC721(_nftContract).transferFrom(msg.sender, address(this), _tokenId);
        token.transfer(msg.sender, offer.amount);

        emit OfferAccepted(_offerId, msg.sender);
    }

    function repayLend(uint256 _offerId) external override nonReentrant {
        Offer storage offer = offers[_offerId];
        require(offer.active, "Offer does not exist or is inactive");
        require(offer.borrower == msg.sender, "You did not accept this offer");
        require(block.timestamp <= offer.endTime, "Loan has expired");

        uint256 plannedDuration = offer.duration;
        uint256 principal = offer.amount;
        uint256 interestRate = offer.interestRate;
        uint256 interestPerSecond = (principal * interestRate) / plannedDuration;
        uint256 actualDuration = block.timestamp - offer.startTime;
        uint256 interest = (actualDuration * interestPerSecond) / uint256(10000);

        require(token.balanceOf(msg.sender) >= offer.amount + interest, "Insufficient balance");
        token.transferFrom(msg.sender, offer.lender, offer.amount + interest);

        address nft = offer.nftContract;
        uint256 tokenId = offer.tokenId;
        IERC721(nft).transferFrom(address(this), msg.sender, tokenId);

        offer.active = false;
        delistNft(nft, tokenId);
        emit LendRepaid(_offerId, msg.sender);
    }

    function redeemCollateral(uint256 _offerId) external override nonReentrant {
        Offer storage offer = offers[_offerId];
        require(offer.active, "Offer does not exist or is inactive");
        require(offer.lender == msg.sender, "You did not create this offer");
        require(block.timestamp > offer.endTime, "Loan has not expired");

        address nft = offer.nftContract;
        uint256 tokenId = offer.tokenId;
        IERC721(nft).transferFrom(address(this), msg.sender, tokenId);

        offer.active = false;
        delistNft(nft, tokenId);
        emit NFTClaimed(_offerId, msg.sender);
    }

    function cancelOffer(uint256 _offerId) external override nonReentrant {
        Offer storage offer = offers[_offerId];
        require(offer.active, "Offer does not exist or is inactive");
        require(offer.lender == msg.sender, "You did not create this offer");

        token.transfer(msg.sender, offers[_offerId].amount);

        offer.active = false;
        delistNft(offer.nftContract, offer.tokenId);
        emit OfferCancelled(_offerId, msg.sender);
    }

    function getOffer(uint256 _offerId) external view override returns (Offer memory) {
        return offers[_offerId];
    }

    function getOffersByNft(address _nftContract, uint256 _tokenId) external view override returns (Offer[] memory) {
        return offersByNft[_nftContract][_tokenId];
    }

    function getInterest(uint256 _offerId, uint256 startTime, uint256 endTime) external view override returns (uint256) {
        uint256 plannedDuration = offers[_offerId].duration;
        uint256 principal = offers[_offerId].amount;
        uint256 interestRate = offers[_offerId].interestRate;
        uint256 interestPerSecond = (principal * interestRate) / plannedDuration;
        uint256 actualDuration = endTime - startTime;
        uint256 interest = actualDuration * interestPerSecond;
        return interest / uint256(10000);
    }
}
