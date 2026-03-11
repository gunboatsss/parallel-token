// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.33;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract ParallelToken {
    struct TokenData {
        address underlyingERC20;
        address owner;
        uint256 amount;
    }

    mapping(uint256 id => TokenData) public idToTokenData;
    mapping(address => uint256) public nonces;

    mapping(address owner => mapping(address spender => mapping(uint256 id => bool))) public allowance;
    mapping(address owner => mapping(address operator => bool)) public isOperator;

    event Mint(uint256 indexed id, address indexed owner, uint256 balance);
    event Burn(uint256 indexed id, address indexed owner, uint256 balance);

    event Merge(uint256 indexed id, uint256 newAmount);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id, bool approval);
    event OperatorSet(address indexed owner, address indexed operator, bool approval);

    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, bytes memo);

    function mint(address _underlying, uint256 _amount) public returns (uint256 newId) {
        require(_amount > 0);
        uint256 nonce = nonces[msg.sender] + 1;
        newId = uint256(keccak256(abi.encode(msg.sender, nonce)));
        require(_underlying != address(0));
        require(idToTokenData[newId].owner == address(0));
        idToTokenData[newId] = TokenData({underlyingERC20: _underlying, owner: msg.sender, amount: _amount});
        nonces[msg.sender] = nonce;
        emit Mint(newId, msg.sender, _amount);
        SafeTransferLib.safeTransferFrom(_underlying, msg.sender, address(this), _amount);
    }

    function mintMany(address _underlying, uint256[] calldata _amount) public returns (uint256[] memory newId) {
        uint256 length = _amount.length;
        require(length > 0);
        newId = new uint256[](length);
        uint256 totalDebit;
        uint256 nonce = nonces[msg.sender] + 1;
        for (uint256 i; i < length; i++) {
            uint256 currentAmount = _amount[i];
            require(currentAmount > 0);
            totalDebit += currentAmount;
            uint256 newCurrentId = uint256(keccak256(abi.encode(msg.sender, nonce)));
            require(idToTokenData[newCurrentId].owner == address(0));
            idToTokenData[newCurrentId] =
                TokenData({underlyingERC20: _underlying, owner: msg.sender, amount: currentAmount});
            newId[i] = newCurrentId;
            emit Mint(newCurrentId, msg.sender, currentAmount);
            nonce += 1;
        }
        nonces[msg.sender] = nonce;
        SafeTransferLib.safeTransferFrom(_underlying, msg.sender, address(this), totalDebit);
    }

    function burn(uint256 _id) public returns (uint256 redeemed) {
        require(idToTokenData[_id].owner == msg.sender);
        redeemed = idToTokenData[_id].amount;
        address underlyingToken = idToTokenData[_id].underlyingERC20;
        delete idToTokenData[_id];
        emit Burn(_id, msg.sender, redeemed);
        SafeTransferLib.safeTransfer(underlyingToken, msg.sender, redeemed);
    }

    function burnMany(uint256[] calldata _id) public returns (uint256 redeemed) {
        uint256 length = _id.length;
        require(length > 0);
        TokenData memory firstToken = idToTokenData[_id[0]];
        require(firstToken.owner == msg.sender);
        address underlying = firstToken.underlyingERC20;
        redeemed = firstToken.amount;
        delete idToTokenData[_id[0]];
        emit Burn(_id[0], msg.sender, firstToken.amount);
        for (uint256 i = 1; i < length; i++) {
            TokenData memory currentToken = idToTokenData[_id[i]];
            require(currentToken.underlyingERC20 == underlying);
            require(currentToken.owner == msg.sender);
            redeemed += currentToken.amount;
            delete idToTokenData[_id[i]];
            emit Burn(_id[i], msg.sender, currentToken.amount);
        }
        SafeTransferLib.safeTransfer(underlying, msg.sender, redeemed);
    }

    function merge(uint256[] calldata _id, uint256 _to) public returns (bool) {
        require(idToTokenData[_to].owner == msg.sender);
        uint256 length = _id.length;
        uint256 accumulator;
        for (uint256 i; i < length; i++) {
            TokenData memory currentToken = idToTokenData[_id[i]];
            require(_id[i] != _to);
            require(currentToken.owner == msg.sender);
            require(currentToken.underlyingERC20 == idToTokenData[_to].underlyingERC20);
            accumulator += currentToken.amount;
            delete idToTokenData[_id[i]];
            emit Burn(_id[i], msg.sender, currentToken.amount);
        }
        idToTokenData[_to].amount += accumulator;
        emit Merge(_to, idToTokenData[_to].amount);
        return true;
    }

    function split(uint256 _id, uint256[] calldata splitAmount) public returns (uint256[] memory newId) {
        TokenData memory tokenToSplit = idToTokenData[_id];
        require(tokenToSplit.owner == msg.sender);
        uint256 originalAmount = tokenToSplit.amount;
        delete idToTokenData[_id];
        emit Burn(_id, msg.sender, originalAmount);
        uint256 length = splitAmount.length;
        newId = new uint256[](length);
        uint256 accumulator;
        uint256 nonce = nonces[msg.sender] + 1;
        for (uint256 i; i < length; i++) {
            require(splitAmount[i] > 0);
            accumulator += splitAmount[i];
            uint256 newCurrentId = uint256(keccak256(abi.encode(msg.sender, nonce)));
            require(idToTokenData[newCurrentId].owner == address(0));
            idToTokenData[newCurrentId] =
                TokenData({underlyingERC20: tokenToSplit.underlyingERC20, owner: msg.sender, amount: splitAmount[i]});
            newId[i] = newCurrentId;
            emit Mint(newCurrentId, msg.sender, splitAmount[i]);
            nonce += 1;
        }
        require(accumulator == tokenToSplit.amount);
        nonces[msg.sender] = nonce;
    }

    function _push(uint256 _id, address _to, bytes memory _memo) private {
        require(idToTokenData[_id].owner == msg.sender);
        require(_to != address(0));
        idToTokenData[_id].owner = _to;
        emit Transfer(msg.sender, msg.sender, _to, _id, _memo);
    }

    function push(uint256 _id, address _to) public returns (bool) {
        _push(_id, _to, "");
        return true;
    }

    function push(uint256 _id, address _to, bytes calldata _memo) public returns (bool) {
        _push(_id, _to, _memo);
        return true;
    }

    function pushMany(uint256[] calldata _id, address[] calldata _to) public returns (bool) {
        uint256 length = _id.length;
        require(length == _to.length);
        for (uint256 i; i < length; i++) {
            _push(_id[i], _to[i], "");
        }
        return true;
    }

    function pushMany(uint256[] calldata _id, address[] calldata _to, bytes[] calldata _memo) public returns (bool) {
        uint256 length = _id.length;
        require(length == _to.length && length == _memo.length);
        for (uint256 i; i < length; i++) {
            _push(_id[i], _to[i], _memo[i]);
        }
        return true;
    }

    function pull(uint256 _id, address _to, bytes calldata _memo) public returns (bool) {
        address from = idToTokenData[_id].owner;
        require(_to != address(0));
        require(from == msg.sender || isOperator[from][msg.sender] || allowance[from][msg.sender][_id]);
        idToTokenData[_id].owner = _to;
        emit Transfer(msg.sender, from, _to, _id, _memo);
        return true;
    }

    function pullMany(uint256[] calldata _id, address[] calldata _to, bytes calldata _memo) public returns (bool) {
        uint256 length = _id.length;
        require(length == _to.length);
        for (uint256 i; i < length; i++) {
            uint256 currentId = _id[i];
            address currentAddress = _to[i];
            address from = idToTokenData[currentId].owner;
            require(currentAddress != address(0));
            require(from == msg.sender || isOperator[from][msg.sender] || allowance[from][msg.sender][currentId]);
            idToTokenData[currentId].owner = currentAddress;
            emit Transfer(msg.sender, from, currentAddress, currentId, _memo);
        }
        return true;
    }

    function setApproval(address _spender, uint256 _id, bool _approve) public returns (bool) {
        allowance[msg.sender][_spender][_id] = _approve;
        emit Approval(msg.sender, _spender, _id, _approve);
        return true;
    }

    function setOperator(address _spender, bool _approve) public returns (bool) {
        isOperator[msg.sender][_spender] = _approve;
        emit OperatorSet(msg.sender, _spender, _approve);
        return true;
    }
}
