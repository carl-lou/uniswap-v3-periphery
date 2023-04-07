// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import '../interfaces/IMulticall.sol';

// 多次 委托调用
/// @title Multicall
/// @notice Enables calling multiple methods in a single call to the contract
abstract contract Multicall is IMulticall {
    /// @inheritdoc IMulticall
    function multicall(bytes[] calldata data) public payable override returns (bytes[] memory results) {
        // 先创建字节数组 的数组，定义数量，下面对应返回
        results = new bytes[](data.length);
        // 开启循环
        for (uint256 i = 0; i < data.length; i++) {
            // 委托调用
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                // 如果返回结果的长度小于68，那说明没有回复消息
                if (result.length < 68) revert();
                assembly {
                    // 将签名哈希切片
                    result := add(result, 0x04)
                }
                // bytes转换成字符串类型
                revert(abi.decode(result, (string)));
            }

            // 返回结果加入到数组里
            results[i] = result;
        }
    }
}
