// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title Interface for WETH9
interface IWETH9 is IERC20 {
    /// @notice Deposit ether to get wrapped ether
    // 存入 ETH,必须payable
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether
    // 提取包裹了的ETH,包裹成ERC20标准的代币
    function withdraw(uint256) external;
}
