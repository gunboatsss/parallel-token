// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {ParallelToken} from "src/ParallelToken.sol";
import {IParallelToken} from "src/interfaces/IParallelToken.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

contract TokenA is ERC20 {
    constructor(address a) {
        _mint(a, 1_000_000e18);
    }

    function name() public pure override returns (string memory) {
        return "Token A";
    }

    function symbol() public pure override returns (string memory) {
        return "A";
    }
}

contract TokenB is ERC20 {
    constructor(address a) {
        _mint(a, 1_000_000e18);
    }

    function name() public pure override returns (string memory) {
        return "Token B";
    }

    function symbol() public pure override returns (string memory) {
        return "B";
    }
}

contract ParallelTokenTest is Test {
    TokenA tokenA;
    TokenB tokenB;
    ParallelToken pt;
    address adam = makeAddr("adam");
    address bob = makeAddr("bob");

    function setUp() public {
        tokenA = new TokenA(adam);
        tokenB = new TokenB(adam);
        pt = new ParallelToken();
    }

    function test_mint() public {
        vm.startPrank(adam);

        uint256 balanceBefore = tokenA.balanceOf(address(pt));
        uint256 nonceBefore = pt.nonces(adam);
        tokenA.approve(address(pt), 1e18);

        uint256 id = pt.mint(address(tokenA), 1e18);

        (address underlying, address owner, uint256 amount) = pt.idToTokenData(id);
        assertEq(tokenA.balanceOf(address(pt)) - balanceBefore, 1e18);
        assertEq(owner, adam);
        assertEq(amount, 1e18);
        assertEq(underlying, address(tokenA));
        assertEq(pt.nonces(adam), nonceBefore + 1);

        vm.stopPrank();
    }

    function test_mintMany() public {
        vm.startPrank(adam);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1e18;
        amounts[1] = 2e18;
        amounts[2] = 3e18;
        uint256 balanceBefore = tokenA.balanceOf(address(pt));
        uint256 nonceBefore = pt.nonces(adam);
        tokenA.approve(address(pt), 6e18);

        uint256[] memory ids = pt.mintMany(address(tokenA), amounts);

        assertEq(tokenA.balanceOf(address(pt)) - balanceBefore, 6e18);
        assertEq(pt.nonces(adam), nonceBefore + 4);
        for (uint256 i; i < ids.length; i++) {
            (address underlying, address owner, uint256 amount) = pt.idToTokenData(ids[i]);
            assertEq(owner, adam);
            assertEq(amount, amounts[i]);
            assertEq(underlying, address(tokenA));
        }
        vm.stopPrank();
    }

    function test_burn() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);

        uint256 balanceBefore = tokenA.balanceOf(adam);
        pt.burn(id);

        (address underlying, address owner, uint256 amount) = pt.idToTokenData(id);
        assertEq(tokenA.balanceOf(adam) - balanceBefore, 1e18);
        assertEq(underlying, address(0));
        assertEq(owner, address(0));
        assertEq(amount, 0);
        vm.stopPrank();
    }

    function test_burnMany() public {
        vm.startPrank(adam);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1e18;
        amounts[1] = 2e18;
        amounts[2] = 3e18;
        tokenA.approve(address(pt), 6e18);
        uint256[] memory ids = pt.mintMany(address(tokenA), amounts);

        uint256 balanceBefore = tokenA.balanceOf(adam);
        pt.burnMany(ids);

        assertEq(tokenA.balanceOf(adam) - balanceBefore, 6e18);
        for (uint256 i; i < ids.length; i++) {
            (address underlying, address owner, uint256 amount) = pt.idToTokenData(ids[i]);
            assertEq(underlying, address(0));
            assertEq(owner, address(0));
            assertEq(amount, 0);
        }
        vm.stopPrank();
    }

    function test_burnMany_reverts_different_underlying() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        tokenB.approve(address(pt), 1e18);
        uint256 idA = pt.mint(address(tokenA), 1e18);
        uint256 idB = pt.mint(address(tokenB), 1e18);
        uint256[] memory ids = new uint256[](2);
        ids[0] = idA;
        ids[1] = idB;
        vm.expectRevert();
        pt.burnMany(ids);
        vm.stopPrank();
    }

    function test_push() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);

        bool success = pt.push(id, bob);

        assertTrue(success);
        (, address owner,) = pt.idToTokenData(id);
        assertEq(owner, bob);
        vm.stopPrank();
    }

    function test_pushMany() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 3e18);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e18;
        amounts[1] = 2e18;
        uint256[] memory ids = pt.mintMany(address(tokenA), amounts);

        address[] memory tos = new address[](2);
        tos[0] = bob;
        tos[1] = adam;
        pt.pushMany(ids, tos);

        (, address owner0,) = pt.idToTokenData(ids[0]);
        (, address owner1,) = pt.idToTokenData(ids[1]);
        assertEq(owner0, bob);
        assertEq(owner1, adam);
        vm.stopPrank();
    }

    function test_push_reverts_zero_address() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);
        vm.expectRevert();
        pt.push(id, address(0));
        vm.stopPrank();
    }

    function test_push_reverts_not_owner() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);
        vm.stopPrank();
        vm.startPrank(bob);
        vm.expectRevert();
        pt.push(id, bob);
        vm.stopPrank();
    }

    function test_pushMany_reverts_length_mismatch() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 2e18);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        uint256[] memory ids = pt.mintMany(address(tokenA), amounts);

        address[] memory tos = new address[](1);
        tos[0] = bob;
        vm.expectRevert();
        pt.pushMany(ids, tos);
        vm.stopPrank();
    }

    function test_push_with_memo() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);
        vm.expectEmit(address(pt));
        emit IParallelToken.Transfer(adam, adam, bob, id, "hello memo");
        pt.push(id, bob, "hello memo");
        (, address owner,) = pt.idToTokenData(id);
        assertEq(owner, bob);
        vm.stopPrank();
    }

    function test_pushMany_with_memos() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 3e18);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e18;
        amounts[1] = 2e18;
        uint256[] memory ids = pt.mintMany(address(tokenA), amounts);

        address[] memory tos = new address[](2);
        tos[0] = bob;
        tos[1] = adam;

        bytes[] memory memos = new bytes[](2);
        memos[0] = "memo for bob";
        memos[1] = "memo for adam";

        vm.expectEmit(address(pt));
        emit IParallelToken.Transfer(adam, adam, bob, ids[0], "memo for bob");
        pt.pushMany(ids, tos, memos);

        (, address owner0,) = pt.idToTokenData(ids[0]);
        (, address owner1,) = pt.idToTokenData(ids[1]);
        assertEq(owner0, bob);
        assertEq(owner1, adam);
        vm.stopPrank();
    }

    function test_pull() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);

        pt.pull(id, bob, "");

        (, address owner,) = pt.idToTokenData(id);
        assertEq(owner, bob);
        vm.stopPrank();
    }

    function test_pull_operator() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);
        pt.setOperator(bob, true);
        vm.stopPrank();

        vm.startPrank(bob);
        pt.pull(id, bob, "");

        (, address owner,) = pt.idToTokenData(id);
        assertEq(owner, bob);
        vm.stopPrank();
    }

    function test_pull_allowance() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);
        pt.setApproval(bob, id, true);
        vm.stopPrank();

        vm.startPrank(bob);
        pt.pull(id, bob, "");

        (, address owner,) = pt.idToTokenData(id);
        assertEq(owner, bob);
        vm.stopPrank();
    }

    function test_pull_reverts_zero_address() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert();
        pt.pull(id, address(0), "");
        vm.stopPrank();
    }

    function test_pull_reverts_not_authorized() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert();
        pt.pull(id, bob, "");
        vm.stopPrank();
    }

    function test_pullMany() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 2e18);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        uint256[] memory ids = pt.mintMany(address(tokenA), amounts);

        address[] memory tos = new address[](2);
        tos[0] = bob;
        tos[1] = bob;

        bytes[] memory memos = new bytes[](2);
        memos[0] = "abc";
        memos[1] = "def";
        pt.pullMany(ids, tos, memos);

        (, address owner0,) = pt.idToTokenData(ids[0]);
        (, address owner1,) = pt.idToTokenData(ids[1]);
        assertEq(owner0, bob);
        assertEq(owner1, bob);
        vm.stopPrank();
    }

    function test_merge() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 4e18);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        amounts[2] = 2e18;
        uint256[] memory ids = pt.mintMany(address(tokenA), amounts);

        uint256 toId = ids[2];
        uint256[] memory mergeIds = new uint256[](2);
        mergeIds[0] = ids[0];
        mergeIds[1] = ids[1];

        (,, uint256 amountBefore) = pt.idToTokenData(toId);
        pt.merge(mergeIds, toId);

        (,, uint256 amountAfter) = pt.idToTokenData(toId);
        assertEq(amountAfter, amountBefore + 2e18);
        (, address owner0,) = pt.idToTokenData(ids[0]);
        assertEq(owner0, address(0));
        vm.stopPrank();
    }

    function test_merge_reverts_not_owner() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 2e18);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        uint256[] memory ids = pt.mintMany(address(tokenA), amounts);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert();
        pt.merge(ids, ids[1]);
        vm.stopPrank();
    }

    function test_split() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);

        uint256[] memory splitAmounts = new uint256[](2);
        splitAmounts[0] = 4e17;
        splitAmounts[1] = 6e17;
        uint256[] memory newIds = pt.split(id, splitAmounts);

        (, address owner0,) = pt.idToTokenData(newIds[0]);
        (, address owner1,) = pt.idToTokenData(newIds[1]);
        (,, uint256 amount0) = pt.idToTokenData(newIds[0]);
        (,, uint256 amount1) = pt.idToTokenData(newIds[1]);
        assertEq(owner0, adam);
        assertEq(owner1, adam);
        assertEq(amount0, 4e17);
        assertEq(amount1, 6e17);
        vm.stopPrank();
    }

    function test_split_reverts_amount_mismatch() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);

        uint256[] memory splitAmounts = new uint256[](2);
        splitAmounts[0] = 3e17;
        splitAmounts[1] = 3e17;
        vm.expectRevert();
        pt.split(id, splitAmounts);
        vm.stopPrank();
    }

    function test_setApproval() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);

        bool success = pt.setApproval(bob, id, true);

        assertTrue(success);
        assertTrue(pt.allowance(adam, bob, id));
        vm.stopPrank();
    }

    function test_setApproval_revokes() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);
        pt.setApproval(bob, id, true);
        pt.setApproval(bob, id, false);

        assertTrue(!pt.allowance(adam, bob, id));
        vm.stopPrank();
    }

    function test_setOperator() public {
        vm.startPrank(adam);

        bool success = pt.setOperator(bob, true);

        assertTrue(success);
        assertTrue(pt.isOperator(adam, bob));
        vm.stopPrank();
    }

    function test_setOperator_revokes() public {
        vm.startPrank(adam);
        pt.setOperator(bob, true);
        pt.setOperator(bob, false);

        assertTrue(!pt.isOperator(adam, bob));
        vm.stopPrank();
    }

    function test_mint_reverts_zero_address() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        vm.expectRevert(IParallelToken.ZeroAddress.selector);
        pt.mint(address(0), 1e18);
        vm.stopPrank();
    }

    function test_mint_reverts_zero_amount() public {
        vm.startPrank(adam);
        vm.expectRevert(IParallelToken.ZeroAmount.selector);
        pt.mint(address(tokenA), 0);
        vm.stopPrank();
    }

    function test_merge_reverts_invalid_merge() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 2e18);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e18;
        amounts[1] = 1e18;
        uint256[] memory ids = pt.mintMany(address(tokenA), amounts);
        vm.expectRevert(IParallelToken.InvalidMerge.selector);
        uint256[] memory mergeIds = new uint256[](1);
        mergeIds[0] = ids[0];
        pt.merge(mergeIds, ids[0]);
        vm.stopPrank();
    }

    function test_merge_reverts_mixed_underlying() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        tokenB.approve(address(pt), 1e18);
        uint256 idA = pt.mint(address(tokenA), 1e18);
        uint256 idB = pt.mint(address(tokenB), 1e18);
        vm.expectRevert();
        uint256[] memory mergeIds = new uint256[](1);
        mergeIds[0] = idA;
        pt.merge(mergeIds, idB);
        vm.stopPrank();
    }

    function test_merge_reverts_zero_length() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);
        uint256[] memory mergeIds = new uint256[](0);
        vm.expectRevert(IParallelToken.ZeroLength.selector);
        pt.merge(mergeIds, id);
        vm.stopPrank();
    }

    function test_split_reverts_zero_length() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);
        uint256[] memory splitAmounts = new uint256[](0);
        vm.expectRevert(IParallelToken.ZeroLength.selector);
        pt.split(id, splitAmounts);
        vm.stopPrank();
    }

    function test_split_reverts_zero_amount_in_array() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);
        uint256[] memory splitAmounts = new uint256[](2);
        splitAmounts[0] = 5e17;
        splitAmounts[1] = 0;
        vm.expectRevert();
        pt.split(id, splitAmounts);
        vm.stopPrank();
    }

    function test_split_reverts_not_owner() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256[] memory splitAmounts = new uint256[](2);
        splitAmounts[0] = 4e17;
        splitAmounts[1] = 6e17;
        vm.expectRevert();
        pt.split(id, splitAmounts);
        vm.stopPrank();
    }
}
