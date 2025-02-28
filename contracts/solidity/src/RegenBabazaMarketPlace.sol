// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract RegenBazaar is Ownable, Pausable, ReentrancyGuard, IERC721Receiver, IERC1155Receiver {
    using SafeERC20 for IERC20;
    using Address for address payable;

    // ======================
    // Custom Errors
    // ======================
    error InvalidTokenType();
    error InvalidTokenPaymentAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidListing();
    error Unauthorized();
    error TransferFailed();
    error MismatchedInputLengths();
    error ListingDoesNotExist();
    error IncorrectPaymentAmount();
    error ERC721InvalidQuantity();

    // ======================
    // Events
    // ======================
    event ListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        address indexed token,
        uint256 tokenId,
        uint256 price,
        uint256 quantity,
        uint8 tokenType
    );

    event ListingPurchased(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 quantity,
        uint256 totalPrice,
        uint256 sellerShare,
        uint256 platformFee
    );

    event ContractPaused();
    event ContractUnpaused();
    event FundsRecovered(address indexed token, uint256 amount);

    // ======================
    // Constants
    // ======================
    uint8 public constant TOKEN_TYPE_ERC721 = 0;
    uint8 public constant TOKEN_TYPE_ERC1155 = 1;
    uint256 public constant FEE_PERCENTAGE = 10;
    uint256 public constant FEE_BASE = 100;

    // ======================
    // Structs
    // ======================
    struct Listing {
        address seller;
        address token;
        uint256 tokenId;
        uint256 price;
        uint256 quantity;
        uint8 tokenType;
        bool isActive;
    }

    // ======================
    // State Variables
    // ======================
    mapping(uint256 => Listing) public listings;
    uint256 public nextListingId;
    IERC20 public paymentToken;

    // ======================
    // Constructor
    // ======================
    constructor(address _paymentToken) Ownable(msg.sender) {
        if (_paymentToken == address(0)) revert InvalidTokenPaymentAddress();
        paymentToken = IERC20(_paymentToken);
    }

    // ======================
    // Marketplace Functions
    // ======================
    function createListing(
        address token,
        uint256 tokenId,
        uint256 price,
        uint256 quantity,
        uint8 tokenType
    ) external whenNotPaused {
        if (tokenType > TOKEN_TYPE_ERC1155) revert InvalidTokenType();

        if (tokenType == TOKEN_TYPE_ERC721) {
            if (IERC721(token).ownerOf(tokenId) != msg.sender) revert Unauthorized();
            if (quantity <= 0) revert ERC721InvalidQuantity();
        } else if (tokenType == TOKEN_TYPE_ERC1155) {
            if (IERC1155(token).balanceOf(msg.sender, tokenId) < quantity) revert InsufficientBalance();
        }

        listings[nextListingId] = Listing({
            seller: msg.sender,
            token: token,
            tokenId: tokenId,
            price: price,
            quantity: quantity,
            tokenType: tokenType,
            isActive: true
        });

        emit ListingCreated(nextListingId, msg.sender, token, tokenId, price, quantity, tokenType);
        nextListingId++;
    }

    function buyListing(uint256 listingId, uint256 quantity) external payable nonReentrant whenNotPaused {
        Listing storage listing = listings[listingId];
        if (!listing.isActive) revert InvalidListing();
        if (listing.quantity < quantity) revert InsufficientBalance();

        uint256 totalPrice = listing.price * quantity;
        uint256 platformFee = (totalPrice * FEE_PERCENTAGE) / FEE_BASE;
        uint256 sellerShare = totalPrice - platformFee;

        // Handle payment (CELO ETH is the native currency, so we use msg.value)
        if (address(paymentToken) != address(0)) {
            if (msg.value != totalPrice) revert IncorrectPaymentAmount();

            // Transfer seller's share using call
            (bool successSeller, ) = payable(listing.seller).call{value: sellerShare}("");
            if (!successSeller) revert TransferFailed();

            // Transfer platform fee using call
            (bool successPlatform, ) = payable(owner()).call{value: platformFee}("");
            if (!successPlatform) revert TransferFailed();
        } else {
            paymentToken.safeTransferFrom(msg.sender, address(this), totalPrice);
            paymentToken.safeTransfer(listing.seller, sellerShare);
            paymentToken.safeTransfer(owner(), platformFee);
        }

        // Transfer tokens
        if (listing.tokenType == TOKEN_TYPE_ERC721) {
            IERC721(listing.token).safeTransferFrom(listing.seller, msg.sender, listing.tokenId);
        } else if (listing.tokenType == TOKEN_TYPE_ERC1155) {
            IERC1155(listing.token).safeTransferFrom(listing.seller, msg.sender, listing.tokenId, quantity, bytes(""));
        }

        // Update listing
        listing.quantity -= quantity;
        if (listing.quantity == 0) listing.isActive = false;

        emit ListingPurchased(listingId, msg.sender, quantity, totalPrice, sellerShare, platformFee);
    }

    // ======================
    // Additional Functions
    // ======================
    function buyListingsBatch(
        uint256[] calldata listingIds,
        uint256[] calldata quantities
    ) external payable nonReentrant whenNotPaused {
        if (listingIds.length != quantities.length) revert MismatchedInputLengths();

        uint256 totalPrice;
        uint256 totalPlatformFee;

        for (uint256 i = 0; i < listingIds.length; i++) {
            Listing storage listing = listings[listingIds[i]];
            if (!listing.isActive) revert InvalidListing();
            if (listing.quantity < quantities[i]) revert InsufficientBalance();
            
            uint256 listingPrice = listing.price * quantities[i];
            totalPrice += listingPrice;
            totalPlatformFee += (listingPrice * FEE_PERCENTAGE) / FEE_BASE;
        }

        // Handle payment (CELO ETH is the native currency, so we use msg.value)
        if (address(paymentToken) != address(0)) {
            if (msg.value != totalPrice) revert IncorrectPaymentAmount();
            
            (bool success, ) = payable(owner()).call{value: totalPlatformFee}("");
            if (!success) revert TransferFailed();
        } else {
            paymentToken.safeTransferFrom(msg.sender, address(this), totalPrice);
            paymentToken.safeTransfer(owner(), totalPlatformFee);
        }

        for (uint256 i = 0; i < listingIds.length; i++) {
            Listing storage listing = listings[listingIds[i]];
            uint256 listingPrice = listing.price * quantities[i];
            uint256 sellerShare = listingPrice - ((listingPrice * FEE_PERCENTAGE) / FEE_BASE);

            // Transfer seller share
            if (address(paymentToken) == address(0)) {
                (bool success, ) = payable(listing.seller).call{value: sellerShare}("");
                if (!success) revert TransferFailed();
            } else {
                paymentToken.safeTransfer(listing.seller, sellerShare);
            }

            // Transfer tokens
            if (listing.tokenType == TOKEN_TYPE_ERC721) {
                if (quantities[i] != 1) revert ERC721InvalidQuantity();
                IERC721(listing.token).safeTransferFrom(listing.seller, msg.sender, listing.tokenId);
            } else if (listing.tokenType == TOKEN_TYPE_ERC1155) {
                IERC1155(listing.token).safeTransferFrom(listing.seller, msg.sender, listing.tokenId, quantities[i], bytes(""));
            }

            // Update listing
            listing.quantity -= quantities[i];
            if (listing.quantity == 0) listing.isActive = false;

            emit ListingPurchased(
                listingIds[i],
                msg.sender,
                quantities[i],
                listingPrice,
                sellerShare,
                (listingPrice * FEE_PERCENTAGE) / FEE_BASE
            );
        }
    }

    // ======================
    // Admin Functions
    // ======================
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused();
    }

    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused();
    }

    // Recover stuck CELO ETH (native currency) and ERC20 tokens
    function recoverFunds(address token, uint256 amount) external onlyOwner {
        if (token != address(0)) {
            // Recover stuck CELO ETH
            (bool success, ) = payable(owner()).call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            // Recover stuck ERC20 tokens
            IERC20(token).safeTransfer(owner(), amount);
        }
        emit FundsRecovered(token, amount);
    }

    // ======================
    // ERC Receiver Functions
    // ======================
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId ||
               interfaceId == type(IERC1155Receiver).interfaceId;
    }
}