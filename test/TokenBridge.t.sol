// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {TokenBridge} from "../src/TokenBridge.sol";
import {MilkiWay} from "../src/MilkiWay.sol";

contract TokenBridgeTest is Test {
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

    event BridgePaused(bool paused);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        token = new MilkiWay(owner);
        bridge = new TokenBridge(address(token));
        vm.prank(owner);
        token.transferOwnership(address(bridge));
    }

    function testInitialState() public {
        assertEq(address(bridge.token()), address(token));
        assertEq(bridge.owner(), address(this));
        assertEq(bridge.paused(), false);
        assertEq(bridge.MIN_DEPOSIT(), 1e18);
        assertEq(bridge.MAX_DEPOSIT(), 1000000e18);
    }

    function testSetToken() public {
        address newToken = makeAddr("newToken");
        
        bridge.setToken(newToken);
        
        assertEq(address(bridge.token()), newToken);
    }

    function testSetTokenOnlyOwner() public {
        address newToken = makeAddr("newToken");
        
        vm.prank(user1);
        vm.expectRevert();
        bridge.setToken(newToken);
    }

    function testSetTokenInvalidAddress() public {
        vm.expectRevert("Invalid address");
        bridge.setToken(address(0));
    }

    function testDeposit() public {
        uint256 amount = 100e18;
        
        vm.prank(address(bridge));
        token.mint(user1, amount);
        
        assertEq(token.balanceOf(user1), amount);
        
        vm.prank(user1);
        bridge.deposit(amount);
        
        assertEq(token.balanceOf(user1), 0);
        (bridge.nonces(user1), 1);
    }

    function testDepositEmitEvent() public {
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
    }

    function testDepositInsufficientBalance() public {
        uint256 amount = 1000e18;
        
        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        bridge.deposit(amount);
    }

    function testDepositAmountTooSmall() public {
        uint256 amount = 0.5e18;
        
        vm.prank(address(bridge));
        token.mint(user1, amount);
        
        vm.prank(user1);
        vm.expectRevert("Amount small");
        bridge.deposit(amount);
    }

    function testDepositAmountTooLarge() public {
        uint256 amount = 2000000e18; 
        
        vm.prank(address(bridge));
        token.mint(user1, amount);
        
        vm.prank(user1);
        vm.expectRevert("Amount large");
        bridge.deposit(amount);
    }

    function testDepositWhenPaused() public {
        uint256 amount = 1000e18;
        
        vm.prank(address(bridge));
        token.mint(user1, amount);
        
        bridge.pause();
        
        vm.prank(user1);
        vm.expectRevert("Bridge is paused");
        bridge.deposit(amount);
    }

    function testDepositMultipleTimes() public {
        uint256 amount1 = 1000e18;
        uint256 amount2 = 500e18;
        
        vm.prank(address(bridge));
        token.mint(user1, amount1 + amount2);
        
        vm.prank(user1);
        bridge.deposit(amount1);
        
        vm.prank(user1);
        bridge.deposit(amount2);
        
        assertEq(token.balanceOf(user1), 0);
        assertEq(bridge.nonces(user1), 2);
    }

    function testRelease() public {
        uint256 amount = 1000e18;
        
        bytes32 id = keccak256(abi.encodePacked(
            user1, 
            amount, 
                uint256(0),
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        vm.expectEmit(true, true, false, true);
        emit Released(id, user1, amount, block.chainid);
        
        bridge.release(id, user1, amount, block.chainid);
        
        assertEq(token.balanceOf(user1), amount);
        assertTrue(bridge.processed(id));
    }

    function testReleaseOnlyOwner() public {
        uint256 amount = 1000e18;
        bytes32 id = keccak256(abi.encodePacked(
            user1, 
            amount, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        vm.prank(user1);
        vm.expectRevert();
        bridge.release(id, user1, amount, block.chainid);
        
        assertEq(token.balanceOf(user1), 0);
        assertFalse(bridge.processed(id));
    }

    function testReleaseInvalidAddress() public {
        uint256 amount = 1000e18;
        bytes32 id = keccak256(abi.encodePacked(
            user1, 
            amount, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        vm.expectRevert("Invalid address");
        bridge.release(id, address(0), amount, block.chainid);
    }

    function testReleaseAlreadyProcessed() public {
        uint256 amount = 1000e18;
        bytes32 id = keccak256(abi.encodePacked(
            user1, 
            amount, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        bridge.release(id, user1, amount, block.chainid);
        
        vm.expectRevert("In process");
        bridge.release(id, user1, amount, block.chainid);
    }

    function testReleaseZeroAmount() public {
        bytes32 id = keccak256(abi.encodePacked(
            user1, 
            uint256(0), 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        vm.expectRevert("Wrong amount");
        bridge.release(id, user1, 0, block.chainid);
    }

    function testReleaseWhenPaused() public {
        uint256 amount = 1000e18;
        bytes32 id = keccak256(abi.encodePacked(
            user1, 
            amount, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        bridge.pause();
        
        vm.expectRevert("Bridge is paused");
        bridge.release(id, user1, amount, block.chainid);
    }

    function testPause() public {
        vm.expectEmit(false, false, false, true);
        emit BridgePaused(true);
        
        bridge.pause();
        
        assertTrue(bridge.paused());
    }

    function testPauseOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        bridge.pause();
        
        assertFalse(bridge.paused());
    }

    function testUnpause() public {
        bridge.pause();
        
        vm.expectEmit(false, false, false, true);
        emit BridgePaused(false);
        
        bridge.unpause();
        
        assertFalse(bridge.paused());
    }

    function testUnpauseOnlyOwner() public {
        bridge.pause();
        
        vm.prank(user1);
        vm.expectRevert();
        bridge.unpause();
        
        assertTrue(bridge.paused());
    }

    function testGetDepositId() public {
        address user = user1;
        uint256 amount = 1000e18;
        uint256 nonce = 0;
        uint256 chainId = 1;
        uint256 blockNumber = 12345;
        uint256 timestamp = 1234567890;
        
        bytes32 expectedId = keccak256(abi.encodePacked(
            user, amount, nonce, chainId, blockNumber, timestamp
        ));
        
        bytes32 actualId = bridge.getDepositId(
            user, amount, nonce, chainId, blockNumber, timestamp
        );
        
        assertEq(actualId, expectedId);
    }

    function testFuzzDeposit(uint256 amount) public {
        vm.assume(amount >= bridge.MIN_DEPOSIT());
        vm.assume(amount <= bridge.MAX_DEPOSIT());
        
        vm.prank(address(bridge));
        token.mint(user1, amount);
        
        vm.prank(user1);
        bridge.deposit(amount);
        
        assertEq(token.balanceOf(user1), 0);
        assertEq(bridge.nonces(user1), 1);
    }

    function testFuzzRelease(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0);
        vm.assume(amount <= type(uint128).max);
        
        bytes32 id = keccak256(abi.encodePacked(
            user1, 
            amount, 
            uint256(0), 
            block.chainid, 
            block.number,
            block.timestamp
        ));
        
        bridge.release(id, to, amount, block.chainid);
        
        assertEq(token.balanceOf(to), amount);
        assertTrue(bridge.processed(id));
    }
}
