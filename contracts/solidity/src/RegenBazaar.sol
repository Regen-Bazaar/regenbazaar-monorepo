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

/**
 *
 * @author Cyber-Mitch(Reentrancy)
 * @title RegenBazaar - Decentralized NFT Marketplace on Celo
 * @notice A secure marketplace for trading ERC721 and ERC1155 NFTs
 * @dev Inherits from OpenZeppelin's Ownable, Pausable, and ReentrancyGuard contracts
 */
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
    event ListingCancelled(uint256 indexed listingId);
    event ListingInactive(uint256 indexed listingId);

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
    /**
     * @notice Structure representing an NFT listing
     * @param seller Address of the NFT seller
     * @param token Address of the NFT contract
     * @param tokenId ID of the NFT token
     * @param price Price per unit in payment token
     * @param quantity Available quantity (1 for ERC721)
     * @param tokenType 0 for ERC721, 1 for ERC1155
     * @param isActive Whether the listing is active
     */
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
    /**
     * @notice Initializes the contract with payment token address
     *
     * 
     */
    constructor(address _paymentToken) Ownable(msg.sender) {
        paymentToken = IERC20(_paymentToken);
    }

    // ======================
    // Marketplace Functions
    // ======================
    /**
     * @notice Creates a new NFT listing
     * @dev Verifies ownership and approval before creating listing
     * @param token Address of NFT contract
     * @param tokenId ID of NFT token
     * @param price Price per unit in payment token
     * @param quantity Available quantity (1 for ERC721)
     * @param tokenType 0 for ERC721, 1 for ERC1155
     */
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
            if (IERC721(token).getApproved(tokenId) != address(this) && 
            !IERC721(token).isApprovedForAll(msg.sender, address(this))) revert Unauthorized();
            if (quantity <= 0) revert ERC721InvalidQuantity();
        } else {
            if (IERC1155(token).balanceOf(msg.sender, tokenId) < quantity) revert InsufficientBalance();
            if (!IERC1155(token).isApprovedForAll(msg.sender, address(this))) revert Unauthorized();
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

    /**
     * @notice Purchases a single NFT listing
     * @dev Handles both CELO and ERC20 payments with reentrancy protection
     * @param listingId ID of the listing to purchase
     * @param quantity Quantity to purchase
     */
    function buyListing(uint256 listingId, uint256 quantity) external payable nonReentrant whenNotPaused {
        Listing storage listing = listings[listingId];
        if (!listing.isActive) revert InvalidListing();
        if (listing.quantity < quantity) revert InsufficientBalance();

        uint256 totalPrice = listing.price * quantity;
        uint256 platformFee = calculatePlatformFee(totalPrice);
        uint256 sellerShare = totalPrice - platformFee;

        // Update state first to prevent reentrancy
        listing.quantity -= quantity;
        if (listing.quantity == 0) {
            listing.isActive = false;
            emit ListingInactive(listingId);
        }

        // Handle payment
        if (address(paymentToken) == address(0)) { 
            if (msg.value != totalPrice) revert IncorrectPaymentAmount();
            
            (bool successSeller, ) = payable(listing.seller).call{value: sellerShare}("");
            (bool successPlatform, ) = payable(owner()).call{value: platformFee}("");
            
            if (!successSeller || !successPlatform) revert TransferFailed();
        } else { // ERC20 payment
            paymentToken.safeTransferFrom(msg.sender, address(this), totalPrice);
            paymentToken.safeTransfer(listing.seller, sellerShare);
            paymentToken.safeTransfer(owner(), platformFee);
        }

        // Transfer NFT
        if (listing.tokenType == TOKEN_TYPE_ERC721) {
            IERC721(listing.token).safeTransferFrom(listing.seller, msg.sender, listing.tokenId);
        } else {
            IERC1155(listing.token).safeTransferFrom(
                listing.seller, 
                msg.sender, 
                listing.tokenId, 
                quantity, 
                bytes("")
            );
        }

        emit ListingPurchased(listingId, msg.sender, quantity, totalPrice, sellerShare, platformFee);
    }

    // ======================
    // Additional Functions
    // ======================
    /**
     * @notice Purchases multiple listings in a single transaction
     * @param listingIds Array of listing IDs to purchase
     * @param quantities Array of quantities to purchase for each listing
     */
    function buyListingsBatch(
        uint256[] calldata listingIds,
        uint256[] calldata quantities
    ) external payable nonReentrant whenNotPaused {
        if (listingIds.length != quantities.length) revert MismatchedInputLengths();

        uint256 totalPrice;
        uint256 totalPlatformFee;

        // Calculate total price and fees
        for (uint256 i = 0; i < listingIds.length; i++) {
            Listing storage listing = listings[listingIds[i]];
            if (!listing.isActive) revert InvalidListing();
            if (listing.quantity < quantities[i]) revert InsufficientBalance();
            
            uint256 listingPrice = listing.price * quantities[i];
            totalPrice += listingPrice;
            totalPlatformFee += calculatePlatformFee(listingPrice);
        }

        // Handle payment
        if (address(paymentToken) == address(0)) {
            if (msg.value != totalPrice) revert IncorrectPaymentAmount();
            (bool success, ) = payable(owner()).call{value: totalPlatformFee}("");
            if (!success) revert TransferFailed();
        } else { // ERC20 payment
            paymentToken.safeTransferFrom(msg.sender, address(this), totalPrice);
            paymentToken.safeTransfer(owner(), totalPlatformFee);
        }

        // Process each listing
        for (uint256 i = 0; i < listingIds.length; i++) {
            Listing storage listing = listings[listingIds[i]];
            uint256 listingPrice = listing.price * quantities[i];
            uint256 sellerShare = listingPrice - calculatePlatformFee(listingPrice);

            // Update state first
            listing.quantity -= quantities[i];
            if (listing.quantity == 0) {
                listing.isActive = false;
                emit ListingInactive(listingIds[i]);
            }

            // Transfer funds
            if (address(paymentToken) == address(0)) {
                (bool success, ) = payable(listing.seller).call{value: sellerShare}("");
                if (!success) revert TransferFailed();
            } else {
                paymentToken.safeTransfer(listing.seller, sellerShare);
            }

            // Transfer NFT
            if (listing.tokenType == TOKEN_TYPE_ERC721) {
                IERC721(listing.token).safeTransferFrom(listing.seller, msg.sender, listing.tokenId);
            } else {
                IERC1155(listing.token).safeTransferFrom(
                    listing.seller, 
                    msg.sender, 
                    listing.tokenId, 
                    quantities[i], 
                    bytes("")
                );
            }

            emit ListingPurchased(
                listingIds[i],
                msg.sender,
                quantities[i],
                listingPrice,
                sellerShare,
                calculatePlatformFee(listingPrice)
            );
        }
    }

    // ======================
    // View Functions
    // ======================
    /**
     * @notice Get details of a specific listing
     * @dev Returns the full Listing struct for a given listing ID
     * @param listingId ID of the listing to retrieve
     * @return Listing struct containing all listing details
     */
    function getListing(uint256 listingId) external view returns (Listing memory) {
        if (listingId >= nextListingId) revert ListingDoesNotExist();
        return listings[listingId];
    }

    /**
     * @notice Get all active listings in the marketplace
     * @dev Returns an array of all currently active listings
     * @return activeListings Array of active Listing structs
     */
    function getActiveListings() external view returns (Listing[] memory) {
        Listing[] memory activeListings = new Listing[](nextListingId);
        uint256 count = 0;
        
        for (uint256 i = 0; i < nextListingId; i++) {
            if (listings[i].isActive) {
                activeListings[count] = listings[i];
                count++;
            }
        }
        
        // Resize array to remove empty elements
        assembly {
            mstore(activeListings, count)
        }
        return activeListings;
    }

    /**
     * @notice Get all listings created by a specific seller
     * @dev Returns both active and inactive listings for a given address
     * @param seller Address of the seller to query
     * @return sellerListings Array of Listing structs created by the seller
     */
    function getListingsBySeller(address seller) external view returns (Listing[] memory) {
        Listing[] memory sellerListings = new Listing[](nextListingId);
        uint256 count = 0;
        
        for (uint256 i = 0; i < nextListingId; i++) {
            if (listings[i].seller == seller) {
                sellerListings[count] = listings[i];
                count++;
            }
        }
        
        // Resize array to remove empty elements
        assembly {
            mstore(sellerListings, count)
        }
        return sellerListings;
    }

    /**
     * @notice Get all listings in the marketplace
     * @dev Returns both active and inactive listings
     * @return allListings Array of all Listing structs in the marketplace
     */
    function getAllListings() external view returns (Listing[] memory) {
        Listing[] memory allListings = new Listing[](nextListingId);
        
        for (uint256 i = 0; i < nextListingId; i++) {
            allListings[i] = listings[i];
        }
        return allListings;
    }

    // ======================
    // Admin Functions
    // ======================
    /**
     * @notice Pauses the marketplace
     * @dev Only callable by owner
     */
    function pause() external onlyOwner {
        _pause();
        emit ContractPaused();
    }

    /**
     * @notice Unpauses the marketplace
     * @dev Only callable by owner
     */
    function unpause() external onlyOwner {
        _unpause();
        emit ContractUnpaused();
    }

    /**
     * @notice Recovers stuck funds from contract
     * @dev Only callable by owner
     * @param token Address of token to recover (address(0) for CELO)
     * @param amount Amount to recover
     */
    function recoverFunds(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            (bool success, ) = payable(owner()).call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
        emit FundsRecovered(token, amount);
    }

    /**
     * @notice Cancels an active listing
     * @dev Can be called by seller or owner
     * @param listingId ID of listing to cancel
     */
    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        if (msg.sender != listing.seller && msg.sender != owner()) revert Unauthorized();
        listing.isActive = false;
        emit ListingCancelled(listingId);
    }

    // ======================
    // Helper Functions
    // ======================
    function calculatePlatformFee(uint256 totalPrice) internal pure returns (uint256) {
        return (totalPrice * FEE_PERCENTAGE) / FEE_BASE;
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


        /**
     * @notice Rejects direct CELO transfers to contract
     * @dev All payments must go through buyListing/buyListingsBatch
     */
    receive() external payable {
        revert("Direct CELO transfers not allowed");
    }

    /**
     * @notice Fallback function to reject unintended calls
     */
    fallback() external payable {
        revert("Invalid function call");
    }
}