// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {MilkiWay} from "../src/MilkiWay.sol";

contract MilkiWayTest is Test {
    MilkiWay public token;
    address public owner;
    address public user1;
    address public user2;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        vm.prank(owner);
        token = new MilkiWay(owner);
    }

    function testInitialState() public {
        assertEq(token.name(), "MilkiWay");
        assertEq(token.symbol(), "MWY");
        assertEq(token.decimals(), 18);
        assertEq(token.owner(), owner);
        assertEq(token.totalSupply(), 0);
    }

    function testMint() public {
        uint256 amount = 1000e18;
        
        vm.expectEmit(true, false, false, true);
        emit Minted(user1, amount);
        
        vm.prank(owner);
        token.mint(user1, amount);
        
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testMintMultiple() public {
        uint256 amount1 = 500e18;
        uint256 amount2 = 300e18;
        
        vm.startPrank(owner);
        token.mint(user1, amount1);
        token.mint(user2, amount2);
        vm.stopPrank();
        
        assertEq(token.balanceOf(user1), amount1);
        assertEq(token.balanceOf(user2), amount2);
        assertEq(token.totalSupply(), amount1 + amount2);
    }

    function testBurn() public {
        uint256 mintAmount = 1000e18;
        uint256 burnAmount = 300e18;
        
        vm.prank(owner);
        token.mint(user1, mintAmount);
        
        vm.expectEmit(true, false, false, true);
        emit Burned(user1, burnAmount);
        
        vm.prank(owner);
        token.burn(user1, burnAmount);
        
        assertEq(token.balanceOf(user1), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    function testBurnInsufficientBalance() public {
        uint256 mintAmount = 1000e18;
        uint256 burnAmount = 1500e18;
        
        vm.prank(owner);
        token.mint(user1, mintAmount);
        
        vm.prank(owner);
        vm.expectRevert();
        token.burn(user1, burnAmount);
        
        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(token.totalSupply(), mintAmount);
    }

    function testBurnZeroAmount() public {
        uint256 mintAmount = 1000e18;
        
        vm.prank(owner);
        token.mint(user1, mintAmount);
        
        vm.prank(owner);
        token.burn(user1, 0);
        
        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(token.totalSupply(), mintAmount);
    }

    function testTransfer() public {
        uint256 amount = 1000e18;
        uint256 transferAmount = 300e18;
        
        vm.prank(owner);
        token.mint(user1, amount);
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, transferAmount);
        
        vm.prank(user1);
        token.transfer(user2, transferAmount);
        
        assertEq(token.balanceOf(user1), amount - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
    }

    function testTransferInsufficientBalance() public {
        uint256 amount = 1000e18;
        uint256 transferAmount = 1500e18;
        
        vm.prank(owner);
        token.mint(user1, amount);
        
        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, transferAmount);
        
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.balanceOf(user2), 0);
    }

    function testApprove() public {
        uint256 amount = 1000e18;
        uint256 approveAmount = 500e18;
        
        vm.prank(owner);
        token.mint(user1, amount);
        
        vm.prank(user1);
        token.approve(user2, approveAmount);
        
        assertEq(token.allowance(user1, user2), approveAmount);
    }

    function testTransferFrom() public {
        uint256 amount = 1000e18;
        uint256 approveAmount = 500e18;
        uint256 transferAmount = 300e18;
        
        vm.prank(owner);
        token.mint(user1, amount);
        
        vm.prank(user1);
        token.approve(user2, approveAmount);
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, transferAmount);
        
        vm.prank(user2);
        token.transferFrom(user1, user2, transferAmount);
        
        assertEq(token.balanceOf(user1), amount - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
        assertEq(token.allowance(user1, user2), approveAmount - transferAmount);
    }

    function testTransferFromInsufficientAllowance() public {
        uint256 amount = 1000e18;
        uint256 approveAmount = 200e18;
        uint256 transferAmount = 300e18;
        
        vm.prank(owner);
        token.mint(user1, amount);
        
        vm.prank(user1);
        token.approve(user2, approveAmount);
        
        vm.prank(user2);
        vm.expectRevert();
        token.transferFrom(user1, user2, transferAmount);
        
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.balanceOf(user2), 0);
        assertEq(token.allowance(user1, user2), approveAmount);
    }

    function testBurnableBurn() public {
        uint256 amount = 1000e18;
        uint256 burnAmount = 300e18;
        
        vm.prank(owner);
        token.mint(user1, amount);
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, address(0), burnAmount);
        
        vm.prank(user1);
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(user1), amount - burnAmount);
        assertEq(token.totalSupply(), amount - burnAmount);
    }

    function testBurnableBurnInsufficientBalance() public {
        uint256 amount = 1000e18;
        uint256 burnAmount = 1500e18;
        
        vm.prank(owner);
        token.mint(user1, amount);
        
        vm.prank(user1);
        vm.expectRevert();
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testFuzzMint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount <= type(uint128).max); 
        
        vm.prank(owner);
        token.mint(to, amount);
        
        assertEq(token.balanceOf(to), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testFuzzBurn(address from, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(from != address(0));
        vm.assume(mintAmount >= burnAmount);
        vm.assume(mintAmount <= type(uint128).max);
        vm.assume(burnAmount > 0);
        
        vm.prank(owner);
        token.mint(from, mintAmount);
        
        vm.prank(owner);
        token.burn(from, burnAmount);
        
        assertEq(token.balanceOf(from), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }
}
