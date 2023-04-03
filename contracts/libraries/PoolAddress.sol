// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Provides functions for deriving a pool address from the factory, tokens, and the fee
// 交易对池子地址 会用到的一些函数
library PoolAddress {
    // UniswapV3Pool池子合约的 代码字节码的哈希值
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    // 池的标识键，两个token地址，一个fee，即可确定池子的唯一性
    /// @notice The identifying key of the pool
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice Returns PoolKey: the ordered tokens with the matched fee levels
    /// @param tokenA The first token of a pool, unsorted
    /// @param tokenB The second token of a pool, unsorted
    /// @param fee The fee level of the pool
    /// @return Poolkey The pool details with ordered token0 and token1 assignments
    function getPoolKey(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal pure returns (PoolKey memory) {
        // 地址小的排前面（地址是16进制的数字，可以比较大小）
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        // 返回PoolKey结构的数据
        return PoolKey({token0: tokenA, token1: tokenB, fee: fee});
    }

    // 根据给定的工厂合约地址 和带有token0,token1,fee数据的poolKey数据， 确定性的计算出 交易池合约的地址
    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param factory The Uniswap V3 factory contract address
    /// @param key The PoolKey
    /// @return pool The contract address of the V3 pool
    function computeAddress(address factory, PoolKey memory key) internal pure returns (address pool) {
        // 小的合约地址 排在前面,为token0
        require(key.token0 < key.token1);
        //  create2 操作符的 新合约地址生成逻辑
        pool = address(
            // 转换成256正整数 数据结构
            uint256(
                // 取哈希
                keccak256(
                    // 把工厂合约等数据拼接起来
                    abi.encodePacked(
                        hex'ff',
                        factory,
                        keccak256(abi.encode(key.token0, key.token1, key.fee)),
                        POOL_INIT_CODE_HASH//交易池合约的代码字节码哈希值
                    )
                )
            )
        );
    }
}
