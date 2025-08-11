// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title GEM Token
 * @dev ERC20 token for Somnia Mines game
 * Exchange rate: 0.01 STT = 1000 GEM tokens
 */
contract GEMToken is ERC20, Ownable, ReentrancyGuard {
    
    // Exchange rate: 1000 GEM per 0.01 STT => 100,000 GEM per 1 STT (scaled to 18 decimals)
    // This constant is expressed in GEM base units (18 decimals)
    uint256 public constant TOKENS_PER_STT = 100000 * 1e18; // 100,000 GEM per 1 STT
    uint256 public constant MIN_PURCHASE = 0.001 ether; // Minimum 0.001 STT
    uint256 public constant MAX_PURCHASE = 10 ether; // Maximum 10 STT per transaction
    
    // Events
    event TokensPurchased(address indexed buyer, uint256 sttAmount, uint256 gemAmount);
    event TokensBurned(address indexed from, uint256 amount);
    event EmergencyWithdraw(address indexed owner, uint256 amount);
    
    // Errors
    error InsufficientPayment();
    error ExceedsMaxPurchase();
    error BelowMinPurchase();
    error InsufficientBalance();
    error TransferFailed();
    
    constructor() ERC20("GEM Token", "GEM") {}
    
    /**
     * @dev Purchase GEM tokens with STT
     * Rate: 1000 GEM = 0.01 STT
     */
    function purchaseTokens() external payable nonReentrant {
        if (msg.value < MIN_PURCHASE) revert BelowMinPurchase();
        if (msg.value > MAX_PURCHASE) revert ExceedsMaxPurchase();
        
        // Calculate GEM tokens to mint (in 18-decimal token units)
        // gemAmountWei = sttWei * TOKENS_PER_STT / 1e18
        uint256 gemAmount = (msg.value * TOKENS_PER_STT) / 1 ether;
        
        // Mint tokens to buyer
        _mint(msg.sender, gemAmount);
        
        emit TokensPurchased(msg.sender, msg.value, gemAmount);
    }
    
    /**
     * @dev Burn tokens (used when betting)
     * Only called by authorized game contracts
     */
    function burn(address from, uint256 amount) external {
        if (balanceOf(from) < amount) revert InsufficientBalance();
        
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }
    
    /**
     * @dev Mint tokens (used when winning games)
     * Only called by authorized game contracts
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /**
     * @dev Get purchase quote
     * @param sttAmount Amount of STT to spend
     * @return gemAmount Amount of GEM tokens received
     */
    function getPurchaseQuote(uint256 sttAmount) external pure returns (uint256 gemAmount) {
        // sttAmount in wei → returns GEM amount in token base units (wei)
        return (sttAmount * TOKENS_PER_STT) / 1 ether;
    }
    
    /**
     * @dev Emergency withdraw for owner (only if needed)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner()).call{value: balance}("");
        if (!success) revert TransferFailed();
        
        emit EmergencyWithdraw(owner(), balance);
    }
    
    /**
     * @dev Get contract STT balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Override transfer to add game integration hooks
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        
        // Add any game-specific logic here if needed
        // For example, preventing transfers during active games
    }
}