// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "../src/NFTLendPropy.sol";
import "../src/FactoryNFTLendPropy.sol";
import "../src/SampleERC20.sol";
import "../src/SampleERC721.sol";

contract NFTLendPropyTest is Test {
    FactoryNFTLendPropy factory;
    NFTLendPropy lendContract;
    SampleERC20 erc20;
    SampleERC721 erc721;
    address owner;
    address borrower;
    address lender;
    uint256 borrowerTokenId;

    function setUp() public {
        owner = address(this);
        borrower = address(0x2);
        lender = address(0x3);

        vm.deal(borrower, 1 ether);
        vm.deal(lender, 1 ether);

        // Deploy Sample ERC20 and ERC721 tokens
        erc20 = new SampleERC20("SampleToken", "STK", 1_000_000 * 10 ** 18);
        erc721 = new SampleERC721("SampleNFT", "SNFT");

        // Mint ERC20 tokens to borrower and lender
        erc20.mint(borrower, 1_000 * 10 ** 18);
        erc20.mint(lender, 1_000 * 10 ** 18);

        // Mint an ERC721 token to the borrower
        borrowerTokenId = erc721.mint(borrower);

        // Log the ownership of the ERC721 token
        emit log_named_address("ERC721 Owner after minting", erc721.ownerOf(borrowerTokenId));

        // Deploy the factory and create a lend contract
        factory = new FactoryNFTLendPropy();
        factory.createLendContract(address(erc20));
        lendContract = NFTLendPropy(factory.getLendContract(0));

        emit log_named_address("Owner", owner);
        emit log_named_address("Borrower", borrower);
        emit log_named_address("Lender", lender);
    }

    function testListNFT() public {
        uint256 newTokenId = erc721.mint(borrower); // Mint a new token for this test
        emit log_named_uint("New Token ID", newTokenId);
        emit log_named_address("New ERC721 Owner after minting", erc721.ownerOf(newTokenId));

        vm.startPrank(borrower);
        erc721.approve(address(lendContract), newTokenId);
        lendContract.listNft(address(erc721), newTokenId);
        vm.stopPrank();

        NFTLendPropy.NFT[] memory listedNfts = lendContract.getListedNfts();
        assertEq(listedNfts.length, 1); // We expect 1 NFT listed now
        assertEq(listedNfts[0].nftContract, address(erc721));
        assertEq(listedNfts[0].tokenId, newTokenId);

        emit log_named_address("NFT Contract", address(erc721));
        emit log_named_uint("Token ID", newTokenId);
        emit log_named_uint("Total Listed NFTs", listedNfts.length);
    }

    function testListNFTRevertNotOwner() public {
        vm.startPrank(owner);
        vm.expectRevert("You do not own this NFT");
        lendContract.listNft(address(erc721), borrowerTokenId);
        vm.stopPrank();
    }

    function testCreateOffer() public {
        uint256 amount = 10 ether;
        uint256 duration = 100 days;

        // List the NFT
        vm.startPrank(borrower);
        erc721.approve(address(lendContract), borrowerTokenId);
        lendContract.listNft(address(erc721), borrowerTokenId);
        vm.stopPrank();

        vm.startPrank(lender);
        erc20.approve(address(lendContract), amount);
        uint256 offerId = lendContract.createOffer(address(erc721), borrowerTokenId, 500, duration, amount);
        vm.stopPrank();

        NFTLendPropy.Offer memory offer = lendContract.getOffer(offerId);
        assertEq(offer.lender, lender);
        assertEq(offer.amount, amount);

        emit log_named_address("NFT Contract", address(erc721));
        emit log_named_uint("Token ID", borrowerTokenId);
        emit log_named_uint("Offer ID", offerId);
        emit log_named_address("Lender", offer.lender);
        emit log_named_uint("Amount", offer.amount);
    }

    function testAcceptOffer() public {
        uint256 amount = 10 ether;
        uint256 duration = 100 days;

        // List the NFT
        vm.startPrank(borrower);
        erc721.approve(address(lendContract), borrowerTokenId);
        lendContract.listNft(address(erc721), borrowerTokenId);
        vm.stopPrank();

        vm.startPrank(lender);
        erc20.approve(address(lendContract), amount);
        uint256 offerId = lendContract.createOffer(address(erc721), borrowerTokenId, 500, duration, amount);
        vm.stopPrank();

        vm.startPrank(borrower);
        lendContract.acceptOffer(offerId);
        vm.stopPrank();

        NFTLendPropy.Offer memory offer = lendContract.getOffer(offerId);
        assertEq(offer.borrower, borrower);

        emit log_named_uint("Offer ID", offerId);
        emit log_named_address("Borrower", offer.borrower);
    }

    function testRepayLend() public {
        uint256 amount = 10 ether;
        uint256 duration = 100 days;

        // List the NFT
        vm.startPrank(borrower);
        erc721.approve(address(lendContract), borrowerTokenId);
        lendContract.listNft(address(erc721), borrowerTokenId);
        vm.stopPrank();

        vm.startPrank(lender);
        erc20.approve(address(lendContract), amount);
        uint256 offerId = lendContract.createOffer(address(erc721), borrowerTokenId, 500, duration, amount);
        vm.stopPrank();

        vm.startPrank(borrower);
        lendContract.acceptOffer(offerId);

        erc20.approve(address(lendContract), amount * 2);
        lendContract.repayLend(offerId);
        vm.stopPrank();

        NFTLendPropy.Offer memory offer = lendContract.getOffer(offerId);
        assertEq(offer.active, false);

        emit log_named_uint("Offer ID", offerId);
        emit log_named_uint("Amount Repaid", amount * 2);
    }

    function testClaimCollateral() public {
        uint256 amount = 10 ether;
        uint256 duration = 100 days;

        // List the NFT
        vm.startPrank(borrower);
        erc721.approve(address(lendContract), borrowerTokenId);
        lendContract.listNft(address(erc721), borrowerTokenId);
        vm.stopPrank();

        vm.startPrank(lender);
        erc20.approve(address(lendContract), amount);
        uint256 offerId = lendContract.createOffer(address(erc721), borrowerTokenId, 500, duration, amount);
        vm.stopPrank();

        vm.startPrank(borrower);
        lendContract.acceptOffer(offerId);
        vm.stopPrank();

        vm.warp(block.timestamp + duration + 1);

        vm.startPrank(lender);
        lendContract.redeemCollateral(offerId);
        vm.stopPrank();

        NFTLendPropy.Offer memory offer = lendContract.getOffer(offerId);
        assertEq(offer.active, false);
        assertEq(erc721.ownerOf(borrowerTokenId), lender);

        emit log_named_uint("Offer ID", offerId);
        emit log_named_address("Collateral Owner", lender);
    }
}
