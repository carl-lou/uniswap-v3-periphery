// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import './PeripheryImmutableState.sol';
import '../interfaces/IPoolInitializer.sol';

/// @title Creates and initializes V3 Pools
abstract contract PoolInitializer is IPoolInitializer, PeripheryImmutableState {
    /// @inheritdoc IPoolInitializer
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable override returns (address pool) {
        require(token0 < token1);
        // 查询是否已经创建过该交易对
        pool = IUniswapV3Factory(factory).getPool(token0, token1, fee);

        if (pool == address(0)) {
            // 调用UniswapV3Factory合约的创建交易对池子方法，创建一个交易对
            pool = IUniswapV3Factory(factory).createPool(token0, token1, fee);
            // 调用UniswapV3Pool这个交易对合约里的初始化方法
            IUniswapV3Pool(pool).initialize(sqrtPriceX96);
        } else {
            // 已创建过这个交易对池子合约，获取当前的价格
            (uint160 sqrtPriceX96Existing, , , , , , ) = IUniswapV3Pool(pool).slot0();
            if (sqrtPriceX96Existing == 0) {
                // 当前价格为0，初始化一下
                IUniswapV3Pool(pool).initialize(sqrtPriceX96);
            }
        }
    }
}
