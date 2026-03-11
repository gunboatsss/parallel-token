// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.33;

import {IParallelTokenFactory} from "./interfaces/IParallelTokenFactory.sol";
import {ParallelTokenPair} from "./ParallelTokenPair.sol";

contract ParallelTokenFactory is IParallelTokenFactory {
    address public override feeTo;
    address public override feeToSetter;
    address public immutable override parallelToken;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    constructor(address _feeToSetter, address _parallelToken) {
        feeToSetter = _feeToSetter;
        parallelToken = _parallelToken;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function createPair(address _tokenA, address _tokenB) external override returns (address pair) {
        require(_tokenA != _tokenB, "ParallelTokenFactory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        require(token0 != address(0), "ParallelTokenFactory: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "ParallelTokenFactory: PAIR_EXISTS");

        bytes memory bytecode = type(ParallelTokenPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ParallelTokenPair(pair).initialize(token0, token1, parallelToken);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "ParallelTokenFactory: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, "ParallelTokenFactory: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}
