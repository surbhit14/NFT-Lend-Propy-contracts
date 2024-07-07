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
        owner = address(1);
        borrower = address(2);
        lender = address(3);

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

        // Deploy the factory and create a lend contract
        factory = new FactoryNFTLendPropy();
        factory.createLendContract(address(erc20));
        lendContract = NFTLendPropy(factory.getLendContract(0));

        // Approve and list the NFT
        vm.startPrank(borrower);
        erc721.approve(address(lendContract), borrowerTokenId);
        lendContract.listNft(address(erc721), borrowerTokenId);
        vm.stopPrank();
    }

    function testListNFT() public {
        vm.startPrank(borrower);
        lendContract.listNft(address(erc721), borrowerTokenId);

        NFTLendPropy.NFT[] memory listedNfts = lendContract.getListedNfts();
        assertEq(listedNfts.length, 1);
        assertEq(listedNfts[0].nftContract, address(erc721));
        assertEq(listedNfts[0].tokenId, borrowerTokenId);
        vm.stopPrank();
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

        vm.startPrank(lender);
        erc20.approve(address(lendContract), amount);
        uint256 offerId = lendContract.createOffer(address(erc721), borrowerTokenId, 500, duration, amount);

        NFTLendPropy.Offer memory offer = lendContract.getOffer(offerId);
        assertEq(offer.lender, lender);
        assertEq(offer.amount, amount);
        vm.stopPrank();
    }

    function testAcceptOffer() public {
        uint256 amount = 10 ether;
        uint256 duration = 100 days;

        vm.startPrank(lender);
        erc20.approve(address(lendContract), amount);
        uint256 offerId = lendContract.createOffer(address(erc721), borrowerTokenId, 500, duration, amount);
        vm.stopPrank();

        vm.startPrank(borrower);
        lendContract.acceptOffer(offerId);

        NFTLendPropy.Offer memory offer = lendContract.getOffer(offerId);
        assertEq(offer.borrower, borrower);
        vm.stopPrank();
    }

    function testRepayLend() public {
        uint256 amount = 10 ether;
        uint256 duration = 100 days;

        vm.startPrank(lender);
        erc20.approve(address(lendContract), amount);
        uint256 offerId = lendContract.createOffer(address(erc721), borrowerTokenId, 500, duration, amount);
        vm.stopPrank();

        vm.startPrank(borrower);
        lendContract.acceptOffer(offerId);

        erc20.approve(address(lendContract), amount * 2);
        lendContract.repayLend(offerId);

        NFTLendPropy.Offer memory offer = lendContract.getOffer(offerId);
        assertEq(offer.active, false);
        vm.stopPrank();
    }

    function testClaimCollateral() public {
        uint256 amount = 10 ether;
        uint256 duration = 100 days;

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

        NFTLendPropy.Offer memory offer = lendContract.getOffer(offerId);
        assertEq(offer.active, false);
        assertEq(erc721.ownerOf(borrowerTokenId), lender);
        vm.stopPrank();
    }
}
