// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {ParallelToken} from "src/ParallelToken.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(address a) {
        _mint(a, type(uint256).max);
    }

    function name() public pure override returns (string memory) {
        return "Mock";
    }

    function symbol() public pure override returns (string memory) {
        return "MOCK";
    }
}

contract ParallelTokenHandler is Test {
    ParallelToken public pt;
    MockERC20 public mockToken;

    address[] public users;
    uint256[] public tokenIds;
    uint256 public initialTokenSupply = 1000e18;

    uint256 public ghost_mintSum;
    uint256 public ghost_burnSum;

    uint256 public constant MAX_TOKEN_COUNT = 50;

    constructor(ParallelToken _pt) {
        pt = _pt;
        mockToken = new MockERC20(address(this));
        mockToken.approve(address(pt), type(uint256).max);

        for (uint256 i = 0; i < 5; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            users.push(user);
            mockToken.transfer(user, initialTokenSupply);
        }
    }

    function actors(uint256 index) public view returns (address) {
        return users[index % users.length];
    }

    function getGhostMintSum() public view returns (uint256) {
        return ghost_mintSum;
    }

    function getGhostBurnSum() public view returns (uint256) {
        return ghost_burnSum;
    }

    function mint(uint256 actorSeed, uint256 amount) public {
        if (tokenIds.length >= MAX_TOKEN_COUNT) return;
        amount = bound(amount, 1e18, 100e18);
        address actor = actors(actorSeed);

        vm.startPrank(actor);
        MockERC20(mockToken).approve(address(pt), amount);
        try pt.mint(address(mockToken), amount) returns (uint256 id) {
            tokenIds.push(id);
            ghost_mintSum += amount;
        } catch {}
        vm.stopPrank();
    }

    function mintMany(uint256 actorSeed, uint256 amountSeed, uint256 count) public {
        if (tokenIds.length >= MAX_TOKEN_COUNT) return;
        count = bound(count, 2, 5);
        amountSeed = bound(amountSeed, 1e18, 20e18);
        address actor = actors(actorSeed);

        uint256[] memory amounts = new uint256[](count);
        uint256 total;
        for (uint256 i; i < count; i++) {
            amounts[i] = (amountSeed * (i + 1)) / count;
            total += amounts[i];
        }

        vm.startPrank(actor);
        MockERC20(mockToken).approve(address(pt), total);
        try pt.mintMany(address(mockToken), amounts) returns (uint256[] memory ids) {
            for (uint256 i; i < ids.length; i++) {
                tokenIds.push(ids[i]);
            }
            ghost_mintSum += total;
        } catch {}
        vm.stopPrank();
    }

    function burn(uint256 actorSeed, uint256 tokenIdSeed) public {
        if (tokenIds.length == 0) return;

        uint256 id = tokenIds[tokenIdSeed % tokenIds.length];
        address actor = actors(actorSeed);

        (,, uint256 amount) = pt.idToTokenData(id);
        if (amount == 0) return;

        vm.startPrank(actor);
        try pt.burn(id) {
            ghost_burnSum += amount;
        } catch {}
        vm.stopPrank();
    }

    function push(uint256 actorSeed, uint256 tokenIdSeed) public {
        if (tokenIds.length == 0) return;

        uint256 id = tokenIds[tokenIdSeed % tokenIds.length];
        address from = actors(actorSeed);
        address to = actors(actorSeed + 1);

        vm.startPrank(from);
        try pt.push(id, to) {} catch {}
        vm.stopPrank();
    }

    function pull(uint256 actorSeed, uint256 tokenIdSeed) public {
        if (tokenIds.length == 0) return;

        uint256 id = tokenIds[tokenIdSeed % tokenIds.length];
        (, address from,) = pt.idToTokenData(id);
        if (from == address(0)) return;

        address to = actors(actorSeed + 1);

        vm.startPrank(to);
        try pt.pull(id, to, "") {} catch {}
        vm.stopPrank();
    }

    function merge(uint256 actorSeed, uint256 tokenIdSeed) public {
        if (tokenIds.length < 3) return;

        uint256 id1 = tokenIds[tokenIdSeed % tokenIds.length];
        uint256 id2 = tokenIds[(tokenIdSeed + 1) % tokenIds.length];
        (, address owner2,) = pt.idToTokenData(id2);
        if (owner2 == address(0)) return;

        address actor = actors(actorSeed);

        uint256[] memory ids = new uint256[](1);
        ids[0] = id1;

        vm.startPrank(actor);
        try pt.merge(ids, id2) {} catch {}
        vm.stopPrank();
    }

    function split(uint256 actorSeed, uint256 tokenIdSeed) public {
        if (tokenIds.length == 0) return;

        uint256 id = tokenIds[tokenIdSeed % tokenIds.length];
        (, address owner,) = pt.idToTokenData(id);
        if (owner == address(0)) return;

        address actor = actors(actorSeed);

        uint256[] memory splitAmounts = new uint256[](2);
        splitAmounts[0] = 1e18;
        splitAmounts[1] = 1e18;

        vm.startPrank(actor);
        try pt.split(id, splitAmounts) {} catch {}
        vm.stopPrank();
    }

    function setApproval(uint256 actorSeed, uint256 tokenIdSeed) public {
        if (tokenIds.length == 0) return;

        uint256 id = tokenIds[tokenIdSeed % tokenIds.length];
        address actor = actors(actorSeed);
        address spender = actors(actorSeed + 1);

        vm.startPrank(actor);
        try pt.setApproval(spender, id, true) {} catch {}
        vm.stopPrank();
    }

    function setOperator(uint256 actorSeed) public {
        address actor = actors(actorSeed);
        address operator = actors(actorSeed + 1);

        vm.startPrank(actor);
        try pt.setOperator(operator, true) {} catch {}
        vm.stopPrank();
    }

    function callSummary() public view {
        console.log("Ghost mint sum:", ghost_mintSum);
        console.log("Ghost burn sum:", ghost_burnSum);
    }
}
