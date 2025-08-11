// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./GEMToken.sol";

/**
 * @title Somnia Mines Game
 * @dev Provably fair mines game using GEM tokens
 */
contract SomniaMines is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    
    // Game configuration
    uint8 public constant GRID_SIZE = 25; // 5x5 grid
    uint8 public constant MIN_MINES = 1;
    uint8 public constant MAX_MINES = 10;
    uint256 public constant MIN_BET = 1e18; // 1 GEM
    uint256 public constant MAX_BET = 10000e18; // 10,000 GEM
    
    // Game counter
    Counters.Counter private _gameIds;
    
    // GEM Token contract
    GEMToken public immutable gemToken;
    
    // Game states
    enum GameState { Active, Completed, Abandoned }
    
    struct Game {
        address player;
        uint256 betAmount;
        uint8 mineCount;
        uint8 gemsFound;
        uint256 currentMultiplier;
        GameState state;
        bool[] revealedCells;
        bool[] minePositions;
        uint256 startTime;
        bytes32 serverSeed;
        uint256 clientSeed;
    }
    
    // Mappings
    mapping(uint256 => Game) public games;
    mapping(address => uint256[]) public playerGames;
    mapping(address => uint256) public playerStats; // Total games played
    mapping(address => uint256) public playerWins;
    
    // Multiplier tables for different mine counts
    mapping(uint8 => uint256[]) public multiplierTables;
    
    // Events
    event GameStarted(uint256 indexed gameId, address indexed player, uint256 betAmount, uint8 mineCount);
    event CellRevealed(uint256 indexed gameId, uint8 cellIndex, bool isMine, uint256 newMultiplier);
    event GameCompleted(uint256 indexed gameId, address indexed player, uint256 winAmount, bool won);
    event GameAbandoned(uint256 indexed gameId, address indexed player);
    
    // Errors
    error InvalidMineCount();
    error InvalidBetAmount();
    error GameNotActive();
    error NotGamePlayer();
    error CellAlreadyRevealed();
    error InvalidCellIndex();
    error InsufficientTokens();
    error InsufficientAllowance();
    error GameAlreadyCompleted();
    
    constructor(address _gemToken) {
        gemToken = GEMToken(_gemToken);
        _initializeMultiplierTables();
    }
    
    /**
     * @dev Start a new mines game
     * @param betAmount Amount of GEM tokens to bet
     * @param mineCount Number of mines (1-10)
     * @param clientSeed Client-provided randomness seed
     */
    function startGame(
        uint256 betAmount,
        uint8 mineCount,
        uint256 clientSeed
    ) external nonReentrant returns (uint256 gameId) {
        if (mineCount < MIN_MINES || mineCount > MAX_MINES) revert InvalidMineCount();
        if (betAmount < MIN_BET || betAmount > MAX_BET) revert InvalidBetAmount();
        if (gemToken.balanceOf(msg.sender) < betAmount) revert InsufficientTokens();
        
        // Pull bet into the game contract (requires prior approval)
        if (gemToken.allowance(msg.sender, address(this)) < betAmount) revert InsufficientAllowance();
        bool transferred = gemToken.transferFrom(msg.sender, address(this), betAmount);
        require(transferred, "Transfer failed");
        
        // Generate game ID
        _gameIds.increment();
        gameId = _gameIds.current();
        
        // Generate server seed (in production, use a commit-reveal scheme)
        bytes32 serverSeed = keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, gameId));
        
        // Generate mine positions
        bool[] memory minePositions = _generateMinePositions(serverSeed, clientSeed, mineCount);
        
        // Initialize game
        Game storage game = games[gameId];
        game.player = msg.sender;
        game.betAmount = betAmount;
        game.mineCount = mineCount;
        game.gemsFound = 0;
        game.currentMultiplier = 1e18; // 1.0x in wei
        game.state = GameState.Active;
        game.revealedCells = new bool[](GRID_SIZE);
        game.minePositions = minePositions;
        game.startTime = block.timestamp;
        game.serverSeed = serverSeed;
        game.clientSeed = clientSeed;
        
        // Update player stats
        playerGames[msg.sender].push(gameId);
        playerStats[msg.sender]++;
        
        emit GameStarted(gameId, msg.sender, betAmount, mineCount);
        
        return gameId;
    }
    
    /**
     * @dev Reveal a cell in the game
     * @param gameId The game ID
     * @param cellIndex Index of cell to reveal (0-24)
     */
    function revealCell(uint256 gameId, uint8 cellIndex) external nonReentrant {
        Game storage game = games[gameId];
        
        if (game.state != GameState.Active) revert GameNotActive();
        if (game.player != msg.sender) revert NotGamePlayer();
        if (cellIndex >= GRID_SIZE) revert InvalidCellIndex();
        if (game.revealedCells[cellIndex]) revert CellAlreadyRevealed();
        
        // Mark cell as revealed
        game.revealedCells[cellIndex] = true;
        
        if (game.minePositions[cellIndex]) {
            // Hit a mine - game over
            game.state = GameState.Completed;
            emit CellRevealed(gameId, cellIndex, true, 0);
            emit GameCompleted(gameId, msg.sender, 0, false);
        } else {
            // Found a gem
            game.gemsFound++;
            
            // Calculate new multiplier
            uint256[] storage multipliers = multiplierTables[game.mineCount];
            if (game.gemsFound < multipliers.length) {
                game.currentMultiplier = multipliers[game.gemsFound];
            }
            
            emit CellRevealed(gameId, cellIndex, false, game.currentMultiplier);
            
            // Check if all safe cells are revealed
            if (game.gemsFound == GRID_SIZE - game.mineCount) {
                _completeGame(gameId, true);
            }
        }
    }
    
    /**
     * @dev Cash out from current game
     * @param gameId The game ID
     */
    function cashOut(uint256 gameId) external nonReentrant {
        Game storage game = games[gameId];
        
        if (game.state != GameState.Active) revert GameNotActive();
        if (game.player != msg.sender) revert NotGamePlayer();
        if (game.gemsFound == 0) revert InvalidCellIndex(); // Must have found at least one gem
        
        _completeGame(gameId, true);
    }

    /**
     * @dev Cash out based on off-chain revealed progress
     * Note: This trusts the claimed gemsFound. Use only for demo; a production system must verify claims.
     */
    function cashOutWithClaim(uint256 gameId, uint8 claimedGemsFound) external nonReentrant {
        Game storage game = games[gameId];
        if (game.state != GameState.Active) revert GameNotActive();
        if (game.player != msg.sender) revert NotGamePlayer();
        if (claimedGemsFound == 0) revert InvalidCellIndex();
        uint8 maxSafe = GRID_SIZE - game.mineCount;
        if (claimedGemsFound > maxSafe) revert InvalidCellIndex();

        // Set progress and settle as win
        game.gemsFound = claimedGemsFound;
        uint256[] storage multipliers = multiplierTables[game.mineCount];
        if (claimedGemsFound < multipliers.length) {
            game.currentMultiplier = multipliers[claimedGemsFound];
        }
        _completeGame(gameId, true);
    }
    
    /**
     * @dev Complete a game and distribute winnings
     */
    function _completeGame(uint256 gameId, bool won) private {
        Game storage game = games[gameId];
        game.state = GameState.Completed;
        
        uint256 winAmount = 0;
        if (won && game.gemsFound > 0) {
            winAmount = (game.betAmount * game.currentMultiplier) / 1e18;
            gemToken.mint(game.player, winAmount);
            playerWins[game.player]++;
        }
        
        emit GameCompleted(gameId, game.player, winAmount, won);
    }
    
    /**
     * @dev Generate mine positions using provably fair randomness
     */
    function _generateMinePositions(
        bytes32 serverSeed,
        uint256 clientSeed,
        uint8 mineCount
    ) private pure returns (bool[] memory) {
        bool[] memory positions = new bool[](GRID_SIZE);
        bytes32 combinedSeed = keccak256(abi.encodePacked(serverSeed, clientSeed));
        
        uint8 minesPlaced = 0;
        uint256 seed = uint256(combinedSeed);
        
        while (minesPlaced < mineCount) {
            uint8 position = uint8(seed % GRID_SIZE);
            
            if (!positions[position]) {
                positions[position] = true;
                minesPlaced++;
            }
            
            seed = uint256(keccak256(abi.encodePacked(seed)));
        }
        
        return positions;
    }
    
    /**
     * @dev Initialize multiplier tables for different mine counts
     */
    function _initializeMultiplierTables() private {
        // Multipliers in wei (1e18 = 1.0x)
        
        // 1 mine
        uint256[] memory mines1 = new uint256[](25);
        mines1[0] = 1e18; mines1[1] = 1.03e18; mines1[2] = 1.07e18; mines1[3] = 1.12e18;
        mines1[4] = 1.18e18; mines1[5] = 1.24e18; mines1[6] = 1.32e18; mines1[7] = 1.41e18;
        mines1[8] = 1.53e18; mines1[9] = 1.67e18; mines1[10] = 1.84e18; mines1[11] = 2.06e18;
        mines1[12] = 2.35e18; mines1[13] = 2.75e18; mines1[14] = 3.32e18; mines1[15] = 4.12e18;
        mines1[16] = 5.29e18; mines1[17] = 7.09e18; mines1[18] = 9.98e18; mines1[19] = 15.08e18;
        mines1[20] = 24.47e18; mines1[21] = 43.72e18; mines1[22] = 87.91e18; mines1[23] = 219.78e18;
        mines1[24] = 879.12e18;
        multiplierTables[1] = mines1;
        
        // 3 mines
        uint256[] memory mines3 = new uint256[](23);
        mines3[0] = 1e18; mines3[1] = 1.08e18; mines3[2] = 1.17e18; mines3[3] = 1.29e18;
        mines3[4] = 1.43e18; mines3[5] = 1.60e18; mines3[6] = 1.80e18; mines3[7] = 2.06e18;
        mines3[8] = 2.38e18; mines3[9] = 2.80e18; mines3[10] = 3.35e18; mines3[11] = 4.09e18;
        mines3[12] = 5.11e18; mines3[13] = 6.54e18; mines3[14] = 8.59e18; mines3[15] = 11.63e18;
        mines3[16] = 16.28e18; mines3[17] = 23.66e18; mines3[18] = 36.06e18; mines3[19] = 58.41e18;
        mines3[20] = 102.17e18; mines3[21] = 196.29e18; mines3[22] = 426.12e18;
        multiplierTables[3] = mines3;
        
        // Add more mine counts as needed (5, 10, etc.)
        // For brevity, showing pattern for 1 and 3 mines
    }
    
    /**
     * @dev Get game details
     */
    function getGame(uint256 gameId) external view returns (
        address player,
        uint256 betAmount,
        uint8 mineCount,
        uint8 gemsFound,
        uint256 currentMultiplier,
        GameState state,
        bool[] memory revealedCells
    ) {
        Game storage game = games[gameId];
        return (
            game.player,
            game.betAmount,
            game.mineCount,
            game.gemsFound,
            game.currentMultiplier,
            game.state,
            game.revealedCells
        );
    }
    
    /**
     * @dev Get player statistics
     */
    function getPlayerStats(address player) external view returns (
        uint256 totalGames,
        uint256 totalWins,
        uint256[] memory gameIds
    ) {
        return (
            playerStats[player],
            playerWins[player],
            playerGames[player]
        );
    }
    
    /**
     * @dev Get current game ID counter
     */
    function getCurrentGameId() external view returns (uint256) {
        return _gameIds.current();
    }
    
    /**
     * @dev Emergency function to abandon game (if stuck)
     */
    function abandonGame(uint256 gameId) external {
        Game storage game = games[gameId];
        
        if (game.player != msg.sender) revert NotGamePlayer();
        if (game.state != GameState.Active) revert GameAlreadyCompleted();
        if (block.timestamp < game.startTime + 1 hours) revert GameNotActive(); // Must wait 1 hour
        
        game.state = GameState.Abandoned;
        emit GameAbandoned(gameId, msg.sender);
    }

    /**
     * @dev Immediately forfeit an active game as a loss (no minting). Keeps staked GEM in contract.
     */
    function forfeitGame(uint256 gameId) external nonReentrant {
        Game storage game = games[gameId];
        if (game.state != GameState.Active) revert GameNotActive();
        if (game.player != msg.sender) revert NotGamePlayer();

        game.state = GameState.Completed;
        emit GameCompleted(gameId, msg.sender, 0, false);
    }
}