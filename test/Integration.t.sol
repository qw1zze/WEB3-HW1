// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {TokenBridge} from "../src/TokenBridge.sol";
import {MilkiWay} from "../src/MilkiWay.sol";

contract IntegrationTest is Test {
    TokenBridge public bridge;
    MilkiWay public token;
    address public owner;
    address public user1;
    address public user2;

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

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        token = new MilkiWay(owner);
        bridge = new TokenBridge(address(token));
        vm.prank(owner);
        token.transferOwnership(address(bridge));
    }

    function testCompleteBridgeFlow() public {
        uint256 amount = 1000e18;
        
        vm.prank(address(bridge));
        token.mint(user1, amount);
        assertEq(token.balanceOf(user1), amount);
        
        vm.prank(user1);
        bridge.deposit(amount);
        assertEq(token.balanceOf(user1), 0);
        assertEq(bridge.nonces(user1), 1);
        
        bytes32 depositId = keccak256(abi.encodePacked(
            user1, 
            amount, 
            uint256(0),
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        vm.stopPrank();
        bridge.release(depositId, user1, amount, block.chainid);
        assertEq(token.balanceOf(user1), amount);
        assertTrue(bridge.processed(depositId));
    }

    function testMultipleUsersBridgeFlow() public {
        uint256 amount1 = 1000e18;
        uint256 amount2 = 500e18;
        
        vm.prank(address(bridge));
        token.mint(user1, amount1);  
        vm.prank(address(bridge));
        token.mint(user2, amount2);
        
        vm.prank(user1);
        bridge.deposit(amount1);
        
        vm.prank(user2);
        bridge.deposit(amount2);
        
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(user2), 0);
        assertEq(bridge.nonces(user1), 1);
        assertEq(bridge.nonces(user2), 1);
        
        bytes32 depositId1 = keccak256(abi.encodePacked(
            user1, 
            amount1, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        bytes32 depositId2 = keccak256(abi.encodePacked(
            user2, 
            amount2, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        vm.stopPrank();
        bridge.release(depositId1, user1, amount1, block.chainid);
        
        bridge.release(depositId2, user2, amount2, block.chainid);
        
        assertEq(token.balanceOf(user1), amount1);
        assertEq(token.balanceOf(user2), amount2);
        assertTrue(bridge.processed(depositId1));
        assertTrue(bridge.processed(depositId2));
    }

    function testUserMultipleDeposits() public {
        uint256 amount1 = 1000e18;
        uint256 amount2 = 500e18;
        uint256 totalAmount = amount1 + amount2;
        
        vm.prank(address(bridge));
        token.mint(user1, totalAmount);
        
        vm.prank(user1);
        bridge.deposit(amount1);
        assertEq(bridge.nonces(user1), 1);
        
        vm.prank(user1);
        bridge.deposit(amount2);
        assertEq(bridge.nonces(user1), 2);
        
        assertEq(token.balanceOf(user1), 0);
        
        bytes32 depositId1 = keccak256(abi.encodePacked(
            user1, 
            amount1, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        bytes32 depositId2 = keccak256(abi.encodePacked(
            user1, 
            amount2, 
            uint256(1), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        vm.stopPrank();
        bridge.release(depositId1, user1, amount1, block.chainid);
        
        bridge.release(depositId2, user1, amount2, block.chainid);
        
        assertEq(token.balanceOf(user1), totalAmount);
    }

    function testBridgePauseDuringFlow() public {
        uint256 amount = 1000e18;
        
        vm.prank(address(bridge));
        token.mint(user1, amount);
        
        bridge.pause();
        assertTrue(bridge.paused());
        
        vm.prank(user1);
        vm.expectRevert("Bridge is paused");
        bridge.deposit(amount);
        
        bridge.unpause();
        assertFalse(bridge.paused());
        
        vm.prank(user1);
        bridge.deposit(amount);
        
        assertEq(token.balanceOf(user1), 0);
    }

    function testCrossChainScenario() public {
        uint256 amount = 1000e18;
        uint256 sourceChainId = 1;
        uint256 targetChainId = 137;
        
        vm.prank(address(bridge));
        token.mint(user1, amount);
        
        vm.prank(user1);
        bridge.deposit(amount);
        
        bytes32 depositId = keccak256(abi.encodePacked(
            user1, 
            amount, 
            uint256(0), 
            sourceChainId, 
            block.number,
            block.timestamp
        ));
        
        vm.stopPrank();
        bridge.release(depositId, user1, amount, targetChainId);
        
        assertEq(token.balanceOf(user1), amount);
        assertTrue(bridge.processed(depositId));
    }

    function testBridgeWithDifferentRecipients() public {
        uint256 amount = 1000e18;
        
        vm.prank(address(bridge));
        token.mint(user1, amount);
        
        vm.prank(user1);
        bridge.deposit(amount);
        
        bytes32 depositId = keccak256(abi.encodePacked(
            user1, 
            amount, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        vm.stopPrank();
        bridge.release(depositId, user2, amount, block.chainid);
        
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.balanceOf(user2), amount);
    }

    function testBridgeWithPartialAmounts() public {
        uint256 depositAmount = 1000e18;
        uint256 releaseAmount1 = 300e18;
        uint256 releaseAmount2 = 700e18;
        
        vm.prank(address(bridge));
        token.mint(user1, depositAmount);
        
        vm.prank(user1);
        bridge.deposit(depositAmount);
        
        bytes32 depositId1 = keccak256(abi.encodePacked(
            user1, 
            depositAmount, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        bytes32 depositId2 = keccak256(abi.encodePacked(
            user1, 
            depositAmount, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp + 1
        ));
        
        vm.stopPrank();
        bridge.release(depositId1, user1, releaseAmount1, block.chainid);
        
        bridge.release(depositId2, user1, releaseAmount2, block.chainid);
        
        assertEq(token.balanceOf(user1), releaseAmount1 + releaseAmount2);
    }

    function testBridgeStateConsistency() public {
        uint256 amount = 1000e18;
        
        assertEq(token.totalSupply(), 0);
        assertEq(bridge.nonces(user1), 0);
        
        vm.prank(address(bridge));
        token.mint(user1, amount);
        assertEq(token.totalSupply(), amount);
        
        vm.prank(user1);
        bridge.deposit(amount);
        assertEq(token.totalSupply(), 0);
        assertEq(bridge.nonces(user1), 1);
        
        bytes32 depositId = keccak256(abi.encodePacked(
            user1, 
            amount, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        vm.stopPrank();
        bridge.release(depositId, user1, amount, block.chainid);
        assertEq(token.totalSupply(), amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function testBridgeWithZeroAmounts() public {
        vm.prank(user1);
        vm.expectRevert("Amount small");
        bridge.deposit(0);
    }

    function testBridgeWithMaximumAmounts() public {
        uint256 maxAmount = bridge.MAX_DEPOSIT();
        
        vm.prank(address(bridge));
        token.mint(user1, maxAmount);
        
        vm.prank(user1);
        bridge.deposit(maxAmount);
        
        assertEq(token.balanceOf(user1), 0);
        
        bytes32 depositId = keccak256(abi.encodePacked(
            user1, 
            maxAmount, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        vm.stopPrank();
        bridge.release(depositId, user1, maxAmount, block.chainid);
        
        assertEq(token.balanceOf(user1), maxAmount);
    }

    function testBridgeEventConsistency() public {
        uint256 amount = 1000e18;
        
        vm.prank(address(bridge));
        token.mint(user1, amount);
        
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit Deposited(
            keccak256(abi.encodePacked(
                user1, 
                amount, 
                uint256(0), 
                block.chainid, 
                block.number,
                block.timestamp
            )),
            user1, 
            amount, 
            uint256(0), 
            block.chainid, 
            block.number
        );
        bridge.deposit(amount);
        
        bytes32 depositId = keccak256(abi.encodePacked(
            user1, 
            amount, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        vm.stopPrank();
        vm.expectEmit(true, true, false, true);
        emit Released(depositId, user1, amount, block.chainid);
        bridge.release(depositId, user1, amount, block.chainid);
    }
}
