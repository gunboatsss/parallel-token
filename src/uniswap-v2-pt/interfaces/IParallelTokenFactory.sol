// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.33;

interface IParallelTokenFactory {
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function parallelToken() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address _feeTo) external;
    function setFeeToSetter(address _feeToSetter) external;
}
