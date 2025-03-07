// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@hypercerts-org/contracts/contracts/HypercertMinter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RegenBazaarHypercert
 * @dev Contract for creating tiered impact NFTs based on Hypercerts
 * This implementation extends the HypercertMinter contract which already incorporates token functionality
 */
contract RegenBazaarHypercert is HypercertMinter, Ownable {
    // Regen Bazaar treasury address
    address public regenBazaarTreasury;
    
    // Collection structure
    struct TierInfo {
        string name;
        uint256 price;
        uint256 maxSupply;
        uint256 currentSupply;
        string imageURI;
        uint256 fractionId;  // The fraction ID in the HypercertMinter
    }
    
    struct CollectionData {
        uint256 claimId;     // The claim ID in the HypercertMinter
        address creator;
        bool isApproved;
        uint256[] tierIds;
        string metadataURI;
    }
    
    // Storage
    mapping(uint256 => CollectionData) public collections;
    mapping(uint256 => TierInfo) public tiers;
    uint256 public collectionCounter;
    uint256 public tierCounter;
    
    // Events
    event CollectionCreated(uint256 indexed collectionId, address indexed creator, uint256 claimId);
    event CollectionApproved(uint256 indexed collectionId);
    event TierAdded(uint256 indexed collectionId, uint256 indexed tierId, string name, uint256 price, uint256 fractionId);
    event TierMinted(uint256 indexed collectionId, uint256 indexed tierId, address buyer);
    event ImageUpdated(uint256 indexed collectionId, uint256 indexed tierId, string imageURI);
    
    /**
     * @dev Constructor initializes the contract
     * @param _regenBazaarTreasury Address for treasury to receive platform fees
     * @param _name Name for the Hypercert token
     * @param _symbol Symbol for the Hypercert token
     * @param _contractURI URI for contract metadata
     * @param _baseURI Base URI for token metadata
     */
    constructor(
        address _regenBazaarTreasury,
        string memory _name,
        string memory _symbol,
        string memory _contractURI,
        string memory _baseURI
    ) HypercertMinter(_name, _symbol, _contractURI, _baseURI) {
        regenBazaarTreasury = _regenBazaarTreasury;
        collectionCounter = 1;
        tierCounter = 1;
    }
    
    /**
     * @dev Creates a new impact collection
     * @param metadataURI The URI to the metadata describing the impact
     * @param units Total units of impact being represented
     */
    function createCollection(string memory metadataURI, uint256 units) external returns (uint256) {
        // Create claim metadata
        HypercertMetadata memory claimMetadata = HypercertMetadata({
            name: "", // Can be set from metadata or parameters
            description: "", // Can be set from metadata or parameters
            image: "", // Can be set from metadata or parameters
            external_url: "",
            properties: new Property[](0),
            impact_scope: "impact",
            impact_timeframe: "timeframe",
            work_scope: "work",
            work_timeframe: "workframe",
            contributors: new string[](0),
            rights: new string[](0),
            uri: metadataURI
        });

        // Create a new claim using the HypercertMinter functionality
        uint256 claimId = mintClaim(msg.sender, units, claimMetadata);
        
        // Store collection data
        uint256 collectionId = collectionCounter++;
        CollectionData storage collection = collections[collectionId];
        collection.claimId = claimId;
        collection.creator = msg.sender;
        collection.isApproved = false;
        collection.metadataURI = metadataURI;
        
        emit CollectionCreated(collectionId, msg.sender, claimId);
        return collectionId;
    }
    
    /**
     * @dev Approves a collection for minting
     * @param collectionId The ID of the collection to approve
     */
    function approveCollection(uint256 collectionId) external {
        CollectionData storage collection = collections[collectionId];
        require(msg.sender == collection.creator, "Only creator can approve collection");
        require(!collection.isApproved, "Collection already approved");
        
        collection.isApproved = true;
        emit CollectionApproved(collectionId);
    }
    
    /**
     * @dev Adds a tier to a collection
     * @param collectionId The collection ID
     * @param name Name of the tier
     * @param price Price for minting this tier
     * @param maxSupply Maximum supply for this tier
     * @param imageURI URI to the image for this tier
     */
    function addTier(
        uint256 collectionId, 
        string memory name, 
        uint256 price, 
        uint256 maxSupply, 
        string memory imageURI
    ) external returns (uint256) {
        CollectionData storage collection = collections[collectionId];
        require(msg.sender == collection.creator, "Only creator can add tiers");
        require(!collection.isApproved, "Cannot add tiers after approval");
        
        // Calculate fraction values based on maxSupply
        // Each fraction represents units/maxSupply of the total impact
        uint256 units = getUnits(collection.claimId);
        uint256 unitsPerFraction = units / maxSupply;
        require(unitsPerFraction > 0, "Units per fraction must be greater than 0");
        
        // Create a fraction of the claim using HypercertMinter
        // First, creator needs to approve this contract to transfer fractions
        TransferData[] memory transferData = new TransferData[](1);
        transferData[0] = TransferData({
            fromTokenId: collection.claimId,
            toAddress: msg.sender,
            value: maxSupply * unitsPerFraction
        });
        
        uint256 fractionId = mintFraction(
            collection.claimId,
            msg.sender,
            maxSupply * unitsPerFraction
        );
        
        // Transfer the fractions to this contract to manage. The creator needs to approve this contract first
        transferFrom(msg.sender, address(this), fractionId, maxSupply, "");
        
        uint256 tierId = tierCounter++;
        
        TierInfo storage tier = tiers[tierId];
        tier.name = name;
        tier.price = price;
        tier.maxSupply = maxSupply;
        tier.currentSupply = 0;
        tier.imageURI = imageURI;
        tier.fractionId = fractionId;
        
        collection.tierIds.push(tierId);
        
        emit TierAdded(collectionId, tierId, name, price, fractionId);
        return tierId;
    }
    
    // ... rest of the contract remains unchanged
}