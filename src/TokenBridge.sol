// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MilkiWay} from "./MilkiWay.sol";

contract TokenBridge is Ownable, ReentrancyGuard {
    event Deposited(
        bytes32 indexed id, 
        address indexed from, 
        uint256 amount, 
        uint256 nonce,
        uint256 chainId,
        uint256 blockNumber
    );

    event Released(
        bytes32 indexed id, 
        address indexed to, 
        uint256 amount,
        uint256 chainId
    );

    event BridgePaused(bool paused);
    bool public paused = false;

    MilkiWay public token;
    mapping(bytes32 => bool) public processed;
    mapping(address => uint256) public nonces;
    
    uint256 public constant MIN_DEPOSIT = 1e18;
    uint256 public constant MAX_DEPOSIT = 1000000e18; 
    
    modifier whenNotPaused() {
        require(!paused, "Bridge is paused");
        _;
    }

    constructor(address tokenAddress) Ownable(msg.sender) {
        token = MilkiWay(tokenAddress);
    }

    function setToken(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "Invalid address");
        token = MilkiWay(tokenAddress);
    }

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(amount >= MIN_DEPOSIT, "Amount small");
        require(amount <= MAX_DEPOSIT, "Amount large");
        
        token.burn(msg.sender, amount);
        
        bytes32 id = keccak256(abi.encodePacked(
            msg.sender, 
            amount, 
            nonces[msg.sender], 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        nonces[msg.sender]++;
        
        emit Deposited(id, msg.sender, amount, nonces[msg.sender] - 1, block.chainid, block.number);
    }

    function release(bytes32 id, address to, uint256 amount,uint256 sourceChainId) external onlyOwner whenNotPaused nonReentrant {
        require(to != address(0), "Invalid address");
        require(!processed[id], "In process");
        require(amount > 0, "Wrong amount");
        
        processed[id] = true;
        token.mint(to, amount);
        
        emit Released(id, to, amount, sourceChainId);
    }

    function pause() external onlyOwner {
        paused = true;
        emit BridgePaused(true);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit BridgePaused(false);
    }

    function getDepositId(address user, uint256 amount, uint256 nonce, uint256 chainId, uint256 blockNumber, uint256 timestamp) 
        external pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, amount, nonce, chainId, blockNumber, timestamp));
    }

    function mintToken(uint256 amount) external onlyOwner {
        token.mint(msg.sender, amount);
    }
}
