// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/contracts/Vault.sol";
import "../src/router/ProtocolRegistry.sol";
import "../src/router/YieldRouter.sol";
import "../src/adaptor/MockAdaptor.sol";

/// @dev Simple ERC20 for testing
contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Test helper that exposes internal _hashMove for signing
contract TestYieldRouter is YieldRouter {
    constructor(ProtocolRegistry registry_, Vault vault_) YieldRouter(registry_, vault_) {}

    function hashMovePublic(
        address signer,
        address fromAdaptor,
        address toAdaptor,
        uint256 amount,
        uint256 deadline,
        uint256 nonce
    ) external view override returns (bytes32) {
        // returns the EIP-712 digest to sign
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    MOVE_TYPEHASH,
                    signer,
                    fromAdaptor,
                    toAdaptor,
                    amount,
                    deadline,
                    nonce
                )
            )
        );
    }
}

contract AdaptorFlowTest is Test {
    TestToken token;
    Vault vault;
    ProtocolRegistry registry;
    TestYieldRouter router;
    MockAdaptor adaptorA;
    MockAdaptor adaptorB;

    address user = address(0xBEEF);
    uint256 userKey; // private key for signing EOA-like actions (if needed)
    address agent;   // simulated TEE agent public address
    uint256 agentKey; // agent private key used to sign Move

    function setUp() public {
        // setup keys
        (user, userKey) = makeAddrAndKey("user"); // convenience helper doesn't exist; use a fixed pk
        // Using fixed private keys instead
        userKey = 0xA11CE;
        vm.deal(user, 10 ether);

        // agent key (private key)
        agentKey = 0xBEEFCAFE;
        agent = vm.addr(agentKey);

        // Deploy token
        token = new TestToken("Test USDC", "tUSDC");
        // mint to user
        token.mint(user, 1_000_000e6);

        // Deploy Vault
        vault = new Vault(IERC20(address(token)), "AI Vault", "AIV");

        // Deploy registry
        registry = new ProtocolRegistry();

        // Deploy adaptors
        adaptorA = new MockAdaptor(address(token), "MockA");
        adaptorB = new MockAdaptor(address(token), "MockB");

        // Add adaptors
        registry.addAdaptor(address(adaptorA));
        registry.addAdaptor(address(adaptorB));

        // Deploy test router
        router = new TestYieldRouter(registry, vault);

        // Make router the vault's router
        vault.transferOwnership(address(this)); // test contract becomes owner of vault
        vault.setRouter(address(router));
        vault.transferOwnership(address(this)); // keep ownership for testing

        // Set router relayer to this test contract
        router.transferOwnership(address(this));
        router.setRelayer(address(this));

        // fund the user's wallet in test env by giving user tokens (already minted)
        // Approve & deposit: simulate user depositing into vault
        vm.prank(user);
        token.approve(address(vault), 500_000e6);
        vm.prank(user);
        vault.deposit(500_000e6, user);

        // For convenience: now vault has some liquid balance
        assertEq(token.balanceOf(address(vault)), 500_000e6);
    }

    function test_fullMoveFlow() public {
        uint256 amount = 100_000e6;
        vm.prank(user);
        // 1) transfer amount from vault -> fromAdaptor (simulating router sending funds)
        // But normally router.transferTo is used - the router is authorized; test contract is owner and relayer.
        token.transfer(address(adaptorA), amount);

        // 2) adaptorA depositsFrom(vault) - since tokens were transferred to adaptor already,
        //    calling depositFrom will pull from vault (but the token is already in adaptor).
        // For our MockAdaptor, depositFrom pulls from the sender, so to simulate either:
        // We'll instead rely on the tokens already being in adaptorA, so no need to call depositFrom.
        // However to follow the flow, call depositFrom with sender = address(this) after approving adaptor
        // But vault.transferTo already put tokens in adaptor; skip depositFrom.

        assertEq(token.balanceOf(address(adaptorA)), amount);

        // 3) Build EIP-712 digest using router helper and sign with agentKey
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = router.nonces(agent); // should be 0
        bytes32 digest = router.hashMovePublic(agent, address(adaptorA), address(adaptorB), amount, deadline, nonce);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(agentKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        // 4) Call executeMove as relayer (test contract)
        router.executeMove(agent, address(adaptorA), address(adaptorB), amount, deadline, nonce, sig, 0);

        // After executeMove:
        // adaptorA.withdrawTo(router) should have transferred tokens from adaptorA -> router
        // router then approved adaptorB and called adaptorB.depositFrom(router, amount), which pulled tokens into adaptorB
        // So final expected: adaptorB.balance >= amount
        assertEq(token.balanceOf(address(adaptorB)), amount);

        // And router emitted MoveExecuted and consumed nonce
        assertEq(router.nonces(agent), nonce + 1);

        vm.stopPrank();
    }
}
