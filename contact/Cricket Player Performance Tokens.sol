// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Cricket Player Performance Tokens
 * @dev Smart contract for tokenizing cricket player performance
 * Fans can invest in players and earn rewards based on performance
 */
contract CricketPlayerPerformanceTokens {
    
    address public owner;
    bool private locked;
    
    struct Player {
        string name;
        string team;
        uint256 totalTokens;
        uint256 currentPrice;
        uint256 performanceScore;
        bool isActive;
        uint256 totalMatches;
        uint256 totalRuns;
        uint256 totalWickets;
    }
    
    struct Investment {
        uint256 playerId;
        uint256 tokensOwned;
        uint256 lastRewardClaim;
    }
    
    mapping(uint256 => Player) public players;
    mapping(address => mapping(uint256 => Investment)) public investments;
    mapping(address => uint256[]) public userInvestments;
    
    uint256 public nextPlayerId;
    uint256 public constant BASE_PRICE = 1 ether;
    uint256 public constant PERFORMANCE_MULTIPLIER = 10;
    uint256 public rewardPool;
    
    event PlayerAdded(uint256 indexed playerId, string name, string team);
    event TokensPurchased(address indexed investor, uint256 indexed playerId, uint256 amount, uint256 price);
    event PerformanceUpdated(uint256 indexed playerId, uint256 newScore);
    event RewardsClaimed(address indexed investor, uint256 indexed playerId, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }
    
    constructor() {
        owner = msg.sender;
        nextPlayerId = 1;
    }
    
    /**
     * @dev Core Function 1: Add a new cricket player to the platform
     * @param _name Player's name
     * @param _team Player's team
     */
    function addPlayer(string memory _name, string memory _team) external onlyOwner {
        players[nextPlayerId] = Player({
            name: _name,
            team: _team,
            totalTokens: 100000, // Initial token supply per player
            currentPrice: BASE_PRICE,
            performanceScore: 0,
            isActive: true,
            totalMatches: 0,
            totalRuns: 0,
            totalWickets: 0
        });
        
        emit PlayerAdded(nextPlayerId, _name, _team);
        nextPlayerId++;
    }
    
    /**
     * @dev Core Function 2: Purchase player performance tokens
     * @param _playerId ID of the player to invest in
     * @param _amount Number of tokens to purchase
     */
    function purchasePlayerTokens(uint256 _playerId, uint256 _amount) external payable nonReentrant {
        require(_playerId < nextPlayerId && _playerId > 0, "Invalid player ID");
        require(players[_playerId].isActive, "Player is not active");
        require(_amount > 0, "Amount must be greater than 0");
        
        Player storage player = players[_playerId];
        uint256 totalCost = player.currentPrice * _amount;
        require(msg.value >= totalCost, "Insufficient payment");
        
        // Update investment
        if (investments[msg.sender][_playerId].tokensOwned == 0) {
            userInvestments[msg.sender].push(_playerId);
        }
        
        investments[msg.sender][_playerId].playerId = _playerId;
        investments[msg.sender][_playerId].tokensOwned += _amount;
        investments[msg.sender][_playerId].lastRewardClaim = block.timestamp;
        
        // Update player price based on demand
        player.currentPrice = (player.currentPrice * 105) / 100; // 5% price increase
        
        // Add to reward pool
        rewardPool += totalCost / 10; // 10% goes to reward pool
        
        emit TokensPurchased(msg.sender, _playerId, _amount, player.currentPrice);
        
        // Refund excess payment
        if (msg.value > totalCost) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - totalCost}("");
            require(success, "Refund failed");
        }
    }
    
    /**
     * @dev Core Function 3: Update player performance and distribute rewards
     * @param _playerId ID of the player
     * @param _runs Runs scored in recent match
     * @param _wickets Wickets taken in recent match
     * @param _matchResult 1 for win, 0 for loss/draw
     */
    function updatePerformance(
        uint256 _playerId, 
        uint256 _runs, 
        uint256 _wickets, 
        uint256 _matchResult
    ) external onlyOwner {
        require(_playerId < nextPlayerId && _playerId > 0, "Invalid player ID");
        require(players[_playerId].isActive, "Player is not active");
        
        Player storage player = players[_playerId];
        
        // Calculate performance score
        uint256 performancePoints = (_runs * 2) + (_wickets * 10) + (_matchResult * 20);
        player.performanceScore += performancePoints;
        player.totalMatches++;
        player.totalRuns += _runs;
        player.totalWickets += _wickets;
        
        // Adjust token price based on performance
        if (performancePoints > 50) {
            player.currentPrice = (player.currentPrice * 110) / 100; // 10% increase for great performance
        } else if (performancePoints < 10) {
            player.currentPrice = (player.currentPrice * 95) / 100; // 5% decrease for poor performance
        }
        
        emit PerformanceUpdated(_playerId, player.performanceScore);
    }
    
    /**
     * @dev Claim performance-based rewards
     * @param _playerId ID of the player to claim rewards for
     */
    function claimRewards(uint256 _playerId) external nonReentrant {
        require(investments[msg.sender][_playerId].tokensOwned > 0, "No tokens owned for this player");
        
        Investment storage investment = investments[msg.sender][_playerId];
        Player storage player = players[_playerId];
        
        uint256 timeSinceLastClaim = block.timestamp - investment.lastRewardClaim;
        require(timeSinceLastClaim >= 1 days, "Can only claim once per day");
        
        // Calculate rewards based on performance and tokens owned
        uint256 rewardAmount = (player.performanceScore * investment.tokensOwned * timeSinceLastClaim) / 
                              (86400 * PERFORMANCE_MULTIPLIER * 1000); // Daily reward calculation
        
        require(rewardAmount <= rewardPool, "Insufficient reward pool");
        require(rewardAmount > 0, "No rewards to claim");
        
        investment.lastRewardClaim = block.timestamp;
        rewardPool -= rewardAmount;
        
        (bool success, ) = payable(msg.sender).call{value: rewardAmount}("");
        require(success, "Reward transfer failed");
        
        emit RewardsClaimed(msg.sender, _playerId, rewardAmount);
    }
    
    /**
     * @dev Get player information
     */
    function getPlayer(uint256 _playerId) external view returns (Player memory) {
        require(_playerId < nextPlayerId && _playerId > 0, "Invalid player ID");
        return players[_playerId];
    }
    
    /**
     * @dev Get user's investment in a specific player
     */
    function getUserInvestment(address _user, uint256 _playerId) external view returns (Investment memory) {
        return investments[_user][_playerId];
    }
    
    /**
     * @dev Get all player IDs a user has invested in
     */
    function getUserInvestments(address _user) external view returns (uint256[] memory) {
        return userInvestments[_user];
    }
    
    /**
     * @dev Calculate potential rewards for a user
     */
    function calculatePotentialRewards(address _user, uint256 _playerId) external view returns (uint256) {
        Investment memory investment = investments[_user][_playerId];
        Player memory player = players[_playerId];
        
        if (investment.tokensOwned == 0) return 0;
        
        uint256 timeSinceLastClaim = block.timestamp - investment.lastRewardClaim;
        return (player.performanceScore * investment.tokensOwned * timeSinceLastClaim) / 
               (86400 * PERFORMANCE_MULTIPLIER * 1000);
    }
    
    /**
     * @dev Fund the reward pool
     */
    function fundRewardPool() external payable {
        rewardPool += msg.value;
    }
    
    /**
     * @dev Withdraw contract balance (owner only)
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance - rewardPool;
        require(balance > 0, "No funds to withdraw");
        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @dev Transfer ownership
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
    
    /**
     * @dev Deactivate a player
     */
    function deactivatePlayer(uint256 _playerId) external onlyOwner {
        require(_playerId < nextPlayerId && _playerId > 0, "Invalid player ID");
        players[_playerId].isActive = false;
    }
}
