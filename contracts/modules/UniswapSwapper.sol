// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/**
 * @title UniswapSwapper
 * @notice Handles conversion of liquidated assets or collateral into stablecoins.
 * @dev Fixes: Dynamic fees, MEV-protected deadlines, and SafeERC20 allowance resets.
 */
contract UniswapSwapper is Ownable {
    using SafeERC20 for IERC20;

    ISwapRouter public immutable swapRouter;

    event SwapExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    constructor(address _swapRouter) Ownable(msg.sender) {
        require(_swapRouter != address(0), "Invalid router");
        swapRouter = ISwapRouter(_swapRouter);
    }

    /**
     * @notice Swaps tokenIn for tokenOut via Uniswap V3.
     * @param tokenIn Address of the asset to sell.
     * @param tokenOut Address of the asset to buy (e.g., USDC).
     * @param amountIn Amount of tokenIn to swap.
     * @param amountOutMin Minimum amount of tokenOut to receive (slippage protection).
     * @param poolFee The Uniswap V3 pool fee (500, 3000, 10000).
     * @param deadline Transaction deadline (must be provided by off-chain signer to prevent MEV).
     */
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint24 poolFee,
        uint256 deadline
    ) external onlyOwner returns (uint256 amountOut) {
        require(amountIn > 0, "Amount must be > 0");
        require(deadline >= block.timestamp, "Deadline expired");

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Handle non-standard tokens like USDT that require zero-allowance reset
        IERC20(tokenIn).safeApprove(address(swapRouter), 0);
        IERC20(tokenIn).safeApprove(address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: poolFee,
            recipient: msg.sender,
            deadline: deadline,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });

        amountOut = swapRouter.exactInputSingle(params);

        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut);
    }
}