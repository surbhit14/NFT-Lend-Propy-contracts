// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {INFTLendPropy} from "./INFTLendPropy.sol";

/**
 * @title NFTLendPropy
 * @dev This contract allows users to create lend offers, list NFTs as collateral, and accept offers.
 * It also includes functionality for liquidity providers to deposit and withdraw funds.
 */
contract NFTLendPropy is INFTLendPropy, ReentrancyGuard {
    address public token;

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
        address[] depositors; // List of depositors
    }

    NFT[] public listedNfts;
    uint256 public lastOfferId;
    mapping(uint256 => Offer> public offers;
    mapping(address => mapping(uint256 => Offer[])) public offersByNft;
    mapping(address => mapping(uint256 => bool)) public isNFTListed;
    Pool public liquidityPool;

    event LendOfferCreated(uint256 offerId, address lender, address nftContract, uint256 tokenId, uint256 amount);
    event NFTListed(address nftContract, uint256 tokenId, address owner);
    event OfferAccepted(uint256 offerId, address borrower);
    event LendRepaid(uint256 offerId, address borrower);
    event NFTClaimed(uint256 offerId, address lender);
    event OfferCancelled(uint256 offerId, address lender);
    event DepositMade(address indexed provider, uint256 amount);
    event WithdrawalMade(address indexed provider, uint256 amount);

    /**
     * @dev Constructor to initialize the contract.
     * @param _token The address of the ERC20 token to be used for lends.
     */
    constructor(address _token) {
        token = _token;
    }

    /**
     * @dev Creates a lend offer with the specified parameters.
     * @param _nftContract The address of the NFT contract.
     * @param _tokenId The ID of the NFT to be used as collateral.
     * @param _interestRate The interest rate for the lend.
     * @param _duration The duration of the lend.
     * @param _amount The amount of the lend.
     * @return offerId The ID of the created offer.
     */
    function createOffer(
        address _nftContract,
        uint256 _tokenId,
        uint256 _interestRate,
        uint256 _duration,
        uint256 _amount
    ) public nonReentrant returns (uint256 offerId) {
        require(isNFTListed[_nftContract][_tokenId], "NFT not listed for collateral");
        require(_interestRate > 0, "Interest rate must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= IERC20(token).balanceOf(msg.sender), "Insufficient balance");

        IERC20(token).transferFrom(msg.sender, address(this), _amount);

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
     * @dev Lists an NFT as collateral.
     * @param _nftContract The address of the NFT contract.
     * @param _tokenId The ID of the NFT to be listed.
     */
    function listNft(address _nftContract, uint256 _tokenId) external nonReentrant {
        require(IERC721(_nftContract).ownerOf(_tokenId) == msg.sender, "You do not own this NFT");
        listedNfts.push(NFT({nftContract: _nftContract, tokenId: _tokenId, listed: true}));
        IERC721(_nftContract).transferFrom(msg.sender, address(this), _tokenId);
        isNFTListed[_nftContract][_tokenId] = true;

        emit NFTListed(_nftContract, _tokenId, msg.sender);
    }

    /**
     * @dev Gets the list of NFTs currently listed as collateral.
     * @return An array of listed NFTs.
     */
    function getListedNfts() public view returns (NFT[] memory) {
        return listedNfts;
    }

    /**
     * @dev Delists an NFT from the collateral list.
     * @param _nftContract The address of the NFT contract.
     * @param _tokenId The ID of the NFT to be delisted.
     */
    function delistNft(address _nftContract, uint256 _tokenId) private {
        for (uint i = 0; i < listedNfts.length; i++) {
            if (listedNfts[i].nftContract == _nftContract && listedNfts[i].tokenId == _tokenId) {
                listedNfts[i].listed = false;
                break;
            }
        }
        isNFTListed[_nftContract][_tokenId] = false;
    }

    /**
     * @dev Accepts a lend offer.
     * @param _offerId The ID of the offer to be accepted.
     */
    function acceptOffer(uint256 _offerId) public nonReentrant {
        require(offers[_offerId].active == true, "Offer does not exist");
        require(offers[_offerId].borrower == address(0), "Offer already accepted");
        address _nftContract = offers[_offerId].nftContract;
        uint256 _tokenId = offers[_offerId].tokenId;

        require(IERC721(_nftContract).ownerOf(_tokenId) == msg.sender, "You do not own this NFT");

        offers[_offerId].borrower = msg.sender;
        offers[_offerId].startTime = block.timestamp;
        offers[_offerId].endTime = block.timestamp + offers[_offerId].duration;

        IERC721(_nftContract).transferFrom(msg.sender, address(this), _tokenId);
        IERC20(token).transfer(msg.sender, offers[_offerId].amount);

        emit OfferAccepted(_offerId, msg.sender);
    }

    /**
     * @dev Repays a lend.
     * @param _offerId The ID of the offer to be repaid.
     */
    function repayLend(uint256 _offerId) public nonReentrant {
        require(offers[_offerId].active == true, "Offer does not exist");
        require(offers[_offerId].borrower == msg.sender, "You did not accept this offer");
        require(offers[_offerId].endTime > block.timestamp, "Lend has expired");

        uint256 plannedDuration = offers[_offerId].duration;
        uint256 principal = offers[_offerId].amount;
        uint256 interestRate = offers[_offerId].interestRate;
        uint256 interestPerSecond = (principal * interestRate) / plannedDuration;
        uint256 actualDuration = block.timestamp - offers[_offerId].startTime;
        uint256 interest = (actualDuration * interestPerSecond) / uint256(10000);

        require(IERC20(token).balanceOf(msg.sender) >= offers[_offerId].amount + interest, "Insufficient balance");
        IERC20(token).transferFrom(msg.sender, offers[_offerId].lender, offers[_offerId].amount + interest);

        address nft = offers[_offerId].nftContract;
        uint256 tokenId = offers[_offerId].tokenId;
        IERC721(nft).transferFrom(address(this), msg.sender, tokenId);

        offers[_offerId].active = false;
        delistNft(nft, tokenId);

        emit LendRepaid(_offerId, msg.sender);
    }

    /**
     * @dev Claims the NFT collateral if the lend is not repaid on time.
     * @param _offerId The ID of the offer.
     */
    function claimNFT(uint256 _offerId) public nonReentrant {
        require(offers[_offerId].active == true, "Offer does not exist");
        require(offers[_offerId].lender == msg.sender, "You did not create this offer");
        require(offers[_offerId].endTime < block.timestamp, "Lend has not expired");

        address nft = offers[_offerId].nftContract;
        uint256 tokenId = offers[_offerId].tokenId;
        IERC721(nft).transferFrom(address(this), msg.sender, tokenId);

        offers[_offerId].active = false;
        delistNft(offers[_offerId].nftContract, offers[_offerId].tokenId);

        emit NFTClaimed(_offerId, msg.sender);
    }

    /**
     * @dev Cancels a lend offer.
     * @param _offerId The ID of the offer to be cancelled.
     */
    function cancelOffer(uint256 _offerId) public nonReentrant {
        require(offers[_offerId].active == true, "Offer does not exist");
        require(offers[_offerId].lender == msg.sender, "You did not create this offer");

        IERC20(token).transferFrom(address(this), msg.sender, offers[_offerId].amount);

        offers[_offerId].active = false;
        delistNft(offers[_offerId].nftContract, offers[_offerId].tokenId);

        emit OfferCancelled(_offerId, msg.sender);
    }

    /**
     * @dev Gets the details of a lend offer.
     * @param _offerId The ID of the offer.
     * @return The details of the offer.
     */
    function getOffer(uint256 _offerId) public view returns (Offer memory) {
        return offers[_offerId];
    }

    /**
     * @dev Gets the lend offers for a specific NFT.
     * @param _nftContract The address of the NFT contract.
     * @param _tokenId The ID of the NFT.
     * @return An array of offers for the specified NFT.
     */
    function getOffersByNft(address _nftContract, uint256 _tokenId) public view returns (Offer[] memory) {
        return offersByNft[_nftContract][_tokenId];
    }

    /**
     * @dev Calculates the interest for a lend.
     * @param _offerId The ID of the offer.
     * @param startTime The start time of the lend.
     * @param endTime The end time of the lend.
     * @return The calculated interest.
     */
    function getInterest(uint256 _offerId, uint256 startTime, uint256 endTime) public view returns (uint256) {
        uint256 plannedDuration = offers[_offerId].duration;
        uint256 principal = offers[_offerId].amount;
        uint256 interestRate = offers[_offerId].interestRate;
        uint256 interestPerSecond = (principal * interestRate) / plannedDuration;
        uint256 actualDuration = endTime - startTime;
        uint256 interest = actualDuration * interestPerSecond;
        return interest / uint256(10000);
    }

    /**
     * @dev Deposits ERC20 tokens into the liquidity pool.
     * @param _amount The amount of tokens to deposit.
     */
    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        IERC20(token).transferFrom(msg.sender, address(this), _amount);

        if (liquidityPool.deposits[msg.sender] == 0) {
            liquidityPool.depositors.push(msg.sender);
        }

        liquidityPool.totalDeposits += _amount;
        liquidityPool.deposits[msg.sender] += _amount;

        emit DepositMade(msg.sender, _amount);
    }

    /**
     * @dev Withdraws ERC20 tokens from the liquidity pool.
     * @param _amount The amount of tokens to withdraw.
     */
    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(liquidityPool.deposits[msg.sender] >= _amount, "Insufficient balance");

        liquidityPool.deposits[msg.sender] -= _amount;
        liquidityPool.totalDeposits -= _amount;
        IERC20(token).transfer(msg.sender, _amount);

        if (liquidityPool.deposits[msg.sender] == 0) {
            for (uint256 i = 0; i < liquidityPool.depositors.length; i++) {
                if (liquidityPool.depositors[i] == msg.sender) {
                    liquidityPool.depositors[i] = liquidityPool.depositors[liquidityPool.depositors.length - 1];
                    liquidityPool.depositors.pop();
                    break;
                }
            }
        }

        emit WithdrawalMade(msg.sender, _amount);
    }

    /**
     * @dev Distributes the interest among the liquidity providers.
     * @param _interest The total interest to be distributed.
     */
    function distributeInterest(uint256 _interest) internal {
        uint256 totalDeposits = liquidityPool.totalDeposits;
        if (totalDeposits == 0) {
            return;
        }

        for (uint256 i = 0; i < liquidityPool.depositors.length; i++) {
            address provider = liquidityPool.depositors[i];
            uint256 providerShare = (liquidityPool.deposits[provider] * _interest) / totalDeposits;
            liquidityPool.totalInterestPaid += providerShare;
            IERC20(token).transfer(provider, providerShare);
        }
    }
}
