// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.33;

import {UniswapV2ERC20} from "./UniswapV2ERC20.sol";
import {IParallelToken} from "./interfaces/IParallelToken.sol";
import {IParallelTokenFactory} from "./interfaces/IParallelTokenFactory.sol";
import {Math} from "./libraries/Math.sol";
import {UQ112x112} from "./libraries/UQ112x112.sol";

contract ParallelTokenPair is UniswapV2ERC20 {
    using Math for uint256;
    using UQ112x112 for uint224;

    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    address public factory;
    address public token0;
    address public token1;
    address public parallelToken;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;

    uint256 private unlocked = 1;

    uint256 public position0Id;
    uint256 public position1Id;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    modifier lock() {
        require(unlocked == 1, "ParallelTokenPair: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves()
        public
        view
        override
        returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast)
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1, address _parallelToken) external override {
        require(msg.sender == factory, "ParallelTokenPair: FORBIDDEN");
        require(_token0 != address(0) && _token1 != address(0), "ParallelTokenPair: ZERO_ADDRESS");
        token0 = _token0;
        token1 = _token1;
        parallelToken = _parallelToken;
    }

    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "ParallelTokenPair: OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IParallelTokenFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function _findIdWithAmount(IParallelToken pt, address underlying, uint256 neededAmount)
        internal
        returns (uint256 id, uint256 actualAmount)
    {
        uint256 nonce = pt.nonces(address(this));
        for (uint256 i = 1; i <= nonce + 100; i++) {
            uint256 checkId = uint256(keccak256(abi.encode(address(this), i)));
            try pt.idToTokenData(checkId) returns (IParallelToken.TokenData memory data) {
                if (data.underlyingERC20 == underlying && data.owner == address(this) && data.amount >= neededAmount) {
                    return (checkId, data.amount);
                }
            } catch {
                break;
            }
        }
        revert("ParallelTokenPair: NO_ID_FOUND");
    }

    function deposit(uint256[] calldata ids, address to) external lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = _reserve0;
        uint256 balance1 = _reserve1;
        uint256 amount0;
        uint256 amount1;

        uint256 length = ids.length;
        require(length > 0, "ParallelTokenPair: NO_IDS");

        IParallelToken pt = IParallelToken(parallelToken);

        for (uint256 i; i < length; i++) {
            uint256 id = ids[i];
            IParallelToken.TokenData memory tokenData = pt.idToTokenData(id);

            if (tokenData.underlyingERC20 == token0) {
                amount0 += tokenData.amount;
                if (position0Id == 0) {
                    position0Id = id;
                }
            } else if (tokenData.underlyingERC20 == token1) {
                amount1 += tokenData.amount;
                if (position1Id == 0) {
                    position1Id = id;
                }
            } else {
                revert("ParallelTokenPair: INVALID_UNDERLYING");
            }
        }

        require(amount0 > 0 || amount1 > 0, "ParallelTokenPair: ZERO_DEPOSIT");

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1);
        }
        require(liquidity > 0, "ParallelTokenPair: INSUFFICIENT_LIQUIDITY");
        _mint(to, liquidity);

        balance0 = _reserve0 + amount0;
        balance1 = _reserve1 + amount1;
        _update(balance0, balance1, _reserve0, _reserve1);
        kLast = uint256(reserve0) * reserve1;
        emit Mint(msg.sender, amount0, amount1);
    }

    function withdraw(uint256 liquidity, address to, bytes calldata) external lock returns (uint256[] memory newIds) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = _reserve0;
        uint256 balance1 = _reserve1;
        uint256 _totalSupply = totalSupply;
        uint256 effectiveSupply = _totalSupply - MINIMUM_LIQUIDITY;

        uint256 amount0 = liquidity * balance0 / effectiveSupply;
        uint256 amount1 = liquidity * balance1 / effectiveSupply;
        require(amount0 > 0 && amount1 > 0, "ParallelTokenPair: INSUFFICIENT_LIQUIDITY");

        _burn(msg.sender, liquidity);

        IParallelToken pt = IParallelToken(parallelToken);

        newIds = new uint256[](2);

        if (amount0 > 0 && position0Id != 0) {
            IParallelToken.TokenData memory data = pt.idToTokenData(position0Id);
            require(data.amount >= amount0, "ParallelTokenPair: INSUFFICIENT_BALANCE");
            uint256 remainder = data.amount - amount0;
            if (remainder == 0) {
                pt.push(position0Id, to);
                newIds[0] = position0Id;
                position0Id = 0;
            } else {
                uint256[] memory splitAmounts = new uint256[](2);
                splitAmounts[0] = amount0;
                splitAmounts[1] = remainder;
                uint256[] memory newId0 = pt.split(position0Id, splitAmounts);
                newIds[0] = newId0[0];
                pt.push(newId0[0], to);
                position0Id = newId0[1];
            }
        }

        if (amount1 > 0 && position1Id != 0) {
            IParallelToken.TokenData memory data = pt.idToTokenData(position1Id);
            require(data.amount >= amount1, "ParallelTokenPair: INSUFFICIENT_BALANCE");
            uint256 remainder = data.amount - amount1;
            if (remainder == 0) {
                pt.push(position1Id, to);
                newIds[1] = position1Id;
                position1Id = 0;
            } else {
                uint256[] memory splitAmounts = new uint256[](2);
                splitAmounts[0] = amount1;
                splitAmounts[1] = remainder;
                uint256[] memory newId1 = pt.split(position1Id, splitAmounts);
                newIds[1] = newId1[0];
                pt.push(newId1[0], to);
                position1Id = newId1[1];
            }
        }

        balance0 = _reserve0 - amount0;
        balance1 = _reserve1 - amount1;
        _update(balance0, balance1, _reserve0, _reserve1);
        kLast = uint256(reserve0) * reserve1;
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata) external override lock {
        require(amount0Out > 0 || amount1Out > 0, "ParallelTokenPair: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "ParallelTokenPair: INSUFFICIENT_LIQUIDITY");

        require(to != token0 && to != token1, "ParallelTokenPair: INVALID_TO");

        IParallelToken pt = IParallelToken(parallelToken);

        uint256 amount0In;
        uint256 amount1In;

        if (amount0Out > 0) {
            IParallelToken.TokenData memory data = pt.idToTokenData(position1Id);
            require(data.amount >= amount0Out, "ParallelTokenPair: INSUFFICIENT_BALANCE");
            uint256[] memory splitAmounts = new uint256[](2);
            splitAmounts[0] = amount0Out;
            splitAmounts[1] = data.amount - amount0Out;
            uint256[] memory newId1 = pt.split(position1Id, splitAmounts);
            pt.push(newId1[0], to);
            position1Id = newId1[1];
            amount1In = amount0Out;
        }

        if (amount1Out > 0) {
            IParallelToken.TokenData memory data = pt.idToTokenData(position0Id);
            require(data.amount >= amount1Out, "ParallelTokenPair: INSUFFICIENT_BALANCE");
            uint256[] memory splitAmounts = new uint256[](2);
            splitAmounts[0] = amount1Out;
            splitAmounts[1] = data.amount - amount1Out;
            uint256[] memory newId0 = pt.split(position0Id, splitAmounts);
            pt.push(newId0[0], to);
            position0Id = newId0[1];
            amount0In = amount1Out;
        }

        require(amount0In > 0 || amount1In > 0, "ParallelTokenPair: INSUFFICIENT_INPUT_AMOUNT");

        uint256 balance0After = position0Id != 0 ? pt.idToTokenData(position0Id).amount : 0;
        uint256 balance1After = position1Id != 0 ? pt.idToTokenData(position1Id).amount : 0;

        uint256 balance0Adjusted = balance0After * 1000 - amount0In * 3;
        uint256 balance1Adjusted = balance1After * 1000 - amount1In * 3;
        require(
            balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * _reserve1 * 1000 ** 2, "ParallelTokenPair: K"
        );

        _update(uint112(balance0After), uint112(balance1After), _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }
}
