// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MilkiWay} from "./MilkiWay.sol";

contract TokenBridge is Ownable, ReentrancyGuard {
    event TokensBurned(
        address indexed user,
        uint256 amount,
        uint256 nonce,
        uint256 timestamp
    );
    
    event TokensMinted(
        address indexed user,
        uint256 amount,
        uint256 nonce,
        uint256 timestamp
    );
    
    event DepositProcessed(
        address indexed user,
        uint256 amount,
        uint256 nonce,
        bool success
    );

    MilkiWay public immutable token;
    
    mapping(uint256 => bool) public processedNonces;
    mapping(address => uint256) public userNonces;
    
    uint256 public minTransferAmount = 1 ether;
    uint256 public maxTransferAmount = 1000000 ether;

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        require(_token != address(0), "TokenBridge: invalid token address");
        token = MilkiWay(_token);
    }

    bool public bridgePaused = false;
    modifier whenNotPaused() {
        require(!bridgePaused, "TokenBridge: bridge is paused");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount >= minTransferAmount, "TokenBridge: amount too small");
        require(amount <= maxTransferAmount, "TokenBridge: amount too large");
        _;
    }

    function burnTokens(uint256 amount) 
        external nonReentrant whenNotPaused validAmount(amount) 
    {
        require(token.balanceOf(msg.sender) >= amount, "TokenBridge: insufficient balance");
        require(token.allowance(msg.sender, address(this)) >= amount, "TokenBridge: insufficient allowance");

        userNonces[msg.sender]++;
        uint256 currentNonce = userNonces[msg.sender];
        
        token.burnFrom(msg.sender, amount);
        
        emit TokensBurned(msg.sender, amount, currentNonce, block.timestamp);
    }

    function mintTokens(address user, uint256 amount, uint256 nonce) 
        external onlyOwner nonReentrant whenNotPaused validAmount(amount) 
    {
        require(user != address(0), "TokenBridge: invalid user address");
        require(!processedNonces[nonce], "TokenBridge: nonce already processed");
        
        processedNonces[nonce] = true;
        
        token.mint(user, amount);
        
        emit TokensMinted(user, amount, nonce, block.timestamp);
    }

    function processDeposit(address user, uint256 amount, uint256 nonce, bool success) 
        external onlyOwner 
    {
        require(user != address(0), "TokenBridge: invalid user address");
        require(!processedNonces[nonce], "TokenBridge: nonce already processed");
        
        processedNonces[nonce] = true;
        
        emit DepositProcessed(user, amount, nonce, success);
    }

    function isNonceProcessed(uint256 nonce) external view returns (bool) {
        return processedNonces[nonce];
    }

    function getUserNonce(address user) external view returns (uint256) {
        return userNonces[user];
    }

    function setMinTransferAmount(uint256 _minAmount) external onlyOwner {
        require(_minAmount > 0, "TokenBridge: min amount must be positive");
        minTransferAmount = _minAmount;
    }

    function setMaxTransferAmount(uint256 _maxAmount) external onlyOwner {
        require(_maxAmount > minTransferAmount, "TokenBridge: max amount must be greater than min");
        maxTransferAmount = _maxAmount;
    }

    function pauseBridge() external onlyOwner {
        bridgePaused = true;
    }

    function unpauseBridge() external onlyOwner {
        bridgePaused = false;
    }

    function getTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function getBridgeInfo() external view returns (
        address tokenAddress,
        bool isPaused,
        uint256 minAmount,
        uint256 maxAmount
    ) {
        return (
            address(token),
            bridgePaused,
            minTransferAmount,
            maxTransferAmount
        );
    }
}
