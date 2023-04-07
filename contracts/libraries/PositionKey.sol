// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

library PositionKey {
    // 返回核心库中头寸的键
    /// @dev Returns the key of the position in the core library
    function compute(
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bytes32) {
        // abi加密后，哈希加密
        return keccak256(abi.encodePacked(owner, tickLower, tickUpper));
    }
}
