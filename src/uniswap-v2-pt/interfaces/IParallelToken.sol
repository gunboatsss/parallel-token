// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.33;

interface IParallelToken {
    struct TokenData {
        address underlyingERC20;
        address owner;
        uint256 amount;
    }

    function idToTokenData(uint256 id) external view returns (TokenData memory);
    function nonces(address owner) external view returns (uint256);

    function allowance(address owner, address spender, uint256 id) external view returns (bool);
    function isOperator(address owner, address operator) external view returns (bool);

    function mint(address _underlying, uint256 _amount) external returns (uint256 newId);
    function burn(uint256 _id) external returns (uint256 redeemed);
    function merge(uint256[] calldata _id, uint256 _to) external returns (bool);
    function split(uint256 _id, uint256[] calldata splitAmount) external returns (uint256[] memory newId);

    function push(uint256 _id, address _to) external returns (bool);
    function push(uint256 _id, address _to, bytes calldata _memo) external returns (bool);
    function pushMany(uint256[] calldata _id, address[] calldata _to) external returns (bool);

    function pull(uint256 _id, address _to, bytes calldata _memo) external returns (bool);
    function pullMany(uint256[] calldata _id, address[] calldata _to, bytes calldata _memo) external returns (bool);

    function setApproval(address _spender, uint256 _id, bool _approve) external returns (bool);
    function setOperator(address _spender, bool _approve) external returns (bool);
}
