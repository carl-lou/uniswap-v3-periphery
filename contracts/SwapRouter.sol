// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/libraries/SafeCast.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import './interfaces/ISwapRouter.sol';
import './base/PeripheryImmutableState.sol';
import './base/PeripheryValidation.sol';
import './base/PeripheryPaymentsWithFee.sol';
import './base/Multicall.sol';
import './base/SelfPermit.sol';
import './libraries/Path.sol';
import './libraries/PoolAddress.sol';
import './libraries/CallbackValidation.sol';
import './interfaces/external/IWETH9.sol';

/// @title Uniswap V3 Swap Router
/// @notice Router for stateless execution of swaps against Uniswap V3
contract SwapRouter is
    ISwapRouter,
    PeripheryImmutableState,
    PeripheryValidation,
    PeripheryPaymentsWithFee,
    Multicall,
    SelfPermit
{
    using Path for bytes;
    using SafeCast for uint256;

    /// @dev Used as the placeholder value for amountInCached, because the computed amount in for an exact output swap
    /// can never actually be this value
    uint256 private constant DEFAULT_AMOUNT_IN_CACHED = type(uint256).max;

    /// @dev Transient storage variable used for returning the computed amount in for an exact output swap.
    uint256 private amountInCached = DEFAULT_AMOUNT_IN_CACHED;

    constructor(address _factory, address _WETH9) PeripheryImmutableState(_factory, _WETH9) {}

    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist.
    function getPool(address tokenA, address tokenB, uint24 fee) private view returns (IUniswapV3Pool) {
        return IUniswapV3Pool(PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee)));
    }

    struct SwapCallbackData {
        bytes path;
        address payer;
    }

    /// @inheritdoc IUniswapV3SwapCallback
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external override {
        // 不支持完全在零流动性区域内的交易，必须两个token其中之一大于0
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        // abi.decode第二个参数(SwapCallbackData)是返回参数的类型
        // 这里就是abi解析一下
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        // 解析出第一个交易对里的 两个token的地址和fee
        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();
        // 验证调用这个方法的地址是tokenIn, tokenOut, fee这交易对的 V3 Pool池子的地址
        CallbackValidation.verifyCallback(factory, tokenIn, tokenOut, fee);

        // 判断函数的参数中哪个是本次支付需要支付的代币
        (bool isExactInput, uint256 amountToPay) = amount0Delta > 0
            ? // 如果转入的是token0，
            // 那么path里第一个tokenIn地址若是小于第二个地址，那么第一个地址其实就是token0
            // 注入的资金也是tokenIn
            (tokenIn < tokenOut, uint256(amount0Delta))
            : // 如果注入的资金不是token0，而是token1，
            // tokenOut是token0，那么注入的资金也是tokenIn
            (tokenOut < tokenIn, uint256(amount1Delta));

        
        if (isExactInput) {
            // 把tokenIn付给 pool合约
            pay(tokenIn, data.payer, msg.sender, amountToPay);
        } else {
            // 要么发起下一次交换，要么支付
            // either initiate the next swap or pay
            if (data.path.hasMultiplePools()) {
                // path里有多个交易对
                
                //skipToken函数是删除path里第一个地址+fee
                data.path = data.path.skipToken();
                // 再去执行一次交易，用新的Path
                exactOutputInternal(amountToPay, msg.sender, 0, data);
            } else {
                amountInCached = amountToPay;
                tokenIn = tokenOut; // swap in/out because exact output swaps are reversed
                pay(tokenIn, data.payer, msg.sender, amountToPay);
            }
        }
    }

    /// @dev Performs a single exact input swap
    // 执行一次精确的输入交换
    function exactInputInternal(
        uint256 amountIn,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) private returns (uint256 amountOut) {
        // 接受者如果是0地址，则改为当前合约地址（销毁掉还不如给老子）
        // allow swapping to the router address with address 0
        if (recipient == address(0)) recipient = address(this);

        // 解码path路径中的第一个交易池 , 返回两个token地址，以及费率
        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();
        // 第一个地址小于第二个，则zeroForOne为true.
        // 确定这次交易输入的是交易池的token0还是token1
        // 因为交易池中只保存了token0的价格， sqrt(P)=sqrt(token1/token0)，每个token0需要多少个token1
        // token0兑换成token1，和token1兑换成token0，计价公式会不一样，需要换算一下，详细见后续步骤
        bool zeroForOne = tokenIn < tokenOut;

        // 去调用 交易池合约 里的swap方法
        // 返回交易后的token0/token1金额
        (int256 amount0, int256 amount1) = getPool(tokenIn, tokenOut, fee).swap(
            recipient,
            zeroForOne,
            amountIn.toInt256(),
            sqrtPriceLimitX96 == 0
                ? // MIN_SQRT_RATIO = 4295128739
                // MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342
                // 若不做限价，那么边界就是TickMath里的边界。
                // 若是0转换成1，那么价格限制为最小值MIN_SQRT_RATIO，1转0这是最大值
                (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                : sqrtPriceLimitX96,
            abi.encode(data)
        );

        return uint256(-(zeroForOne ? amount1 : amount0));
    }

    /// @inheritdoc ISwapRouter
    // 单个交易对，exactInput的简化版
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable override checkDeadline(params.deadline) returns (uint256 amountOut) {
        amountOut = exactInputInternal(
            params.amountIn,
            params.recipient,
            params.sqrtPriceLimitX96,
            SwapCallbackData({path: abi.encodePacked(params.tokenIn, params.fee, params.tokenOut), payer: msg.sender})
        );
        require(amountOut >= params.amountOutMinimum, 'Too little received');
    }

    /// @inheritdoc ISwapRouter
    // 交易的入口函数，直接给前端调用
    // 在进行两个代币交易时，是首先需要在链下计算出交易的路径，例如使用 ETH -> DAI ：
    // 可以直接通过 ETH/DAI 的交易池完成
    // 也可以通过 ETH -> USDC -> DAI 路径，即经过 ETH/USDC, USDC/DAI 两个交易池完成交易
    // 前端会进行遍历 查找哪条路径能兑换出最多的token1，最少的手续费
    function exactInput(
        ExactInputParams memory params
    )
        external
        payable
        override
        // 需检查没超过交易有效期
        checkDeadline(params.deadline)
        returns (uint256 amountOut)
    {
        // 函数调用者为 第一步买单
        address payer = msg.sender; // msg.sender pays for the first hop

        // 无限循环，直至break
        while (true) {
            // 判断字节长度是否有多个交易对池子， 超过3个token地址+2个费率的长度
            bool hasMultiplePools = params.path.hasMultiplePools();

            // 前掉期的产出成为后续的输入
            // the outputs of prior swaps become the inputs to subsequent ones
            // 原本exactInputInternal返回的是另外一个交易对，这里立即赋值给amountIn是为了下一次循环，若没有循环则无需赋值给amountIn了
            params.amountIn = exactInputInternal(
                params.amountIn,
                // 对于中间掉期，该合同托管; 需经过多个交易对的交换时，接受者地址 由本合约代持
                hasMultiplePools ? address(this) : params.recipient, // for intermediate swaps, this contract custodies
                0, //不做限价
                SwapCallbackData({
                    // 只有路径中的第一个池是必需的
                    path: params.path.getFirstPool(), // only the first pool in the path is necessary
                    payer: payer
                })
            );

            // decide whether to continue or terminate
            // 根据是否还有多个交易池对子，判断是否继续循环，还是退出
            if (hasMultiplePools) {
                // 因为此时，调用者的钱已经打给了本合约，所以下一次需要本合约来支付
                payer = address(this); // at this point, the caller has paid
                // 删掉前面23位字节（token+fee),留下剩余的字节
                params.path = params.path.skipToken();
            } else {
                // 若已经不再有多个交易池对子了，那么上面exactInputInternal返回的就是输出amountOut了。
                amountOut = params.amountIn;
                break;
            }
        }

        require(amountOut >= params.amountOutMinimum, 'Too little received');
    }

    // 执行一次精确的输出交换
    /// @dev Performs a single exact output swap
    function exactOutputInternal(
        uint256 amountOut,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) private returns (uint256 amountIn) {
        // allow swapping to the router address with address 0
        // 若收款人是0地址，那还不如给本合约地址
        if (recipient == address(0)) recipient = address(this);

        (address tokenOut, address tokenIn, uint24 fee) = data.path.decodeFirstPool();

        bool zeroForOne = tokenIn < tokenOut;

        (int256 amount0Delta, int256 amount1Delta) = getPool(tokenIn, tokenOut, fee).swap(
            recipient,
            zeroForOne,
            -amountOut.toInt256(),
            sqrtPriceLimitX96 == 0
                ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                : sqrtPriceLimitX96,
            abi.encode(data)
        );

        uint256 amountOutReceived;
        (amountIn, amountOutReceived) = zeroForOne
            ? (uint256(amount0Delta), uint256(-amount1Delta))
            : (uint256(amount1Delta), uint256(-amount0Delta));
        // it's technically possible to not receive the full output amount,
        // so if no price limit has been specified, require this possibility away
        if (sqrtPriceLimitX96 == 0) require(amountOutReceived == amountOut);
    }

    /// @inheritdoc ISwapRouter
    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    ) external payable override checkDeadline(params.deadline) returns (uint256 amountIn) {
        // avoid an SLOAD by using the swap return data
        amountIn = exactOutputInternal(
            params.amountOut,
            params.recipient,
            params.sqrtPriceLimitX96,
            SwapCallbackData({path: abi.encodePacked(params.tokenOut, params.fee, params.tokenIn), payer: msg.sender})
        );

        require(amountIn <= params.amountInMaximum, 'Too much requested');
        // has to be reset even though we don't use it in the single hop case
        amountInCached = DEFAULT_AMOUNT_IN_CACHED;
    }

    /// @inheritdoc ISwapRouter
    function exactOutput(
        ExactOutputParams calldata params
    ) external payable override checkDeadline(params.deadline) returns (uint256 amountIn) {
        // it's okay that the payer is fixed to msg.sender here, as they're only paying for the "final" exact output
        // swap, which happens first, and subsequent swaps are paid for within nested callback frames
        exactOutputInternal(
            params.amountOut,
            params.recipient,
            0,
            SwapCallbackData({path: params.path, payer: msg.sender})
        );

        amountIn = amountInCached;
        require(amountIn <= params.amountInMaximum, 'Too much requested');
        amountInCached = DEFAULT_AMOUNT_IN_CACHED;
    }
}
