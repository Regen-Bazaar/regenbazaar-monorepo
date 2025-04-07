// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @author Cyber-Mitch(Reentrancy)
 * @title ImpactProductPurchaser
 * @notice Secure purchasing system for verified impact products
 * @dev Implements dedicated impact product handling with financial safeguards
 */
contract ImpactProductPurchaser is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ======================
    // Custom Errors
    // ======================
    error InvalidTokenType();
    error InsufficientProductSupply();
    error PaymentAmountMismatch();
    error UnauthorizedSeller();
    error InvalidProduct();
    error TransferFailed();
    error InvalidPaymentToken();
    error InvalidTokenApproval();

    // ======================
    // Events
    // ======================
    event ProductListed(
        uint256 indexed productId,
        address indexed seller,
        address indexed impactToken,
        uint256 tokenId,
        uint256 price,
        uint256 supply,
        uint8 tokenType
    );

    event ProductPurchased(
        uint256 indexed productId,
        address buyer,
        uint256 quantity,
        uint256 totalPrice,
        uint256 projectFunding,
        uint256 platformFee
    );

    event EmergencyStopActivated();
    event EmergencyStopLifted();

    // ======================
    // Constants
    // ======================
    uint8 public constant ERC721_TYPE = 0;
    uint8 public constant ERC1155_TYPE = 1;
    uint256 public constant FEE_PERCENTAGE = 10;
    uint256 public constant FEE_BASE = 100;

    // ======================
    // Structs
    // ======================
    struct ImpactProduct {
        address seller;
        address impactToken;
        uint256 tokenId;
        uint256 pricePerUnit;
        uint256 remainingSupply;
        uint8 tokenType;
        bool isActive;
    }

    // ======================
    // State Variables
    // ======================
    mapping(uint256 => ImpactProduct) public products;
    uint256 public nextProductId;
    IERC20 public immutable paymentToken;

    // ======================
    // Constructor
    // ======================
    /**
     * @notice Initializes the purchaser contract
     * @param _paymentToken Approved stablecoin for transactions
     */
    constructor(address _paymentToken) Ownable(msg.sender) {       
        paymentToken = IERC20(_paymentToken);
    }

    // ======================
    // Core Functions
    // ======================

    /**
     * @notice Lists a new impact product for sale
     * @dev Verifies token ownership and contract approval
     * @param impactToken Address of NFT contract
     * @param tokenId NFT token ID
     * @param pricePerUnit Price per impact unit
     * @param initialSupply Initial available units
     * @param tokenType 0=ERC721, 1=ERC1155
     */
    function listProduct(
        address impactToken,
        uint256 tokenId,
        uint256 pricePerUnit,
        uint256 initialSupply,
        uint8 tokenType
    ) external whenNotPaused {
        if (tokenType > ERC1155_TYPE) revert InvalidTokenType();
        
        _validateTokenOwnership(impactToken, tokenId, tokenType, msg.sender, initialSupply);

        products[nextProductId] = ImpactProduct({
            seller: msg.sender,
            impactToken: impactToken,
            tokenId: tokenId,
            pricePerUnit: pricePerUnit,
            remainingSupply: initialSupply,
            tokenType: tokenType,
            isActive: true
        });

        emit ProductListed(
            nextProductId,
            msg.sender,
            impactToken,
            tokenId,
            pricePerUnit,
            initialSupply,
            tokenType
        );
        nextProductId++;
    }

    /**
     * @notice Purchases impact product units
     * @dev Handles payment splitting and inventory management
     * @param productId ID of product to purchase
     * @param quantity Number of units to buy
     */
    function purchaseProduct(
        uint256 productId,
        uint256 quantity
    ) external nonReentrant whenNotPaused {
        ImpactProduct storage product = products[productId];
        
        if (productId >= nextProductId) revert InvalidProduct();
        if (!product.isActive) revert InvalidProduct();
        if (product.remainingSupply < quantity) revert InsufficientProductSupply();

        uint256 totalPrice = product.pricePerUnit * quantity;
        uint256 platformFee = (totalPrice * FEE_PERCENTAGE) / FEE_BASE;
        uint256 projectFunding = totalPrice - platformFee;

        paymentToken.safeTransferFrom(msg.sender, address(this), totalPrice);
        paymentToken.safeTransfer(product.seller, projectFunding);
        paymentToken.safeTransfer(owner(), platformFee);

        product.remainingSupply -= quantity;
        if (product.remainingSupply == 0) product.isActive = false;

        _transferImpactTokens(product, quantity);

        emit ProductPurchased(
            productId,
            msg.sender,
            quantity,
            totalPrice,
            projectFunding,
            platformFee
        );
    }

    // ======================
    // Administrative Functions
    // ======================

    /**
     * @notice Activates emergency pause
     * @dev Restricted to contract owner
     */
    function emergencyPause() external onlyOwner {
        _pause();
        emit EmergencyStopActivated();
    }

    /**
     * @notice Resumes normal operations
     * @dev Restricted to contract owner
     */
    function resumeOperations() external onlyOwner {
        _unpause();
        emit EmergencyStopLifted();
    }

    // ======================
    // View Functions
    // ======================

    /**
     * @notice Retrieves product details
     * @param productId ID of product to view
     * @return Full product details
     */
    function getProduct(uint256 productId) external view returns (ImpactProduct memory) {
        if (productId >= nextProductId) revert InvalidProduct();
        return products[productId];
    }

    // ======================
    // Internal Helpers
    // ======================

    function _validateTokenOwnership(
        address token,
        uint256 tokenId,
        uint8 tokenType,
        address seller,
        uint256 supply
    ) private view {
        if (tokenType == ERC721_TYPE) {
            if (IERC721(token).ownerOf(tokenId) != seller) revert UnauthorizedSeller();
            if (!IERC721(token).isApprovedForAll(seller, address(this))) revert InvalidTokenApproval();
            if (supply != 1) revert InvalidTokenType();
        } else {
            if (IERC1155(token).balanceOf(seller, tokenId) < supply) revert InsufficientProductSupply();
            if (!IERC1155(token).isApprovedForAll(seller, address(this))) revert InvalidTokenApproval();
        }
    }

    function _transferImpactTokens(
        ImpactProduct memory product,
        uint256 quantity
    ) private {
        if (product.tokenType == ERC721_TYPE) {
            IERC721(product.impactToken).transferFrom(
                product.seller,
                msg.sender,
                product.tokenId
            );
        } else {
            IERC1155(product.impactToken).safeTransferFrom(
                product.seller,
                msg.sender,
                product.tokenId,
                quantity,
                ""
            );
        }
    }

    // ======================
    // Security Features
    // ======================
    receive() external payable {
        revert("Direct CELO transfers not supported");
    }

    fallback() external payable {
        revert("Invalid function call");
    }
}