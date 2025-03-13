// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// Import OpenZeppelin contracts for security and standardization
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title ReBazRWICollection
 * @notice An ERC721 NFT collection contract that supports:
 *         - Multiple tiers (with price and supply limits)
 *         - On-demand (zero-mint) minting
 *         - Immediate revenue splitting on mint (90% to creator, 10% to Regen Bazaar)
 *         - EIP‑2981 royalties (10% total; split via a PaymentSplitter)
 *         - Storage of RWI data from impact input
 */
contract ReBazRWICollection is ERC721, ERC2981, Ownable, ReentrancyGuard {
    using Strings for uint256;

    // STRUCTS & STATE VARIABLES

    /// @notice Data structure for each NFT tier.
    struct Tier {
        string name;        // Tier name (e.g., "Standard", "Premium")
        uint256 price;      // Price (in wei) to mint an NFT in this tier
        uint256 maxSupply;  // Maximum NFTs allowed in this tier
        uint256 minted;     // Count of NFTs minted in this tier
    }

    /// @notice RWI data structure
    struct RWIData {
        string organizationType;
        string entityName;
        string actionTitle;
        string achievedImpact;
        string timePeriod;
        string areaOfImpact;
        string proofUrl;
        string technicalSkillLevel;
    }

    // Mapping from tier ID to tier details.
    mapping(uint256 => Tier) public tiers;
    // mapping to track each token's associated tier.
    mapping(uint256 => uint256) public tokenTier;

    // RWI data for this collection (assumed to represent one set of impact data).
    RWIData public rwiData;

    // Token ID counter.
    uint256 public currentTokenId;

    // Addresses for fund distribution.
    address public creator;
    address public regenBazaar;

    // PaymentSplitter contract used for royalties.
    PaymentSplitter public royaltySplitter;

    // Base URI for token metadata (points to off-chain metadata storage such as IPFS).
    string private _baseTokenURI;

    // EVENTS
    
    event Minted(address indexed minter, uint256 tokenId, uint256 tierId);

    // CONSTRUCTOR
    /**
     * @notice Initializes the NFT collection with RWI data, tier information,
     *         revenue splitting addresses, and royalty settings.
     *
     * @param name_
     * @param symbol_
     * @param _creator            Address of the NFT creator (receives 90% of mint funds).
     * @param _regenBazaar        Address for Regen Bazaar (receives 10% of mint funds).
     * @param organizationType
     * @param entityName
     * @param actionTitle
     * @param achievedImpact
     * @param timePeriod
     * @param areaOfImpact
     * @param proofUrl
     * @param technicalSkillLevel ("Low", "Medium", "High").
     * @param baseTokenURI
     * @param tierIds
     * @param tierNames
     * @param tierPrices
     * @param tierMaxSupplies
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address _creator,
        address _regenBazaar,
        string memory organizationType,
        string memory entityName,
        string memory actionTitle,
        string memory achievedImpact,
        string memory timePeriod,
        string memory areaOfImpact,
        string memory proofUrl,
        string memory technicalSkillLevel,
        string memory baseTokenURI,
        uint256[] memory tierIds,
        string[] memory tierNames,
        uint256[] memory tierPrices,
        uint256[] memory tierMaxSupplies
    ) ERC721(name_, symbol_) {
        require(_creator != address(0) && _regenBazaar != address(0), "Invalid addresses");
        creator = _creator;
        regenBazaar = _regenBazaar;
        _baseTokenURI = baseTokenURI;

        // Set RWI data.
        rwiData = RWIData({
            organizationType: organizationType,
            entityName: entityName,
            actionTitle: actionTitle,
            achievedImpact: achievedImpact,
            timePeriod: timePeriod,
            areaOfImpact: areaOfImpact,
            proofUrl: proofUrl,
            technicalSkillLevel: technicalSkillLevel
        });

        // Validate and add tier information.
        require(
            tierIds.length == tierNames.length &&
            tierIds.length == tierPrices.length &&
            tierIds.length == tierMaxSupplies.length,
            "Tier array length mismatch"
        );
        for (uint256 i = 0; i < tierIds.length; i++) {
            tiers[tierIds[i]] = Tier({
                name: tierNames[i],
                price: tierPrices[i],
                maxSupply: tierMaxSupplies[i],
                minted: 0
            });
        }

        // Deploy a PaymentSplitter for royalties.
        // This splitter will receive royalty payments and split them 50/50 (5% each) between creator and Regen Bazaar.
        address[] memory payees = new address[](2);
        payees[0] = _creator;
        payees[1] = _regenBazaar;
        uint256[] memory shares = new uint256[](2);
        shares[0] = 1;
        shares[1] = 1;
        royaltySplitter = new PaymentSplitter(payees, shares);

        // Set the default royalty: 10% (1000 basis points, where denominator is 10000)
        // The royalty receiver is the PaymentSplitter contract.
        _setDefaultRoyalty(address(royaltySplitter), 1000);
    }

    // MINTING FUNCTIONALITY
    /**
     * @notice Mints an NFT in the specified tier.
     *         Checks for valid tier, supply limits, and exact payment.
     *         Splits minting revenue immediately (90% to creator, 10% to Regen Bazaar).
     *
     * @param tierId The ID of the tier in which to mint the NFT.
     */
    function mint(uint256 tierId) external payable nonReentrant {
        Tier storage tier = tiers[tierId];
        require(tier.maxSupply > 0, "Tier does not exist");
        require(tier.minted < tier.maxSupply, "Tier sold out");
        require(msg.value == tier.price, "Incorrect Ether value sent");

        // Increment the minted count for the tier.
        tier.minted++;

        // Mint the NFT.
        currentTokenId++;
        _safeMint(msg.sender, currentTokenId);
        tokenTier[currentTokenId] = tierId;

        // Immediate fund splitting.
        uint256 amount = msg.value;
        uint256 shareCreator = (amount * 90) / 100;
        uint256 shareRegen = amount - shareCreator;

        // Transfer funds to the creator.
        (bool successCreator, ) = creator.call{value: shareCreator}("");
        require(successCreator, "Transfer to creator failed");

        // Transfer funds to Regen Bazaar.
        (bool successRegen, ) = regenBazaar.call{value: shareRegen}("");
        require(successRegen, "Transfer to Regen Bazaar failed");

        emit Minted(msg.sender, currentTokenId, tierId);
    }

    // METADATA & URI MANAGEMENT
    /**
     * @notice Override for the base URI.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @notice Allows the owner to update the base URI for token metadata.
     *
     * @param baseURI_ New base URI.
     */
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
    }

    // INTERFACE OVERRIDES
    /**
     * @notice Override supportsInterface to include ERC2981 (royalties) support.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
