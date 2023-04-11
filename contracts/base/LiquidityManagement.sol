// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';

import '../libraries/PoolAddress.sol';
import '../libraries/CallbackValidation.sol';
import '../libraries/LiquidityAmounts.sol';

import './PeripheryPayments.sol';
import './PeripheryImmutableState.sol';

/// @title Liquidity management functions
/// @notice Internal functions for safely managing liquidity in Uniswap V3
abstract contract LiquidityManagement is IUniswapV3MintCallback, PeripheryImmutableState, PeripheryPayments {
    struct MintCallbackData {
        PoolAddress.PoolKey poolKey;
        address payer;
    }

    /// @inheritdoc IUniswapV3MintCallback
    // 为铸造的流动性支付所欠的池代币
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data //abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender}))
    ) external override {
        // 结果就是 MintCallbackData({poolKey: poolKey, payer: msg.sender})
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
        // 验证decoded.poolKey必须是 factory工厂合约  创建的pool合约
        CallbackValidation.verifyCallback(factory, decoded.poolKey);
        // 如果要转账的钱大于0，就转账,decoded.payer转给msg.sender(pool合约)
        if (amount0Owed > 0) pay(decoded.poolKey.token0, decoded.payer, msg.sender, amount0Owed);
        if (amount1Owed > 0) pay(decoded.poolKey.token1, decoded.payer, msg.sender, amount1Owed);
    }

    struct AddLiquidityParams {
        address token0;
        address token1;
        uint24 fee; //交易费率，给LP的
        address recipient; //流动性资金的所属人地址
        int24 tickLower; //流动性的价格下限（以token0计价），这里传入的是tick index
        int24 tickUpper; //上限
        uint256 amount0Desired; //注入的token0资金数量，希望提供的token0
        uint256 amount1Desired;
        uint256 amount0Min; //提供的token0下限数
        uint256 amount1Min;
    }

    /// @notice Add liquidity to an initialized pool
    // 添加流动性到一个已初始化（构造过的）交易对池子
    function addLiquidity(
        AddLiquidityParams memory params
    ) internal returns (uint128 liquidity, uint256 amount0, uint256 amount1, IUniswapV3Pool pool) {
        // 创建一个poolKey struct 结构的数据
        PoolAddress.PoolKey memory poolKey = PoolAddress.PoolKey({
            token0: params.token0,
            token1: params.token1,
            fee: params.fee
        });

        // 算出交易池合约的地址
        // 地址直接赋值给 IUniswapV3Pool类型,会进行类型隐式转换
        pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));

        // compute the liquidity amount
        // 计算流动性资金金额
        {
            // 获取当前平方价
            (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
            // 传入的 lower/upper 价格是以 tick index 来表示的，
            // 因此需要在链下(前端界面)先计算好价格所对应的 tick index
            // 算出A点也就是刻度下限位置的价格
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(params.tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);

            // 根据价格上下限 当前价格，注入的资金量，算出流动性
            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                sqrtRatioAX96,
                sqrtRatioBX96,
                params.amount0Desired,
                params.amount1Desired
            );
        }
        // 在池子里铸造,增加流动性
        (amount0, amount1) = pool.mint(
            params.recipient,
            params.tickLower,
            params.tickUpper,
            liquidity,
            // MintCallbackData是将池子 与 LP做市商的账户地址 关联起来
            // 对于 UniswapV3Pool 合约来说，这个 Position 的 owner 是 NonfungiblePositionManager，
            // 而 NonfungiblePositionManager 再通过 NFT Token 将 Position 与用户关联起来。这样用户就可以将 LP token 进行转账或者抵押类操作。
            // 跨合约调用，没有对应Struct，要用abi编码
            abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender}))
        );

        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, 'Price slippage check');
    }
}
