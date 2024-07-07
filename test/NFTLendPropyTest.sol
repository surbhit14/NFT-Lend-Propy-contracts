// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFTLendPropy.sol";
import "../src/FactoryNFTLendPropy.sol";
import "../src/SampleERC20.sol";
import "../src/SampleERC721.sol";

contract NFTLendPropyTest is Test {
    NFTLendPropy lendContract;
    SampleERC20 erc20;
    SampleERC721 erc721;
    address owner;
    address borrower;
    address lender;
    uint256 borrowerTokenId;

    function setUp() public {
        owner = address(this);
        borrower = address(1);
        lender = address(2);

        // Deploy Sample ERC20 and ERC721 tokens
        erc20 = new SampleERC20("SampleToken", "STK", 1_000_000 * 10 ** 18);
        erc721 = new SampleERC721("SampleNFT", "SNFT");

        // Mint ERC721 token to borrower
        borrowerTokenId = erc721.mint(borrower);

        // Transfer ERC20 tokens to lender
        erc20.transfer(lender, 1000 ether);

        // Deploy the lending contract
        lendContract = new NFTLendPropy(address(erc20));
    }

    function testListNFT() public {
        vm.startPrank(borrower);
        erc721.approve(address(lendContract), borrowerTokenId);
        lendContract.listNft(address(erc721), borrowerTokenId);

        NFTLendPropy.NFT[] memory listedNfts = lendContract.getListedNfts();
        assertEq(listedNfts.length, 1);
        assertEq(listedNfts[0].nftContract, address(erc721));
        assertEq(listedNfts[0].tokenId, borrowerTokenId);

        // Log for verification
        emit log_named_address("ERC721 Owner after listing", erc721.ownerOf(borrowerTokenId));
        vm.stopPrank();
    }

    function testCreateOffer() public {
        uint256 amount = 10 ether;
        uint256 duration = 100 days;

        vm.startPrank(borrower);
        erc721.approve(address(lendContract), borrowerTokenId);
        lendContract.listNft(address(erc721), borrowerTokenId);
        vm.stopPrank();

        vm.startPrank(lender);
        erc20.approve(address(lendContract), amount);
        uint256 offerId = lendContract.createOffer(address(erc721), borrowerTokenId, 500, duration, amount);

        NFTLendPropy.Offer memory offer = lendContract.getOffer(offerId);
        assertEq(offer.lender, lender);
        assertEq(offer.amount, amount);
        assertEq(offer.nftContract, address(erc721));
        assertEq(offer.tokenId, borrowerTokenId);
        vm.stopPrank();
    }

    function testAcceptOffer() public {
        uint256 amount = 10 ether;
        uint256 duration = 100 days;

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

        NFTLendPropy.Offer memory offer = lendContract.getOffer(offerId);
        assertEq(offer.borrower, borrower);

        // Log for verification
        emit log_named_address("ERC721 Owner after accepting offer", erc721.ownerOf(borrowerTokenId));
        vm.stopPrank();
    }

    function testRepayLend() public {
        uint256 amount = 10 ether;
        uint256 duration = 100 days;

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

        uint256 interest = lendContract.getInterest(offerId, block.timestamp, block.timestamp + duration);
        uint256 totalRepayment = amount + interest;

        erc20.approve(address(lendContract), totalRepayment);
        lendContract.repayLend(offerId);

        NFTLendPropy.Offer memory offer = lendContract.getOffer(offerId);
        assertEq(offer.active, false);

        // Log for verification
        emit log_named_address("ERC721 Owner after repayment", erc721.ownerOf(borrowerTokenId));
        vm.stopPrank();
    }

    function testRedeemCollateral() public {
        uint256 amount = 10 ether;
        uint256 duration = 100 days;

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

        // Fast forward time to expire the loan duration
        vm.warp(block.timestamp + duration + 1);

        vm.startPrank(lender);
        lendContract.redeemCollateral(offerId);

        NFTLendPropy.Offer memory offer = lendContract.getOffer(offerId);
        assertEq(offer.active, false);
        assertEq(erc721.ownerOf(borrowerTokenId), lender);

        // Log for verification
        emit log_named_address("ERC721 Owner after redeeming collateral", erc721.ownerOf(borrowerTokenId));
        vm.stopPrank();
    }

    function testCancelOffer() public {
        uint256 amount = 10 ether;
        uint256 duration = 100 days;

        vm.startPrank(borrower);
        erc721.approve(address(lendContract), borrowerTokenId);
        lendContract.listNft(address(erc721), borrowerTokenId);
        vm.stopPrank();

        vm.startPrank(lender);
        erc20.approve(address(lendContract), amount);
        uint256 offerId = lendContract.createOffer(address(erc721), borrowerTokenId, 500, duration, amount);

        lendContract.cancelOffer(offerId);

        NFTLendPropy.Offer memory offer = lendContract.getOffer(offerId);
        assertEq(offer.active, false);

        // Log for verification
        emit log_named_address("ERC20 Balance after cancelling offer", erc20.balanceOf(lender));
        vm.stopPrank();
    }
}
