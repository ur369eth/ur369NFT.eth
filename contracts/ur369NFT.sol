// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

contract ur369NFT is
    ERC721,
    Ownable,
    ReentrancyGuard,
    AutomationCompatibleInterface
{
    // Supply and Pricing Constants
    uint256 public constant TOTAL_SUPPLY = 44280; // 11070 * 4 batches
    uint256 public constant SUPER_BATCH_SIZE = 11070; // Each batch is 11,070 NFTs
    uint256 public constant SUB_BATCH_SIZE = 369; // Each sub-batch is 369 NFTs
    uint256 public constant SUPER_BATCHES = 4; // Total number of super batches
    uint256 public constant SUB_BATCHES_PER_SUPER_BATCH =
        SUPER_BATCH_SIZE / SUB_BATCH_SIZE; // Each super batch contains 30 sub batches.
    uint256[] public SUPER_BATCH_PRICES = [
        0.0369 ether,
        0.0963 ether,
        0.1845 ether,
        0.369 ether
    ];

    // images url of NFTs respective to super batches
    string[] public SUPER_BATCH_IMAGES = [
        "https://turquoise-immediate-raccoon-914.mypinata.cloud/ipfs/bafybeifk34k7zyte7k42ohirlr2v7egygp3rmbzqdwh75ab2msa43wpnbi/1.jpg",
        "https://turquoise-immediate-raccoon-914.mypinata.cloud/ipfs/bafybeifk34k7zyte7k42ohirlr2v7egygp3rmbzqdwh75ab2msa43wpnbi/2.jpg",
        "https://turquoise-immediate-raccoon-914.mypinata.cloud/ipfs/bafybeifk34k7zyte7k42ohirlr2v7egygp3rmbzqdwh75ab2msa43wpnbi/3.jpg",
        "https://turquoise-immediate-raccoon-914.mypinata.cloud/ipfs/bafybeifk34k7zyte7k42ohirlr2v7egygp3rmbzqdwh75ab2msa43wpnbi/4.jpg"
    ];

    // Metadata URIs for each batch
    string[] public BATCH_METADATA_URIS = [
        "https://turquoise-immediate-raccoon-914.mypinata.cloud/ipfs/bafybeib6uuwbzduuyed7nvj7cmn2bntrfgkinhzgduokzavpzx44ya26mm/",
        "https://turquoise-immediate-raccoon-914.mypinata.cloud/ipfs/bafybeihj7obsqpzoktz6cipf5iedxhc2n5fg3e2pe777j7ehdbkqdsgsge/",
        "https://turquoise-immediate-raccoon-914.mypinata.cloud/ipfs/bafybeiclni2k4bmndk6fbsn4kqwq52sqxt56cfj7vqjfhnzsybjegyictq/",
        "https://turquoise-immediate-raccoon-914.mypinata.cloud/ipfs/bafybeietevjwo72fq7dlkljllbqw2dh47u3bqphcoeazlwtgcczwbwxhnq/"
    ];

    uint256 public constant BASIS_POINTS = 10000; // 100% = 10000 basis points
    uint256 public CLAIM_WINDOW = 3 days + 6 hours + 9 minutes; // Time window for claiming rewards

    // Time-related Variables
    uint256 public immutable deploymentTime;

    // Token Management
    uint256 private _tokenIdCounter = 1; // start with 1

    // Financial State
    mapping(uint256 => mapping(uint256 => uint256))
        private collectedRewardForSubBatch; // superBatchId => subBatchId => collectedReward
    // User State Mappings
    mapping(address => bool) public hasMinted;

    // Fee recipients
    address public publicGoodFunds = 0xC4ef4EDACF31217B810B04702197EE2a0A13C4E3;
    address public devFunds = 0x58b1F6623e6b7dfe78b588d8F1645e5bc1e19807;
    address public urNFTETH = 0x5cC0D9bE2FC2Df3B5d682574f2005EAca253b7d9;

    // Add final recipient address
    address public finalRecipient = 0xC4ef4EDACF31217B810B04702197EE2a0A13C4E3; // address that will receive allthe funds after all the batches are completed and still not claimed amount here

    // Fee distribution percentagewise
    uint256 public claimPoolPercentage = 3690; // 36.9%
    uint256 public publicGoodFundsPercentage = 369; // 3.69%
    uint256 public devFundsPercentage = 4690; // 46.9%
    uint256 public urNFTETHPercentage = 1251; // 12.51%

    // Add EnumerableSet usage declaration
    using EnumerableSet for EnumerableSet.AddressSet;

    // Modify state variables
    mapping(address => address) private referredBy; // who referred this minter
    mapping(address => uint256) private referralCount; // count of referrals per referrer
    EnumerableSet.AddressSet private referrers; // Set of all referrers

    // minter => tokenId
    mapping(address => uint256) private addressToTokenId;

    address[] private allMinters; // array of all historical minters

    // Update SubBatchInfo struct
    struct SubBatchInfo {
        uint256 startTokenId;
        uint256 endTokenId;
        uint256 startTime;
        uint256 lastNFTMintedTime;
        uint256 rewardClaimedTime;
        bool claimed;
    }

    // Mapping from sub-batch ID to its info
    mapping(uint256 => mapping(uint256 => SubBatchInfo)) private subBatchInfo;

    // Add new state variables after other state variables
    struct LastCompletedBatchInfo {
        uint256 superBatchId;
        uint256 subBatchId;
        uint256 lastNFTMintedTime;
        bool claimed;
    }
    LastCompletedBatchInfo private lastCompletedBatch;

    // Add new state variable after other state variables
    uint256 public totalUnclaimedRewards;

    // Events
    event NFTMinted(address indexed minter, uint256 indexed tokenId);
    event RewardClaimed(
        address indexed claimer,
        uint256 superBatchId,
        uint256 subBatchId,
        uint256 claimTime,
        uint256 amount
    );
    event SuperBatchPricesUpdated(
        uint256 batch1Price,
        uint256 batch2Price,
        uint256 batch3Price,
        uint256 batch4Price
    );
    event PeriodDurationUpdated(uint256 newDuration);
    event FeeRecipientUpdated(
        address indexed previousRecipient,
        address indexed newRecipient
    );
    event ReferralRecorded(address indexed minter, address indexed referrer);
    event StableCoinAdded(address indexed tokenAddress);
    event StableCoinRemoved(address indexed tokenAddress);
    event NFTMintedWithStableCoin(
        address indexed minter,
        address indexed stableCoin,
        uint256 amount
    );
    event FeeDistributionUpdated(
        uint256 claimPoolPercentage,
        uint256 publicGoodFundsPercentage,
        uint256 devFundsPercentage,
        uint256 urNFTETHPercentage
    );
    event BatchMetadataURIUpdated(uint256 indexed batchId, string newURI);

    constructor() ERC721("ur369NFT", "ur369NFT") Ownable(msg.sender) {
        deploymentTime = block.timestamp;
    }

    // ============================
    // write functions
    // ============================

    function mint(address referrer) external payable nonReentrant {
        require(referrer != msg.sender, "Cannot refer yourself");
        require(_tokenIdCounter <= TOTAL_SUPPLY, "All NFTs have been minted");
        require(!hasMinted[msg.sender], "Address has already minted");

        (uint256 superBatchId, uint256 subBatchId) = getSubBatchIdOfId(
            _tokenIdCounter
        );

        SubBatchInfo storage info = subBatchInfo[superBatchId][subBatchId];

        // Initialize sub-batch if it's the first NFT in the sub-batch
        if (info.startTokenId == 0) {
            info.startTokenId = _tokenIdCounter;
            info.endTokenId = _tokenIdCounter + SUB_BATCH_SIZE - 1;
            info.startTime = block.timestamp;
        }

        // Update sub-batch info if this is the last NFT in current sub-batch
        if (_tokenIdCounter % SUB_BATCH_SIZE == 0) {
            info.lastNFTMintedTime = block.timestamp;
            // Update lastCompletedBatch when a sub-batch is completed
            lastCompletedBatch = LastCompletedBatchInfo({
                superBatchId: superBatchId,
                subBatchId: subBatchId,
                lastNFTMintedTime: block.timestamp,
                claimed: false
            });
        }

        // Add minter to all minters set
        allMinters.push(msg.sender);

        uint256 paymentAmount;
        uint256 currentRewardPercentage = claimPoolPercentage; // 36.9%

        // ETH payment
        paymentAmount = msg.value;
        require(paymentAmount >= getCurrentPrice(), "Incorrect ETH amount");

        // Handle excess ETH refund
        uint256 currentPrice = getCurrentPrice();
        if (paymentAmount > currentPrice) {
            uint256 excess = paymentAmount - currentPrice;
            (bool refundSuccess, ) = payable(msg.sender).call{value: excess}(
                ""
            );
            require(refundSuccess, "Excess fee refund failed");
            paymentAmount = currentPrice;
        }

        // Handle referral
        if (referrer != address(0) && referrer != msg.sender) {
            referredBy[msg.sender] = referrer;
            referralCount[referrer]++;
            referrers.add(referrer);
            emit ReferralRecorded(msg.sender, referrer);
        }

        // Calculate fee split using current group's reward percentage
        uint256 rewardAmount = (paymentAmount * currentRewardPercentage) /
            BASIS_POINTS;

        // Mint NFT
        hasMinted[msg.sender] = true;
        _mint(msg.sender, _tokenIdCounter);
        addressToTokenId[msg.sender] = _tokenIdCounter;

        // Update reward pool
        collectedRewardForSubBatch[superBatchId][subBatchId] += rewardAmount;

        // Update total unclaimed rewards
        totalUnclaimedRewards += rewardAmount;

        // Distribute fees
        _distributeFees(paymentAmount);

        emit NFTMinted(msg.sender, _tokenIdCounter);

        _tokenIdCounter++;
    }

    function _distributeFees(uint256 feeAmount) internal {
        uint256 publicGoodFundsAmount = (feeAmount *
            publicGoodFundsPercentage) / BASIS_POINTS;
        uint256 devFundsAmount = (feeAmount * devFundsPercentage) /
            BASIS_POINTS;
        uint256 urNFTETHAmount = (feeAmount * urNFTETHPercentage) /
            BASIS_POINTS;

        (bool publicGoodFundsSuccess, ) = payable(publicGoodFunds).call{
            value: publicGoodFundsAmount
        }("");
        require(publicGoodFundsSuccess, "Public good funds transfer failed");

        (bool devFundsSuccess, ) = payable(devFunds).call{
            value: devFundsAmount
        }("");
        require(devFundsSuccess, "Dev funds transfer failed");

        (bool urNFTETHSuccess, ) = payable(urNFTETH).call{
            value: urNFTETHAmount
        }("");
        require(urNFTETHSuccess, "urNFTETH transfer failed");
    }

    /**
     * @notice Claims reward for the winner
     * @dev Verifies the caller is the winner, calculates rewards, and marks batches as claimed
     */
    function claimReward() external nonReentrant {
        // Get winner and reward details
        (
            address winner,
            ,
            uint256 winnerSuperBatchId,
            uint256 winnerSubBatchId,
            uint256 reward
        ) = getWinnerAndReward();

        require(winner == msg.sender, "Not the current winner");
        require(reward > 0, "No rewards to claim");

        // Mark all batches up to winner's batch as claimed in reverse order
        // This ensures we process from the most recent batch to the oldest
        for (
            uint256 superBatchId = winnerSuperBatchId;
            superBatchId >= 1;
            superBatchId--
        ) {
            uint256 startSubBatch = superBatchId == winnerSuperBatchId
                ? winnerSubBatchId
                : SUB_BATCHES_PER_SUPER_BATCH;

            for (
                uint256 subBatchId = startSubBatch;
                subBatchId >= 1;
                subBatchId--
            ) {
                // Adjust indices for storage access
                SubBatchInfo storage info = subBatchInfo[superBatchId][
                    subBatchId
                ];

                // If we encounter a batch that's already claimed, we can stop
                if (info.claimed) {
                    break;
                }

                // Mark batch as claimed
                info.claimed = true;
                info.rewardClaimedTime = block.timestamp;
            }
        }

        // Update lastCompletedBatch.claimed if this is the last completed batch
        if (
            lastCompletedBatch.superBatchId == winnerSuperBatchId &&
            lastCompletedBatch.subBatchId == winnerSubBatchId
        ) {
            lastCompletedBatch.claimed = true;
        }

        // Update total unclaimed rewards
        totalUnclaimedRewards -= reward;

        // Transfer reward to winner
        (bool success, ) = payable(winner).call{value: reward}("");
        require(success, "Reward transfer failed");

        emit RewardClaimed(
            winner,
            winnerSuperBatchId,
            winnerSubBatchId,
            block.timestamp,
            reward
        );
    }

    /**
     * @notice Override of ERC721 transferFrom function to implement soulbound behavior
     * @dev This function always reverts as NFTs are non-transferable (soulbound)
     * @param from The current owner of the token
     * @param to The address to receive the token
     * @param tokenId The ID of the token being transferred
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        revert("NFTs are soulbound and cannot be transferred");
    }

    /**
     * @notice Override of ERC721 safeTransferFrom function to implement soulbound behavior
     * @dev This function always reverts as NFTs are non-transferable (soulbound)
     * @param from The current owner of the token
     * @param to The address to receive the token
     * @param tokenId The ID of the token being transferred
     * @param data Additional data with no specified format
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        revert("NFTs are soulbound and cannot be transferred");
    }

    // ============= setters =============

    /**
     * @notice Allows the owner to change the prices of the batches
     * @dev Only the owner can change the batch prices
     * @param batch1Price The new price for the first batch
     * @param batch2Price The new price for the second batch
     * @param batch3Price The new price for the third batch
     * @param batch4Price The new price for the third batch
     */
    function setSuperBatchPrices(
        uint256 batch1Price,
        uint256 batch2Price,
        uint256 batch3Price,
        uint256 batch4Price
    ) external onlyOwner {
        require(
            batch1Price > 0 &&
                batch2Price > batch1Price &&
                batch3Price > batch2Price &&
                batch4Price > batch3Price,
            "Invalid price progression"
        );
        SUPER_BATCH_PRICES[0] = batch1Price;
        SUPER_BATCH_PRICES[1] = batch2Price;
        SUPER_BATCH_PRICES[2] = batch3Price;
        SUPER_BATCH_PRICES[3] = batch4Price;
        emit SuperBatchPricesUpdated(
            batch1Price,
            batch2Price,
            batch3Price,
            batch4Price
        );
    }

    // set images URI
    function setSUPER_BATCH_IMAGES(
        string memory image1URI,
        string memory image2URI,
        string memory image3URI,
        string memory image4URI
    ) external onlyOwner {
        SUPER_BATCH_IMAGES[0] = image1URI;
        SUPER_BATCH_IMAGES[1] = image2URI;
        SUPER_BATCH_IMAGES[2] = image3URI;
        SUPER_BATCH_IMAGES[3] = image4URI;
    }

    // set the claim window
    function setClaimWindow(uint256 _claimWindow) external onlyOwner {
        CLAIM_WINDOW = _claimWindow;
    }

    // Set the public good funds address
    function setPublicGoodFunds(address _publicGoodFunds) external onlyOwner {
        require(_publicGoodFunds != address(0), "Invalid address");
        publicGoodFunds = _publicGoodFunds;
    }

    // Set the dev funds address
    function setDevFunds(address _devFunds) external onlyOwner {
        require(_devFunds != address(0), "Invalid address");
        devFunds = _devFunds;
    }

    // Set the urNFTETH address
    function setUrNFTETH(address _urNFTETH) external onlyOwner {
        require(_urNFTETH != address(0), "Invalid address");
        urNFTETH = _urNFTETH;
    }

    // Set the claim pool percentage
    function setClaimPoolPercentage(
        uint256 _claimPoolPercentage
    ) external onlyOwner {
        require(
            _claimPoolPercentage <= BASIS_POINTS,
            "Percentage exceeds 100%"
        );
        claimPoolPercentage = _claimPoolPercentage;
        emit FeeDistributionUpdated(
            _claimPoolPercentage,
            publicGoodFundsPercentage,
            devFundsPercentage,
            urNFTETHPercentage
        );
    }

    // Set the public good funds percentage
    function setPublicGoodFundsPercentage(
        uint256 _publicGoodFundsPercentage
    ) external onlyOwner {
        require(
            _publicGoodFundsPercentage <= BASIS_POINTS,
            "Percentage exceeds 100%"
        );
        publicGoodFundsPercentage = _publicGoodFundsPercentage;
        emit FeeDistributionUpdated(
            claimPoolPercentage,
            _publicGoodFundsPercentage,
            devFundsPercentage,
            urNFTETHPercentage
        );
    }

    // Set the dev funds percentage
    function setDevFundsPercentage(
        uint256 _devFundsPercentage
    ) external onlyOwner {
        require(_devFundsPercentage <= BASIS_POINTS, "Percentage exceeds 100%");
        devFundsPercentage = _devFundsPercentage;
        emit FeeDistributionUpdated(
            claimPoolPercentage,
            publicGoodFundsPercentage,
            _devFundsPercentage,
            urNFTETHPercentage
        );
    }

    // Set the urNFTETH percentage
    function setUrNFTETHPercentage(
        uint256 _urNFTETHPercentage
    ) external onlyOwner {
        require(_urNFTETHPercentage <= BASIS_POINTS, "Percentage exceeds 100%");
        urNFTETHPercentage = _urNFTETHPercentage;
        emit FeeDistributionUpdated(
            claimPoolPercentage,
            publicGoodFundsPercentage,
            devFundsPercentage,
            _urNFTETHPercentage
        );
    }

    // Add setter for final recipient
    function setFinalRecipient(address _finalRecipient) external onlyOwner {
        require(_finalRecipient != address(0), "Invalid address");
        finalRecipient = _finalRecipient;
    }

    // Add function to update metadata URIs
    function setBatchMetadataURI(
        uint256 batchId,
        string memory newURI
    ) external onlyOwner {
        require(batchId > 0 && batchId <= SUPER_BATCHES, "Invalid batch ID");
        require(bytes(newURI).length > 0, "URI cannot be empty");
        BATCH_METADATA_URIS[batchId - 1] = newURI;
        emit BatchMetadataURIUpdated(batchId, newURI);
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        // Verify conditions again to ensure they are still valid
        require(
            isAllBatchesCompleted(),
            "Not all batches completed or claim window not expired"
        );
        require(finalRecipient != address(0), "Final recipient not set");

        // Get the last batch info
        (
            uint256 lastSuperBatchId,
            uint256 lastSubBatchId
        ) = getCurrentSubBatch();
        SubBatchInfo memory lastInfo = subBatchInfo[lastSuperBatchId][
            lastSubBatchId
        ];
        require(!lastInfo.claimed, "Last batch already claimed");

        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to transfer");

        // Transfer all remaining funds to final recipient
        (bool success, ) = payable(finalRecipient).call{value: balance}("");
        require(success, "Transfer failed");

        collectedRewardForSubBatch[lastSuperBatchId][lastSubBatchId] = 0;
        totalUnclaimedRewards = 0;
    }

    // ============================
    // read functions
    // ============================

    /**
     * @notice Chainlink Keeper checkUpkeep function
     * @dev Checks if the contract needs to perform upkeep
     * @return needsUpkeep Whether upkeep is needed
     * @return performData Data needed for performUpkeep
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool needsUpkeep, bytes memory performData)
    {
        // Check if all batches are completed and claim window expired
        if (!isAllBatchesCompleted()) {
            return (false, "");
        }

        // Get the last batch info
        (
            uint256 lastSuperBatchId,
            uint256 lastSubBatchId
        ) = getCurrentSubBatch();
        SubBatchInfo memory lastInfo = subBatchInfo[lastSuperBatchId][
            lastSubBatchId
        ];

        // Check if the last batch is already claimed
        if (lastInfo.claimed) {
            return (false, "");
        }

        // Check if there are funds to transfer
        if (address(this).balance == 0) {
            return (false, "");
        }

        // If we reach here, we need to perform upkeep
        return (true, "");
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(tokenId > 0 && tokenId <= TOTAL_SUPPLY, "Token does not exist");

        // Get the super batch ID for this token
        uint256 superBatchId = getSuperBatchIdOfId(tokenId);

        // Get the base URI for this batch
        string memory batchBaseURI = BATCH_METADATA_URIS[superBatchId - 1];

        // Return the complete URI with actual token ID
        return
            string(
                abi.encodePacked(
                    batchBaseURI,
                    Strings.toString(tokenId),
                    ".json"
                )
            );
    }

    // Counter for token IDs
    function getNextTokenIdCounter() public view returns (uint256) {
        return _tokenIdCounter;
    }

    function _totalMinted() internal view returns (uint256) {
        return _tokenIdCounter - 1;
    }

    function getCurrentSuperBatch() public view returns (uint256) {
        uint256 totalMinted = _totalMinted();
        if (totalMinted <= SUPER_BATCH_SIZE) return 1;
        if (totalMinted <= SUPER_BATCH_SIZE * 2) return 2;
        if (totalMinted <= SUPER_BATCH_SIZE * 3) return 3;
        if (totalMinted <= SUPER_BATCH_SIZE * 4) return 4;
        return 4; // Return last batch if all minted
    }

    function getCurrentSuperBatchInfo()
        external
        view
        returns (
            uint256 superBatchNumber,
            uint256 rewardPercentage,
            uint256 startTokenId,
            uint256 endTokenId,
            uint256 currentPrice
        )
    {
        superBatchNumber = getCurrentSuperBatch();
        rewardPercentage = claimPoolPercentage;
        startTokenId = ((superBatchNumber - 1) * SUPER_BATCH_SIZE) + 1;
        endTokenId = superBatchNumber * SUPER_BATCH_SIZE;
        currentPrice = getCurrentPrice();
    }

    function getCurrentSubBatch()
        public
        view
        returns (uint256 superBatchId, uint256 subBatchId)
    {
        uint256 totalMinted = _totalMinted();
        if (totalMinted == 0) {
            return (0, 0); // No NFTs minted yet
        }
        superBatchId = getCurrentSuperBatch();
        subBatchId =
            (((totalMinted - 1) / SUB_BATCH_SIZE) %
                SUB_BATCHES_PER_SUPER_BATCH) +
            1;
    }

    function getCurrentSubBatchInfo()
        external
        view
        returns (
            uint256 superBatch,
            uint256 subBatch,
            uint256 startTime,
            uint256 lastNFTMintTime,
            uint256 rewardClaimTime,
            uint256 rewardPercentage,
            uint256 startTokenId,
            uint256 endTokenId,
            uint256 currentPrice,
            bool claimed
        )
    {
        (superBatch, subBatch) = getCurrentSubBatch();
        SubBatchInfo memory info = subBatchInfo[superBatch][subBatch];
        startTime = info.startTime;
        lastNFTMintTime = info.lastNFTMintedTime;
        rewardClaimTime = info.rewardClaimedTime;
        rewardPercentage = claimPoolPercentage;
        startTokenId = info.startTokenId;
        endTokenId = info.endTokenId;
        currentPrice = getCurrentPrice();
        claimed = info.claimed;
    }

    function getSubBatchInfoOf(
        uint256 superBatchId,
        uint256 subBatchId
    )
        external
        view
        returns (
            uint256 superBatch,
            uint256 subBatch,
            uint256 startTime,
            uint256 lastNFTMintTime,
            uint256 rewardClaimTime,
            uint256 rewardPercentage,
            uint256 startTokenId,
            uint256 endTokenId,
            uint256 currentPrice,
            bool claimed
        )
    {
        superBatch = superBatchId;
        subBatch = subBatchId;
        SubBatchInfo memory info = subBatchInfo[superBatch][subBatch];
        startTime = info.startTime;
        lastNFTMintTime = info.lastNFTMintedTime;
        rewardClaimTime = info.rewardClaimedTime;
        rewardPercentage = claimPoolPercentage;
        startTokenId = info.startTokenId;
        endTokenId = info.endTokenId;
        currentPrice = getCurrentPrice();
        claimed = info.claimed;
    }

    // function to get collected reward for a specific sub batch
    function getCollectedRewardOfSubBatch(
        uint256 superBatchId,
        uint256 subBatchId
    ) external view returns (uint256) {
        require(
            superBatchId > 0 && superBatchId <= 4,
            "Invalid super batch ID"
        );
        require(
            subBatchId > 0 && subBatchId <= SUB_BATCHES_PER_SUPER_BATCH,
            "Invalid sub batch ID"
        );
        return collectedRewardForSubBatch[superBatchId][subBatchId];
    }

    function getSuperBatchIdOfId(
        uint256 _tokenId
    ) public pure returns (uint256) {
        if (_tokenId <= SUPER_BATCH_SIZE) return 1;
        if (_tokenId <= SUPER_BATCH_SIZE * 2) return 2;
        if (_tokenId <= SUPER_BATCH_SIZE * 3) return 3;
        if (_tokenId <= SUPER_BATCH_SIZE * 4) return 4;
        return 4; // Return last batch if all minted
    }

    function getSubBatchIdOfId(
        uint256 _tokenId
    ) public pure returns (uint256 superBatchId, uint256 subBatchId) {
        superBatchId = getSuperBatchIdOfId(_tokenId);

        subBatchId =
            (((_tokenId - 1) / SUB_BATCH_SIZE) % SUB_BATCHES_PER_SUPER_BATCH) +
            1;
    }

    function getCurrentPrice() public view returns (uint256) {
        uint256 nextTokenId = _totalMinted() + 1;
        uint256 batchId = getSuperBatchIdOfId(nextTokenId);
        return SUPER_BATCH_PRICES[batchId - 1];
    }

    // function to get the price of a batch
    function getSuperBatchPrice(
        uint256 superBatchId
    ) public view returns (uint256) {
        require(superBatchId > 0 && superBatchId <= 4, "Invalid batch ID");
        return SUPER_BATCH_PRICES[superBatchId - 1];
    }

    function getRemainingNFTs() public view returns (uint256) {
        return TOTAL_SUPPLY - _totalMinted();
    }

    function getContractStatus()
        external
        view
        returns (
            uint256 totalMinted,
            uint256 currentSuperBatch,
            uint256 currentSubBatch,
            uint256 currentPrice,
            uint256 remainingSupply
        )
    {
        totalMinted = _totalMinted();
        (currentSuperBatch, currentSubBatch) = getCurrentSubBatch();
        currentPrice = getCurrentPrice();
        remainingSupply = getRemainingNFTs();
    }

    // function get the superbatch of next tokenId alongwith it's image
    function getNextIdImageWithSuperBatch()
        external
        view
        returns (uint256 superBatchId, string memory imageUrl)
    {
        uint256 nextTokenId = _totalMinted() + 1;
        if (nextTokenId > TOTAL_SUPPLY) {
            return (4, SUPER_BATCH_IMAGES[3]);
        }
        superBatchId = getSuperBatchIdOfId(nextTokenId);
        imageUrl = SUPER_BATCH_IMAGES[superBatchId - 1];
    }

    /**
     * @notice Returns all referrers and their referral counts
     * @return _referrers Array of referrer addresses
     * @return _counts Array of referral counts corresponding to the referrers
     */
    function getAllReferrersWithCounts()
        external
        view
        returns (address[] memory _referrers, uint256[] memory _counts)
    {
        uint256 length = referrers.length();
        _referrers = new address[](length);
        _counts = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            address referrer = referrers.at(i);
            _referrers[i] = referrer;
            _counts[i] = referralCount[referrer];
        }

        return (_referrers, _counts);
    }

    /**
     * @notice Returns the total number of unique referrers
     */
    function getReferrersCount() external view returns (uint256) {
        return referrers.length();
    }

    /**
     * @notice Returns all unique referrers
     * @return _referrers Array of referrer addresses
     */
    function getAllReferrers()
        external
        view
        returns (address[] memory _referrers)
    {
        return referrers.values();
    }

    /**
     * @notice Returns the total number of referrals for a specific referrer
     * @param referrer Address of the referrer to check
     * @return Total number of referrals for the specified referrer
     */
    function getReferralsCountForReferrer(
        address referrer
    ) external view returns (uint256) {
        return referralCount[referrer];
    }

    /**
     * @notice Returns whether an address is a referrer
     * @param account Address to check
     */
    function isReferrer(address account) external view returns (bool) {
        return referrers.contains(account);
    }

    /**
     * @notice Returns who referred a specific minter
     * @param minter Address of the minter to check
     * @return Address of the referrer (address(0) if none)
     */
    function getReferrer(address minter) external view returns (address) {
        return referredBy[minter];
    }

    /**
     * @notice Returns the token ID minted by a specific address
     * @param owner Address to check
     * @return tokenId The token ID minted by the address (0 if none)
     */
    function getTokenIdByOwner(address owner) external view returns (uint256) {
        return addressToTokenId[owner];
    }

    // Add new function to get all historical minters
    /**
     * @notice Returns all historical minters
     * @dev Returns array of all addresses that have minted NFTs
     * @return Array of minter addresses
     */
    function getAllMinters() external view returns (address[] memory) {
        return allMinters;
    }

    /**
     * @notice Returns the sub-batch ID that is currently active for claiming
     * @return superBatchId The super batch ID
     * @return subBatchId The sub batch ID
     */
    function getActiveSubBatch()
        public
        view
        returns (uint256 superBatchId, uint256 subBatchId)
    {
        (superBatchId, subBatchId) = getCurrentSubBatch();

        // Check if current sub-batch is complete and within claim window
        SubBatchInfo memory info = subBatchInfo[superBatchId][subBatchId];
        if (
            info.lastNFTMintedTime > 0 &&
            block.timestamp < info.lastNFTMintedTime + CLAIM_WINDOW
        ) {
            return (superBatchId, subBatchId);
        }

        // If current sub-batch is not active, check previous sub-batches
        while (subBatchId > 1) {
            subBatchId--;
            info = subBatchInfo[superBatchId][subBatchId];
            if (
                info.lastNFTMintedTime > 0 &&
                block.timestamp < info.lastNFTMintedTime + CLAIM_WINDOW
            ) {
                return (superBatchId, subBatchId);
            }
        }

        // If no active sub-batch found in current super batch, check previous super batches
        while (superBatchId > 1) {
            superBatchId--;
            subBatchId = SUB_BATCHES_PER_SUPER_BATCH; // Last sub-batch of previous super batch
            while (subBatchId > 1) {
                info = subBatchInfo[superBatchId][subBatchId];
                if (
                    info.lastNFTMintedTime > 0 &&
                    block.timestamp < info.lastNFTMintedTime + CLAIM_WINDOW
                ) {
                    return (superBatchId, subBatchId);
                }
                subBatchId--;
            }
        }
        return (0, 0); // No active sub-batch found
    }

    /**
     * @notice Randomly selects a winner from all minters up to the active sub-batch
     * @return winner The address of the selected winner
     */
    function selectWinner()
        public
        view
        returns (
            address winner,
            uint256 superBatchIdOfWinner,
            uint256 subBatchIdOfWinner
        )
    {
        if (_totalMinted() == 0) {
            return (address(0), 0, 0); // No minters available
        }

        // Get active sub-batch
        (
            uint256 activeSuperBatchId,
            uint256 activeSubBatchId
        ) = getActiveSubBatch();

        if (activeSuperBatchId == 0 || activeSubBatchId == 0) {
            return (address(0), 0, 0); // No active sub-batch found
        }

        // Check if the active batch is already claimed
        SubBatchInfo memory activeBatch = subBatchInfo[activeSuperBatchId][
            activeSubBatchId
        ];
        if (activeBatch.claimed) {
            return (address(0), 0, 0); // Active batch already claimed
        }

        // Calculate total NFTs up to active sub-batch
        uint256 totalEligibleNFTs = ((activeSuperBatchId - 1) *
            SUPER_BATCH_SIZE) + (activeSubBatchId * SUB_BATCH_SIZE);

        // Ensure we don't exceed actual minted tokens
        uint256 actualMinted = _totalMinted();
        if (totalEligibleNFTs > actualMinted) {
            totalEligibleNFTs = actualMinted;
        }

        if (totalEligibleNFTs == 0) {
            return (address(0), 0, 0);
        }

        // Use the lastNFTMintedTime instead of block.timestamp for deterministic winner selection
        uint256 claimWindowStart = activeBatch.lastNFTMintedTime;

        // Create a deterministic seed using batch IDs and claim window start time
        bytes32 seed = keccak256(
            abi.encodePacked(
                activeSuperBatchId,
                activeSubBatchId,
                claimWindowStart,
                "UR369_WINNER_SELECTION" // Add a fixed string to ensure consistent hashing
            )
        );

        // Select winner from eligible minters
        uint256 randomIndex = uint256(seed) % totalEligibleNFTs;
        return (allMinters[randomIndex], activeSuperBatchId, activeSubBatchId);
    }

    /**
     * @notice Verifies winner
     * @param _winner The address of potential winner to verify
     * @return isWinner Whether the address matches current winner
     */
    function verifyWinner(address _winner) public view returns (bool) {
        (address currentWinner, , ) = selectWinner();
        return _winner == currentWinner;
    }

    /**
     * @notice get winner and calculates total unclaimed rewards
     * @return winner winner address
     * @return winnerTokenId winner's token id
     * @return winnerSuperBatchId winner superbatch id
     * @return winnerSubBatchId winner subbatch id
     * @return reward Total unclaimed rewards if winner is valid
     */
    function getWinnerAndReward()
        public
        view
        returns (
            address winner,
            uint256 winnerTokenId,
            uint256 winnerSuperBatchId,
            uint256 winnerSubBatchId,
            uint256 reward
        )
    {
        (
            address currentWinner,
            uint256 superBatchId,
            uint256 subBatchId
        ) = selectWinner();

        // Get winner's token and batch info
        winner = currentWinner;
        winnerSuperBatchId = superBatchId;
        winnerSubBatchId = subBatchId;
        winnerTokenId = addressToTokenId[winner];

        reward = calculateRewardUptoBatch(winnerSuperBatchId, winnerSubBatchId);
    }

    /**
     * @notice Calculates total unclaimed rewards up to and including specified batch
     * @param superBatchId The super batch ID to calculate rewards until
     * @param subBatchId The sub batch ID to calculate rewards until
     * @return totalReward Total unclaimed rewards up to specified batch
     */
    function calculateRewardUptoBatch(
        uint256 superBatchId,
        uint256 subBatchId
    ) public view returns (uint256 totalReward) {
        // require(
        //     superBatchId > 0 &&
        //         superBatchId <= SUPER_BATCHES &&
        //         subBatchId > 0 &&
        //         subBatchId <= SUB_BATCHES_PER_SUPER_BATCH,
        //     "Invalid batch ID"
        // );
        // Add reward from current specified sub-batch if completed
        SubBatchInfo memory currentInfo = subBatchInfo[superBatchId][
            subBatchId
        ];
        if (currentInfo.lastNFTMintedTime > 0) {
            totalReward = collectedRewardForSubBatch[superBatchId][subBatchId];
        }

        // Check previous sub-batches in current super batch
        for (uint256 i = subBatchId; i > 1; i--) {
            SubBatchInfo memory info = subBatchInfo[superBatchId][i - 1];
            if (info.claimed) {
                break; // Stop if we hit a claimed batch
            } else if (info.lastNFTMintedTime > 0) {
                totalReward += collectedRewardForSubBatch[superBatchId][i - 1];
            }
        }

        // Check previous super batches
        for (uint256 i = superBatchId; i > 1; i--) {
            bool batchClaimed = false;
            for (uint256 j = SUB_BATCHES_PER_SUPER_BATCH; j >= 1; j--) {
                SubBatchInfo memory info = subBatchInfo[i - 1][j];
                if (info.claimed) {
                    batchClaimed = true;
                    break; // Stop checking this super batch
                } else if (info.lastNFTMintedTime > 0) {
                    totalReward += collectedRewardForSubBatch[i - 1][j];
                }
            }
            if (batchClaimed) {
                break; // Stop checking previous batches
            }
        }

        return totalReward;
    }

    /**
     * @notice Checks if all batches are completed and claim window has expired
     * @return bool True if all batches are completed and claim window expired
     */
    function isAllBatchesCompleted() public view returns (bool) {
        // Check if all NFTs are minted
        if (_totalMinted() < TOTAL_SUPPLY) {
            return false;
        }

        // Get the last sub-batch info
        (
            uint256 lastSuperBatchId,
            uint256 lastSubBatchId
        ) = getCurrentSubBatch();
        SubBatchInfo memory lastInfo = subBatchInfo[lastSuperBatchId][
            lastSubBatchId
        ];

        // Check if claim window has expired for the last batch
        if (
            lastInfo.lastNFTMintedTime == 0 ||
            block.timestamp < lastInfo.lastNFTMintedTime + CLAIM_WINDOW
        ) {
            return false;
        }

        return true;
    }

    /**
     * @notice Returns information about the last completed batch where claim window has expired and reward is not claimed
     * @return superBatchId The super batch ID
     * @return subBatchId The sub batch ID
     * @return reward The reward amount
     * @return lastNFTMintedTime When the last NFT was minted
     * @return exists Whether such a batch exists
     */
    function getLastCompletedBatchInfo()
        external
        view
        returns (
            uint256 superBatchId,
            uint256 subBatchId,
            uint256 reward,
            uint256 lastNFTMintedTime,
            bool exists
        )
    {
        if (lastCompletedBatch.lastNFTMintedTime == 0) {
            return (0, 0, 0, 0, false);
        }

        // Check if claim window has expired and reward is not claimed
        bool claimWindowExpired = block.timestamp >=
            lastCompletedBatch.lastNFTMintedTime + CLAIM_WINDOW;
        if (!lastCompletedBatch.claimed && claimWindowExpired) {
            superBatchId = lastCompletedBatch.superBatchId;
            subBatchId = lastCompletedBatch.subBatchId;
            reward = calculateRewardUptoBatch(
                lastCompletedBatch.superBatchId,
                lastCompletedBatch.subBatchId
            );
            lastNFTMintedTime = lastCompletedBatch.lastNFTMintedTime;
            exists = true;
            return (
                superBatchId,
                subBatchId,
                reward,
                lastNFTMintedTime,
                exists
            );
        }

        return (0, 0, 0, 0, false);
    }
}
