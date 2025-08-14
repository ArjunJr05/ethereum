// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CarbonCreditMarketplace is ERC1155, Ownable {
    using Counters for Counters.Counter;

    uint256 public constant CARBON_CREDIT_ID = 0;

    // Use OpenZeppelin counters for safer incrementing
    Counters.Counter private _listingIds;
    Counters.Counter private _transactionIds;

    // --- State Variables for Statistics ---
    Counters.Counter private _activeListingsCount;
    uint256 public totalCreditsTraded;

    // --- Registration System ---
    mapping(address => bool) public isRegistered;
    mapping(address => string) public userProfiles; // Optional: store user company names

    struct Listing {
        uint256 listingId;
        address seller;
        uint128 amount;
        uint128 price;
        uint128 pricePerCredit;
        uint64 createdAt;
        bool active;
        string description;
    }

    struct Transaction {
        uint256 transactionId;
        address buyer;
        address seller;
        uint128 amount;
        uint128 totalPrice;
        uint64 timestamp;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Transaction) public transactions;

    // --- Mappings for Efficient Data Retrieval ---
    mapping(uint256 => uint256) private activeListingIdToIndex;
    uint256[] private activeListingIds;
    mapping(address => uint256[]) private userTransactionIds;

    // --- Events ---
    event CreditIssued(address indexed to, uint256 amount);
    event CreditEarned(address indexed earner, uint256 amount);
    event CreditListed(uint256 indexed listingId, address indexed seller, uint256 amount, uint256 price);
    event CreditSold(uint256 indexed transactionId, uint256 indexed listingId, address indexed buyer, address seller, uint256 amount, uint256 price);
    event ListingCancelled(uint256 indexed listingId);
    event UserRegistered(address indexed user, string profile);

    constructor() ERC1155("Carbon Credit") {}

    // --- Registration Functions ---
    function register() external {
        require(!isRegistered[msg.sender], "Already registered");
        isRegistered[msg.sender] = true;
        emit UserRegistered(msg.sender, "");
    }

    function registerWithProfile(string calldata profile) external {
        require(!isRegistered[msg.sender], "Already registered");
        isRegistered[msg.sender] = true;
        userProfiles[msg.sender] = profile;
        emit UserRegistered(msg.sender, profile);
    }

    modifier onlyRegistered() {
        require(isRegistered[msg.sender], "Not registered");
        _;
    }

    // --- Helper functions for managing active listings array ---
    function _addActiveListing(uint256 listingId) private {
        activeListingIdToIndex[listingId] = activeListingIds.length;
        activeListingIds.push(listingId);
    }

    function _removeActiveListing(uint256 listingId) private {
        uint256 index = activeListingIdToIndex[listingId];
        uint256 lastId = activeListingIds[activeListingIds.length - 1];
        activeListingIds[index] = lastId;
        activeListingIdToIndex[lastId] = index;
        activeListingIds.pop();
        delete activeListingIdToIndex[listingId];
    }

    function issue(address to, uint256 amount, bytes memory data) external onlyOwner {
        _mint(to, CARBON_CREDIT_ID, amount, data);
        emit CreditIssued(to, amount);
    }

    function earnCreditForAction() external {
        _mint(msg.sender, CARBON_CREDIT_ID, 1, "");
        emit CreditEarned(msg.sender, 1);
    }

    function listCredits(uint256 amount, uint256 price, string calldata description) external onlyRegistered {
        require(balanceOf(msg.sender, CARBON_CREDIT_ID) >= amount, "Insufficient balance");
        require(isApprovedForAll(msg.sender, address(this)), "Not approved");
        require(amount > 0, "Amount must be greater than 0");
        require(price > 0, "Price must be greater than 0");
        
        uint256 listingId = _listingIds.current();

        listings[listingId] = Listing({
            listingId: listingId,
            seller: msg.sender,
            amount: uint128(amount),
            price: uint128(price),
            pricePerCredit: uint128(price / amount),
            active: true,
            createdAt: uint64(block.timestamp),
            description: description
        });
        
        _addActiveListing(listingId);
        _activeListingsCount.increment();
        _listingIds.increment();

        emit CreditListed(listingId, msg.sender, amount, price);
    }

    function buyCredits(uint256 listingId) external payable {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(msg.value == listing.price, "Incorrect ETH value sent");
        require(listing.seller != msg.sender, "Cannot buy own credits");
        
        address seller = listing.seller;
        uint256 amount = listing.amount;
        uint256 price = listing.price;
        uint256 transactionId = _transactionIds.current();

        listing.active = false;
        _removeActiveListing(listingId);
        _activeListingsCount.decrement();

        safeTransferFrom(seller, msg.sender, CARBON_CREDIT_ID, amount, "");
        (bool sent, ) = seller.call{value: msg.value}("");
        require(sent, "ETH transfer failed");

        totalCreditsTraded += amount;

        transactions[transactionId] = Transaction({
            transactionId: transactionId,
            buyer: msg.sender,
            seller: seller,
            amount: uint128(amount),
            totalPrice: uint128(price),
            timestamp: uint64(block.timestamp)
        });

        userTransactionIds[msg.sender].push(transactionId);
        userTransactionIds[seller].push(transactionId);

        _transactionIds.increment();
        emit CreditSold(transactionId, listingId, msg.sender, seller, amount, price);
    }

    function cancelListing(uint256 listingId) external onlyRegistered {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Not listing owner");
        require(listing.active, "Listing not active");
        
        listing.active = false;
        _removeActiveListing(listingId);
        _activeListingsCount.decrement();
        emit ListingCancelled(listingId);
    }

    // --- VIEW FUNCTIONS ---

    function getActiveListingIds() external view returns (uint256[] memory) {
        return activeListingIds;
    }
    
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function getUserTransactionIds(address userAddress) external view returns (uint256[] memory) {
        return userTransactionIds[userAddress];
    }

    function getMarketplaceStats() external view returns (
        uint256 activeListings,
        uint256 totalTransactions,
        uint256 _totalCreditsTraded
    ) {
        return (
            _activeListingsCount.current(),
            _transactionIds.current(),
            totalCreditsTraded
        );
    }

    // Helper function to get user's balance
    function getCarbonCreditBalance(address user) external view returns (uint256) {
        return balanceOf(user, CARBON_CREDIT_ID);
    }

    // Helper function to get user's active listings
    function getUserActiveListings(address user) external view returns (uint256[] memory userListings) {
        uint256 count = 0;
        // First pass: count user's active listings
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            if (listings[activeListingIds[i]].seller == user) {
                count++;
            }
        }
        
        // Second pass: populate array
        userListings = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < activeListingIds.length; i++) {
            if (listings[activeListingIds[i]].seller == user) {
                userListings[index] = activeListingIds[i];
                index++;
            }
        }
        
        return userListings;
    }

    // Function to check if a user is registered
    function isUserRegistered(address user) external view returns (bool) {
        return isRegistered[user];
    }

    // Function to get user profile
    function getUserProfile(address user) external view returns (string memory) {
        return userProfiles[user];
    }

    // Function to get all registered users (for admin purposes)
    function getRegisteredUsersCount() external pure returns (uint256) { 

    return 0;
}
}