// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ParallelToken} from "src/ParallelToken.sol";
import {ParallelTokenHandler} from "../handlers/ParallelTokenHandlers.sol";

contract ParallelTokenInvariantTest is StdInvariant {
    ParallelToken public pt;
    ParallelTokenHandler public handler;

    function setUp() public {
        pt = new ParallelToken();
        handler = new ParallelTokenHandler(pt);
        targetContract(address(handler));
    }

    function invariant_token_conservation() public view {
        uint256 ghostMint = handler.getGhostMintSum();
        uint256 ghostBurn = handler.getGhostBurnSum();
        uint256 totalInContract = ghostMint - ghostBurn;

        uint256 balanceInContract = MockERC20(address(handler.mockToken())).balanceOf(address(pt));

        assert(balanceInContract == totalInContract);
    }
}

interface MockERC20 {
    function balanceOf(address account) external view returns (uint256);
}
