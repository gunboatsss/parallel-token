// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.33;

interface IParallelToken {
    struct TokenData {
        address underlyingERC20;
        address owner;
        uint256 amount;
    }

    event Mint(uint256 indexed id, address indexed owner, uint256 balance);
    event Burn(uint256 indexed id, address indexed owner, uint256 balance);
    event Merge(uint256 indexed id, uint256 newAmount);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, bool approval);
    event OperatorSet(address indexed owner, address indexed operator, bool approval);
    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, bytes memo);

    error ZeroAmount();
    error ZeroAddress();
    error Collusion();
    error ZeroLength();
    error NotAOwner();
    error MixedAddress(address address1, address address2);
    error InvalidMerge();
    error InvalidLength();
    error Unauthorized();

    function nonces(address owner) external view returns (uint256);
    function allowance(address owner, address spender, uint256 id) external view returns (bool);
    function isOperator(address owner, address operator) external view returns (bool);

    function mint(address _underlying, uint256 _amount) external returns (uint256 newId);

    function mintMany(address _underlying, uint256[] calldata _amount) external returns (uint256[] memory newId);

    function burn(uint256 _id) external returns (uint256 redeemed);

    function burnMany(uint256[] calldata _id) external returns (uint256 redeemed);

    function merge(uint256[] calldata _id, uint256 _to) external returns (bool);

    function split(uint256 _id, uint256[] calldata splitAmount) external returns (uint256[] memory newId);

    function push(uint256 _id, address _to) external returns (bool);

    function push(uint256 _id, address _to, bytes calldata _memo) external returns (bool);

    function pushMany(uint256[] calldata _id, address[] calldata _to) external returns (bool);

    function pushMany(uint256[] calldata _id, address[] calldata _to, bytes[] calldata _memo) external returns (bool);

    function pull(uint256 _id, address _to, bytes calldata _memo) external returns (bool);

    function pullMany(uint256[] calldata _id, address[] calldata _to, bytes[] calldata _memo) external returns (bool);

    function setApproval(address _spender, uint256 _id, bool _approve) external returns (bool);

    function setOperator(address _spender, bool _approve) external returns (bool);
}
