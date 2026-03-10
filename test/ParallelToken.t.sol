// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";

import {ParallelToken} from "src/ParallelToken.sol";

import {ERC20} from "solady/tokens/ERC20.sol";

contract TokenA is ERC20 {
    constructor(address a) {
        _mint(a, 1_000_000e18);
    }

    function name() public view override returns (string memory) {
        return "Token A";
    }

    function symbol() public view override returns (string memory) {
        return "A";
    }
}

contract ParallelTokenTest is Test {
    TokenA tokenA;
    ParallelToken pt;
    address adam = makeAddr("adam");

    function setUp() public {
        tokenA = new TokenA(adam);
        pt = new ParallelToken();
    }

    function test_mintAndBurn() public {
        vm.startPrank(adam);
        tokenA.approve(address(pt), 1e18);
        uint256 id = pt.mint(address(tokenA), 1e18);
        pt.burn(id);
    }
}
