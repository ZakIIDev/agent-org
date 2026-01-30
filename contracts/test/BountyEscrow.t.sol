// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {BountyEscrow} from "../src/BountyEscrow.sol";

contract MockERC20 {
    string public name = "Mock";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external { balanceOf[to] += amt; }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        require(balanceOf[msg.sender] >= amt, "bal");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        require(a >= amt, "allow");
        allowance[from][msg.sender] = a - amt;
        require(balanceOf[from] >= amt, "bal");
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

contract BountyEscrowTest is Test {
    BountyEscrow esc;
    address owner = address(0xA11CE);
    address solver = address(0xBEEF);

    function setUp() public {
        vm.deal(owner, 100 ether);
        vm.prank(owner);
        esc = new BountyEscrow();
    }

    function test_ethFlow_claim_submit_pay() public {
        bytes32 meta = keccak256("meta");
        vm.prank(owner);
        uint256 id = esc.createEthBounty{value: 1 ether}(meta, 0);

        vm.prank(solver);
        esc.claim(id);

        vm.prank(solver);
        esc.submit(id, keccak256("work"), "https://example.com/proof");

        uint256 beforeBal = solver.balance;
        vm.prank(owner);
        esc.acceptAndPay(id);
        assertEq(solver.balance, beforeBal + 1 ether);
    }

    function test_ownerCanCancelAndRefund() public {
        bytes32 meta = keccak256("meta");
        uint256 beforeBal = owner.balance;
        vm.prank(owner);
        uint256 id = esc.createEthBounty{value: 2 ether}(meta, 0);
        vm.prank(owner);
        esc.cancel(id);
        assertEq(owner.balance, beforeBal);
    }

    function test_erc20Flow() public {
        MockERC20 t = new MockERC20();
        t.mint(owner, 100e18);
        vm.startPrank(owner);
        t.approve(address(esc), 10e18);
        uint256 id = esc.createErc20Bounty(address(t), 10e18, keccak256("m"), 0);
        vm.stopPrank();

        vm.prank(solver);
        esc.claim(id);
        vm.prank(solver);
        esc.submit(id, keccak256("w"), "ipfs://proof");

        uint256 beforeBal = t.balanceOf(solver);
        vm.prank(owner);
        esc.acceptAndPay(id);
        assertEq(t.balanceOf(solver), beforeBal + 10e18);
    }
}
