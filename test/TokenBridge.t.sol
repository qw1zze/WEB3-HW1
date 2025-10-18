// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {TokenBridge} from "../src/TokenBridge.sol";
import {MilkiWay} from "../src/MilkiWay.sol";

contract TokenBridgeTest is Test {
    TokenBridge public bridge;
    MilkiWay public token;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    uint256 public constant INITIAL_SUPPLY = 1000000 ether;
    uint256 public constant TEST_AMOUNT = 100 ether;

    event TokensBurned(address indexed user, uint256 amount, uint256 nonce, uint256 timestamp);
    event TokensMinted(address indexed user, uint256 amount, uint256 nonce, uint256 timestamp);
    event DepositProcessed(address indexed user, uint256 amount, uint256 nonce, bool success);

    function setUp() public {
        vm.startPrank(owner);
        
        token = new MilkiWay(owner);
        
        token.mint(user1, INITIAL_SUPPLY);
        token.mint(user2, INITIAL_SUPPLY);
        
        bridge = new TokenBridge(address(token), owner);
        
        token.transferOwnership(address(bridge));
        
        vm.stopPrank();
    }

    function testInitialState() public view  {
        assertEq(address(bridge.token()), address(token));
        assertEq(bridge.owner(), owner);
        assertEq(bridge.minTransferAmount(), 1 ether);
        assertEq(bridge.maxTransferAmount(), 1000000 ether);
        assertFalse(bridge.bridgePaused());
    }

    function testBurnTokens() public {
        vm.startPrank(user1);
        
        token.approve(address(bridge), TEST_AMOUNT);
        
        uint256 initialBalance = token.balanceOf(user1);
        uint256 initialNonce = bridge.userNonces(user1);
        
        bridge.burnTokens(TEST_AMOUNT);
        
        assertEq(token.balanceOf(user1), initialBalance - TEST_AMOUNT);
        assertEq(bridge.userNonces(user1), initialNonce + 1);
        
        vm.stopPrank();
    }

    function testMintTokens() public {
        vm.startPrank(owner);
        
        uint256 nonce = 12345;
        
        bridge.mintTokens(user1, TEST_AMOUNT, nonce);
        
        assertTrue(bridge.processedNonces(nonce));
        assertEq(token.balanceOf(user1), INITIAL_SUPPLY + TEST_AMOUNT);
        
        vm.stopPrank();
    }

    function testProcessDeposit() public {
        vm.startPrank(owner);
        
        uint256 nonce = 54321;
        
        vm.expectEmit(true, false, false, true);
        emit DepositProcessed(user1, TEST_AMOUNT, nonce, true);
        
        bridge.processDeposit(user1, TEST_AMOUNT, nonce, true);

        assertTrue(bridge.processedNonces(nonce));
        
        vm.stopPrank();
    }

    function testPreventDoubleProcessing() public {
        vm.startPrank(owner);
        
        uint256 nonce = 99999;
        
        bridge.mintTokens(user1, TEST_AMOUNT, nonce);
        assertTrue(bridge.processedNonces(nonce));
        
        vm.expectRevert("TokenBridge: nonce already processed");
        bridge.mintTokens(user1, TEST_AMOUNT, nonce);
        
        vm.stopPrank();
    }

    function testInsufficientBalance() public {
        vm.startPrank(user1);
        
        uint256 largeAmount = INITIAL_SUPPLY + 1;
        token.approve(address(bridge), largeAmount);
        
        vm.expectRevert("TokenBridge: amount too large");
        bridge.burnTokens(largeAmount);
        
        vm.stopPrank();
    }

    function testInsufficientAllowance() public {
        vm.startPrank(user1);
        
        vm.expectRevert("TokenBridge: insufficient allowance");
        bridge.burnTokens(TEST_AMOUNT);
        
        vm.stopPrank();
    }

    function testAmountTooSmall() public {
        vm.startPrank(user1);
        
        token.approve(address(bridge), 0.5 ether);
        
        vm.expectRevert("TokenBridge: amount too small");
        bridge.burnTokens(0.5 ether);
        
        vm.stopPrank();
    }

    function testAmountTooLarge() public {
        vm.startPrank(user1);
        
        uint256 largeAmount = 2000000 ether;
        token.approve(address(bridge), largeAmount);
        
        vm.expectRevert("TokenBridge: amount too large");
        bridge.burnTokens(largeAmount);
        
        vm.stopPrank();
    }

    function testBridgePaused() public {
        vm.startPrank(owner);
        
        bridge.pauseBridge();
        assertTrue(bridge.bridgePaused());
        
        vm.stopPrank();
        
        vm.startPrank(user1);
        
        token.approve(address(bridge), TEST_AMOUNT);
        
        vm.expectRevert("TokenBridge: bridge is paused");
        bridge.burnTokens(TEST_AMOUNT);
        
        vm.stopPrank();
        
        vm.startPrank(owner);
        
        bridge.unpauseBridge();
        assertFalse(bridge.bridgePaused());
        
        vm.stopPrank();
    }

    function testOnlyOwnerFunctions() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        bridge.mintTokens(user1, TEST_AMOUNT, 1);
        
        vm.expectRevert();
        bridge.processDeposit(user1, TEST_AMOUNT, 1, true);
        
        vm.expectRevert();
        bridge.setMinTransferAmount(2 ether);
        
        vm.expectRevert();
        bridge.setMaxTransferAmount(2000000 ether);
        
        vm.expectRevert();
        bridge.pauseBridge();
        
        vm.stopPrank();
    }

    function testSetTransferLimits() public {
        vm.startPrank(owner);
        
        bridge.setMinTransferAmount(2 ether);
        bridge.setMaxTransferAmount(2000000 ether);
        
        assertEq(bridge.minTransferAmount(), 2 ether);
        assertEq(bridge.maxTransferAmount(), 2000000 ether);
        
        vm.stopPrank();
    }

    function testInvalidMinAmount() public {
        vm.startPrank(owner);
        
        vm.expectRevert("TokenBridge: min amount must be positive");
        bridge.setMinTransferAmount(0);
        
        vm.stopPrank();
    }

    function testInvalidMaxAmount() public {
        vm.startPrank(owner);
        
        vm.expectRevert("TokenBridge: max amount must be greater than min");
        bridge.setMaxTransferAmount(0.5 ether);
        
        vm.stopPrank();
    }

    function testInvalidUserAddress() public {
        vm.startPrank(owner);
        
        vm.expectRevert("TokenBridge: invalid user address");
        bridge.mintTokens(address(0), TEST_AMOUNT, 1);
        
        vm.expectRevert("TokenBridge: invalid user address");
        bridge.processDeposit(address(0), TEST_AMOUNT, 1, true);
        
        vm.stopPrank();
    }

    function testGetBridgeInfo() public view  {
        (
            address tokenAddress,
            bool isPaused,
            uint256 minAmount,
            uint256 maxAmount
        ) = bridge.getBridgeInfo();
        
        assertEq(tokenAddress, address(token));
        assertFalse(isPaused);
        assertEq(minAmount, 1 ether);
        assertEq(maxAmount, 1000000 ether);
    }

    function testIsNonceProcessed() public {
        assertFalse(bridge.isNonceProcessed(12345));
        
        vm.startPrank(owner);
        bridge.mintTokens(user1, TEST_AMOUNT, 12345);
        vm.stopPrank();
        
        assertTrue(bridge.isNonceProcessed(12345));
    }

    function testGetUserNonce() public {
        assertEq(bridge.getUserNonce(user1), 0);
        
        vm.startPrank(user1);
        token.approve(address(bridge), TEST_AMOUNT);
        bridge.burnTokens(TEST_AMOUNT);
        vm.stopPrank();
        
        assertEq(bridge.getUserNonce(user1), 1);
    }

    function testGetTokenBalance() public {
        assertEq(bridge.getTokenBalance(), 0);
        
        vm.startPrank(address(bridge));
        token.mint(address(bridge), TEST_AMOUNT);
        vm.stopPrank();
        
        assertEq(bridge.getTokenBalance(), TEST_AMOUNT);
    }

    function testMultipleUsersNonces() public {
        vm.startPrank(user1);
        token.approve(address(bridge), TEST_AMOUNT);
        bridge.burnTokens(TEST_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(user2);
        token.approve(address(bridge), TEST_AMOUNT);
        bridge.burnTokens(TEST_AMOUNT);
        vm.stopPrank();
        
        assertEq(bridge.getUserNonce(user1), 1);
        assertEq(bridge.getUserNonce(user2), 1);
        
        vm.startPrank(user1);
        token.approve(address(bridge), TEST_AMOUNT);
        bridge.burnTokens(TEST_AMOUNT);
        vm.stopPrank();
        
        assertEq(bridge.getUserNonce(user1), 2);
        assertEq(bridge.getUserNonce(user2), 1);
    }
}