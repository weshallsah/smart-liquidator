// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {Vault} from "../src/contracts/Vault.sol";
import {YieldRouter} from "../src/router/YieldRouter.sol";
import {ProtocolRegistry} from "../src/router/ProtocolRegistry.sol";
import {MockAdaptor} from "../src/adaptor/MockAdaptor.sol";

/// Simple ERC20 for testing
contract TestToken is IERC20 {
    string public name = "TestToken";
    string public symbol = "TST";
    uint8 public decimals = 6;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    function totalSupply() external pure override returns (uint256) {
        return 0; // irrelevant for test
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
}

    contract FullSystemTest is Test {
        TestToken token;
        Vault vault;
        ProtocolRegistry registry;
        YieldRouter router;

        MockAdaptor adaptorA;
        MockAdaptor adaptorB;

        address user;
        uint256 agentKey;
        address agent; // simulated TEE signer

        function setUp() public {
            // users
            user = makeAddr("user");

            // TEE private key
            agentKey = 0xBEEFCAFE;
            agent = vm.addr(agentKey);

            // token
            token = new TestToken();
            token.mint(user, 1_000_000e6);

            // vault
            vault = new Vault(IERC20(address(token)), "AI Vault", "AIV");

            // registry
            registry = new ProtocolRegistry();

            // adaptors
            adaptorA = new MockAdaptor(address(token), "A");
            adaptorB = new MockAdaptor(address(token), "B");

            registry.addAdaptor(address(adaptorA));
            registry.addAdaptor(address(adaptorB));

            // router
            router = new YieldRouter(registry, vault);

            // wire vault
            vault.transferOwnership(address(this));
            vault.setRouter(address(router));
            vault.transferOwnership(address(this));

            // router admin
            router.transferOwnership(address(this));
            router.setRelayer(address(this));

            // deposit into vault
            vm.prank(user);
            token.approve(address(vault), 200_000e6);

            vm.prank(user);
            vault.deposit(200_000e6, user);

            assertEq(token.balanceOf(address(vault)), 200_000e6);
        }

        function test_endToEndFullSystem() public {
            uint256 amount = 50_000e6;

            // router initiates movement: vault → adaptorA
            // vm.prank(address(this));
            // vault.transferTo(address(adaptorA), amount);
            vm.prank(address(router));
            vault.transferTo(address(adaptorA), amount);

            assertEq(token.balanceOf(address(adaptorA)), amount);

            // TEE signs MOVE
            uint256 deadline = block.timestamp + 1 hours;
            uint256 nonce = router.nonces(agent);

            bytes32 digest = router.hashMovePublic(agent, address(adaptorA), address(adaptorB), amount, deadline, nonce);

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(agentKey, digest);
            bytes memory sig = abi.encodePacked(r, s, v);

            // Execute move
            router.executeMove(
                agent,
                address(adaptorA),
                address(adaptorB),
                amount,
                deadline,
                nonce,
                sig,
                0 // no fee
            );

            // Check funds moved A → B
            assertEq(token.balanceOf(address(adaptorA)), 0);
            assertEq(token.balanceOf(address(adaptorB)), amount);

            // Bring funds back from adaptorB → vault via router
            router.redeem(address(adaptorB), amount);

            assertEq(token.balanceOf(address(vault)), 200_000e6); // back to full

            // User withdraws
            vm.prank(user);
            vault.withdraw(200_000e6, user, user);

            assertEq(token.balanceOf(user), 1_000_000e6);
            assertEq(vault.totalAssets(), 0);
        }
    }

