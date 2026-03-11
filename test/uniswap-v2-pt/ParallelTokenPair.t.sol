// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {ParallelToken} from "src/ParallelToken.sol";
import {ParallelTokenFactory} from "src/uniswap-v2-pt/ParallelTokenFactory.sol";
import {ParallelTokenPair} from "src/uniswap-v2-pt/ParallelTokenPair.sol";

contract MockToken is ERC20 {
    function name() public pure override returns (string memory) {
        return "Mock Token";
    }

    function symbol() public pure override returns (string memory) {
        return "MOCK";
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ParallelTokenPairTest is Test {
    MockToken public token0;
    MockToken public token1;
    ParallelToken public pt;
    ParallelTokenFactory public factory;
    ParallelTokenPair public pair;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 constant INITIAL_MINT = 1000e18;
    uint256 constant MINIMUM_LIQUIDITY = 1000;

    function setUp() public {
        token0 = new MockToken();
        token1 = new MockToken();
        pt = new ParallelToken();
        factory = new ParallelTokenFactory(address(this), address(pt));
        pair = ParallelTokenPair(factory.createPair(address(token0), address(token1)));

        token0.mint(alice, INITIAL_MINT);
        token1.mint(alice, INITIAL_MINT);
        token0.mint(bob, INITIAL_MINT);
        token1.mint(bob, INITIAL_MINT);

        vm.startPrank(alice);
        token0.approve(address(pt), type(uint256).max);
        token1.approve(address(pt), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        token0.approve(address(pt), type(uint256).max);
        token1.approve(address(pt), type(uint256).max);
        vm.stopPrank();
    }

    function test_factory_createPair_tokenOrder() public view {
        address pairAddress = factory.getPair(address(token0), address(token1));
        assertEq(pairAddress, address(pair));
    }

    function test_factory_createPair_getPair() public view {
        address pairAddress = factory.getPair(address(token0), address(token1));
        assertEq(pairAddress, address(pair));
        pairAddress = factory.getPair(address(token1), address(token0));
        assertEq(pairAddress, address(pair));
    }

    function test_factory_createPair_allPairs() public view {
        assertEq(factory.allPairsLength(), 1);
        assertEq(factory.allPairs(0), address(pair));
    }

    function test_factory_createPair_identicalAddresses() public {
        vm.expectRevert("ParallelTokenFactory: IDENTICAL_ADDRESSES");
        factory.createPair(address(token0), address(token0));
    }

    function test_factory_createPair_zeroAddress() public {
        vm.expectRevert("ParallelTokenFactory: ZERO_ADDRESS");
        factory.createPair(address(0), address(token0));
    }

    function test_factory_setFeeTo() public {
        factory.setFeeTo(charlie);
        assertEq(factory.feeTo(), charlie);
    }

    function test_factory_setFeeToSetter() public {
        factory.setFeeToSetter(charlie);
        assertEq(factory.feeToSetter(), charlie);
    }

    function test_pair_initialize() public view {
        assertTrue(pair.token0() == address(token0) || pair.token0() == address(token1));
        assertTrue(pair.token1() == address(token0) || pair.token1() == address(token1));
        assertTrue(pair.token0() != pair.token1());
    }

    function test_pair_initialize_onlyFactory() public {
        vm.startPrank(alice);
        vm.expectRevert("ParallelTokenPair: FORBIDDEN");
        pair.initialize(address(token0), address(token1), address(pt));
        vm.stopPrank();
    }

    function test_deposit_firstLiquidity() public {
        uint256 amount0 = 1e18;
        uint256 amount1 = 1e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256 expectedLiquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        uint256 lpMinted = pair.deposit(ids, alice);
        vm.stopPrank();

        assertEq(pair.totalSupply(), expectedLiquidity + MINIMUM_LIQUIDITY);
        assertEq(pair.balanceOf(alice), expectedLiquidity);
        assertEq(lpMinted, expectedLiquidity);
    }

    function test_deposit_minimumLiquidityLocked() public {
        uint256 amount0 = 1e18;
        uint256 amount1 = 1e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        pair.deposit(ids, alice);
        vm.stopPrank();

        assertEq(pair.balanceOf(address(0)), MINIMUM_LIQUIDITY);
    }

    function test_deposit_updatesReserves() public {
        uint256 amount0 = 1e18;
        uint256 amount1 = 1e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        pair.deposit(ids, alice);
        vm.stopPrank();

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(reserve0, amount0);
        assertEq(reserve1, amount1);
    }

    function test_deposit_emitMint() public {
        uint256 amount0 = 1e18;
        uint256 amount1 = 1e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        vm.expectEmit(true, true, true, true);
        emit ParallelTokenPair.Mint(alice, amount0, amount1);
        pair.deposit(ids, alice);
        vm.stopPrank();
    }

    function test_deposit_noIds() public {
        vm.startPrank(alice);
        vm.expectRevert("ParallelTokenPair: NO_IDS");
        pair.deposit(new uint256[](0), alice);
        vm.stopPrank();
    }

    function test_deposit_invalidUnderlying() public {
        MockToken token2 = new MockToken();
        token2.mint(alice, 1e18);

        vm.startPrank(alice);
        token2.approve(address(pt), type(uint256).max);
        uint256 id0 = pt.mint(address(token0), 1e18);
        uint256 id2 = pt.mint(address(token2), 1e18);

        pt.push(id0, address(pair));
        pt.push(id2, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id2;
        vm.expectRevert("ParallelTokenPair: INVALID_UNDERLYING");
        pair.deposit(ids, alice);
        vm.stopPrank();
    }

    function test_deposit_alreadyDeposited() public {
        uint256 amount0 = 1e18;
        uint256 amount1 = 1e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        pair.deposit(ids, alice);
        vm.stopPrank();
    }

    function test_withdraw_full() public {
        uint256 amount0 = 10e18;
        uint256 amount1 = 10e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        uint256 lpMinted = pair.deposit(ids, alice);

        uint256[] memory newIds = pair.withdraw(lpMinted, alice, "");
        vm.stopPrank();

        assertEq(pair.balanceOf(alice), 0);
        assertEq(newIds.length, 2);
    }

    function test_withdraw_partial() public {
        uint256 amount0 = 10e18;
        uint256 amount1 = 10e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        uint256 lpMinted = pair.deposit(ids, alice);

        uint256 withdrawLp = lpMinted / 2;
        pair.withdraw(withdrawLp, alice, "");

        assertEq(pair.balanceOf(alice), lpMinted - withdrawLp);
        vm.stopPrank();
    }

    function test_withdraw_updatesReserves() public {
        uint256 amount0 = 10e18;
        uint256 amount1 = 10e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        uint256 lpMinted = pair.deposit(ids, alice);

        pair.withdraw(lpMinted, alice, "");
        vm.stopPrank();

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
    }

    function test_withdraw_emitBurn() public {
        uint256 amount0 = 10e18;
        uint256 amount1 = 10e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        uint256 lpMinted = pair.deposit(ids, alice);

        vm.expectEmit(true, true, true, true);
        emit ParallelTokenPair.Burn(alice, amount0, amount1, alice);
        pair.withdraw(lpMinted, alice, "");
        vm.stopPrank();
    }

    function test_swap_token0ForToken1() public {
        uint256 amount0 = 10e18;
        uint256 amount1 = 10e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        pair.deposit(ids, alice);
        vm.stopPrank();
    }

    function test_swap_kInvariant() public {
        uint256 amount0 = 100e18;
        uint256 amount1 = 100e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        pair.deposit(ids, alice);
        vm.stopPrank();
    }

    function test_swap_zeroOutput() public {
        uint256 amount0 = 10e18;
        uint256 amount1 = 10e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        pair.deposit(ids, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("ParallelTokenPair: INSUFFICIENT_OUTPUT_AMOUNT");
        pair.swap(0, 0, bob, "");
        vm.stopPrank();
    }

    function test_swap_insufficientLiquidity() public {
        uint256 amount0 = 10e18;
        uint256 amount1 = 10e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        pair.deposit(ids, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 idSwap = pt.mint(address(token0), amount0);
        pt.push(idSwap, address(pair));
        vm.expectRevert("ParallelTokenPair: INSUFFICIENT_LIQUIDITY");
        pair.swap(amount0 + 1, 0, bob, "");
        vm.stopPrank();
    }

    function test_swap_invalidTo() public {
        uint256 amount0 = 10e18;
        uint256 amount1 = 10e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        pair.deposit(ids, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 idSwap = pt.mint(address(token0), 1e18);
        pt.push(idSwap, address(pair));
        vm.expectRevert("ParallelTokenPair: INVALID_TO");
        pair.swap(0, 1e18, address(token0), "");
        vm.stopPrank();
    }

    function test_swap_noInput() public {
        uint256 amount0 = 10e18;
        uint256 amount1 = 10e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        pair.deposit(ids, alice);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert("ParallelTokenPair: INSUFFICIENT_OUTPUT_AMOUNT");
        pair.swap(0, 0, alice, "");
        vm.stopPrank();
    }

    function test_swap_emitSwap() public {
        uint256 amount0 = 10e18;
        uint256 amount1 = 10e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        pair.deposit(ids, alice);
        vm.stopPrank();
    }

    function test_getReserves() public {
        uint256 amount0 = 10e18;
        uint256 amount1 = 10e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        pair.deposit(ids, alice);
        vm.stopPrank();

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
        assertEq(reserve0, amount0);
        assertEq(reserve1, amount1);
        assertEq(blockTimestampLast, block.timestamp % 2 ** 32);
    }

    function test_LP_approve() public {
        vm.startPrank(alice);
        pair.approve(bob, 100e18);
        vm.stopPrank();

        assertEq(pair.allowance(alice, bob), 100e18);
    }

    function test_LP_transfer() public {
        uint256 amount0 = 10e18;
        uint256 amount1 = 10e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        uint256 lpMinted = pair.deposit(ids, alice);

        pair.transfer(bob, lpMinted);
        vm.stopPrank();

        assertEq(pair.balanceOf(alice), 0);
        assertEq(pair.balanceOf(bob), lpMinted);
    }

    function test_LP_transferFrom() public {
        uint256 amount0 = 10e18;
        uint256 amount1 = 10e18;

        vm.startPrank(alice);
        uint256 id0 = pt.mint(address(token0), amount0);
        uint256 id1 = pt.mint(address(token1), amount1);

        pt.push(id0, address(pair));
        pt.push(id1, address(pair));

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        uint256 lpMinted = pair.deposit(ids, alice);

        pair.approve(bob, lpMinted);
        vm.stopPrank();

        vm.startPrank(bob);
        pair.transferFrom(alice, charlie, lpMinted);
        vm.stopPrank();

        assertEq(pair.balanceOf(charlie), lpMinted);
    }

    function test_LP_nameAndSymbol() public view {
        assertEq(pair.name(), "Parallel Liquidity");
        assertEq(pair.symbol(), "PLP");
    }
}

library Math {
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
