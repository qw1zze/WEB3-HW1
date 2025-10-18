// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {MilkiWay} from "../src/MilkiWay.sol";

contract MilkiWayTest is Test {
    MilkiWay public milkiWay;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        vm.prank(owner);
        milkiWay = new MilkiWay(owner);
    }

    function testMint() public {
        uint256 amount = 1000 * 10**18;
        
        vm.prank(owner);
        milkiWay.mint(user1, amount);
        
        assertEq(milkiWay.balanceOf(user1), amount);
        assertEq(milkiWay.totalSupply(), amount);
    }

    function testMintOnlyOwner() public {
        uint256 amount = 1000 * 10**18;
        
        vm.prank(user1);
        vm.expectRevert();
        milkiWay.mint(user2, amount);
    }

    function testBurn() public {
        uint256 mintAmount = 1000 * 10**18;
        uint256 burnAmount = 300 * 10**18;
        
        vm.prank(owner);
        milkiWay.mint(owner, mintAmount);
        
        assertEq(milkiWay.balanceOf(owner), mintAmount);
        assertEq(milkiWay.totalSupply(), mintAmount);
        
        vm.prank(owner);
        milkiWay.burn(burnAmount);
        
        assertEq(milkiWay.balanceOf(owner), mintAmount - burnAmount);
        assertEq(milkiWay.totalSupply(), mintAmount - burnAmount);
    }

    function testBurnOnlyOwner() public {
        uint256 amount = 1000 * 10**18;
        
        vm.prank(owner);
        milkiWay.mint(user1, amount);
        
        vm.prank(user1);
        vm.expectRevert();
        milkiWay.burn(100 * 10**18);
    }

    function testBurnFrom() public {
        uint256 mintAmount = 1000 * 10**18;
        uint256 burnAmount = 300 * 10**18;
        
        vm.prank(owner);
        milkiWay.mint(user1, mintAmount);
        
        vm.prank(user1);
        milkiWay.approve(owner, burnAmount);
        
        vm.prank(owner);
        milkiWay.burnFrom(user1, burnAmount);
        
        assertEq(milkiWay.balanceOf(user1), mintAmount - burnAmount);
        assertEq(milkiWay.totalSupply(), mintAmount - burnAmount);
    }

    function testBurnFromOnlyOwner() public {
        uint256 amount = 1000 * 10**18;
        
        vm.prank(owner);
        milkiWay.mint(user1, amount);
        
        vm.prank(user2);
        vm.expectRevert();
        milkiWay.burnFrom(user1, 100 * 10**18);
    }
}
