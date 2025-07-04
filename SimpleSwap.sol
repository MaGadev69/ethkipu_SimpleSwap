// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimpleSwap
 * @author Gasquez_Jonatan
 */
contract SimpleSwap is ERC20 {
    /// @notice The address of the first token in the liquidity pool.
    IERC20 public tokenA;
    /// @notice The address of the second token in the liquidity pool.
    IERC20 public tokenB;

    /// @notice The total reserve of tokenA held by this contract.
    uint256 public reserveA;
    /// @notice The total reserve of tokenB held by this contract.
    uint256 public reserveB;

    /// @notice Initializes the contract, setting the name and symbol for the LP token.
    constructor() ERC20("SimpleSwap LP", "SSLP") {}

    /**
     * @notice Adds liquidity to the pool for a pair of tokens.
     * @dev If the pool is empty, the initial token ratio is set. Otherwise, liquidity is added based on the existing ratio. Mints LP tokens to the provider.
     * @param _tokenA The address of tokenA.
     * @param _tokenB The address of tokenB.
     * @param amountADesired The amount of tokenA the user wishes to add.
     * @param amountBDesired The amount of tokenB the user wishes to add.
     * @param amountAMin The minimum amount of tokenA to add, for slippage protection.
     * @param amountBMin The minimum amount of tokenB to add, for slippage protection.
     * @param to The address that will receive the LP tokens.
     * @param deadline The timestamp after which the transaction will be reverted.
     * @return amountA The actual amount of tokenA added.
     * @return amountB The actual amount of tokenB added.
     * @return liquidity The amount of LP tokens minted.
     */
    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(deadline >= block.timestamp, "SimpleSwap: EXPIRED");

        if (address(tokenA) == address(0) && address(tokenB) == address(0)) {
            tokenA = IERC20(_tokenA);
            tokenB = IERC20(_tokenB);
        }

        require(
            _tokenA == address(tokenA) && _tokenB == address(tokenB),
            "SimpleSwap: INVALID_TOKENS"
        );

        (uint256 _reserveA, uint256 _reserveB) = (reserveA, reserveB);

        if (_reserveA == 0 && _reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            uint256 amountBOptimal = (amountADesired * _reserveB) / _reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    "SimpleSwap: INSUFFICIENT_B_AMOUNT"
                );
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = (amountBDesired * _reserveA) / _reserveB;
                require(
                    amountAOptimal >= amountAMin,
                    "SimpleSwap: INSUFFICIENT_A_AMOUNT"
                );
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        reserveA += amountA;
        reserveB += amountB;

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min(
                (amountA * _totalSupply) / _reserveA,
                (amountB * _totalSupply) / _reserveB
            );
        }

        require(liquidity > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);
    }

    /// @dev Internal function to calculate the square root of a number.
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /// @dev Internal function to find the minimum of two numbers.
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Removes liquidity from the pool.
     * @dev Burns the user's LP tokens and sends them a proportional amount of tokenA and tokenB from the reserves.
     * @param _tokenA The address of tokenA.
     * @param _tokenB The address of tokenB.
     * @param liquidity The amount of LP tokens to burn.
     * @param amountAMin The minimum amount of tokenA to receive, for slippage protection.
     * @param amountBMin The minimum amount of tokenB to receive, for slippage protection.
     * @param to The address that will receive the underlying tokens.
     * @param deadline The timestamp after which the transaction will be reverted.
     * @return amountA The actual amount of tokenA sent to the user.
     * @return amountB The actual amount of tokenB sent to the user.
     */
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        require(deadline >= block.timestamp, "SimpleSwap: EXPIRED");
        require(
            _tokenA == address(tokenA) && _tokenB == address(tokenB),
            "SimpleSwap: INVALID_TOKENS"
        );
        require(balanceOf(msg.sender) >= liquidity, "SimpleSwap: INSUFFICIENT_LP_TOKEN_BURNED");

        (uint256 _reserveA, uint256 _reserveB, uint256 _totalSupply) = (reserveA, reserveB, totalSupply());

        amountA = (liquidity * _reserveA) / _totalSupply;
        amountB = (liquidity * _reserveB) / _totalSupply;

        require(amountA >= amountAMin, "SimpleSwap: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "SimpleSwap: INSUFFICIENT_B_AMOUNT");

        _burn(msg.sender, liquidity);

        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(to, amountA);
        tokenB.transfer(to, amountB);
    }

    /**
     * @notice Swaps an exact amount of an input token for as much as possible of an output token.
     * @param amountIn The exact amount of the input token to send.
     * @param amountOutMin The minimum amount of the output token to receive, for slippage protection.
     * @param path An array of token addresses representing the swap route. Must be 2 addresses.
     * @param to The address that will receive the output tokens.
     * @param deadline The timestamp after which the transaction will be reverted.
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        require(deadline >= block.timestamp, "SimpleSwap: EXPIRED");
        require(path.length == 2, "SimpleSwap: INVALID_PATH");
        require(
            (path[0] == address(tokenA) && path[1] == address(tokenB)) ||
                (path[0] == address(tokenB) && path[1] == address(tokenA)),
            "SimpleSwap: INVALID_PATH"
        );

        (uint256 _reserveIn, uint256 _reserveOut) = (path[0] == address(tokenA))
            ? (reserveA, reserveB)
            : (reserveB, reserveA);

        uint256 amountOut = getAmountOut(amountIn, _reserveIn, _reserveOut);
        require(amountOut >= amountOutMin, "SimpleSwap: INSUFFICIENT_OUTPUT_AMOUNT");

        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);

        if (path[0] == address(tokenA)) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        IERC20(path[1]).transfer(to, amountOut);
    }

    /**
     * @notice Calculates the amount of an output token to receive for a given amount of an input token.
     * @dev Applies a 0.3% fee to the input amount before calculation.
     * @param amountIn The amount of the input token.
     * @param _reserveIn The reserve of the input token in the pool.
     * @param _reserveOut The reserve of the output token in the pool.
     * @return amountOut The calculated amount of the output token.
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        require(_reserveIn > 0 && _reserveOut > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = (_reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /**
     * @notice Calculates the price of tokenA in terms of tokenB.
     * @param _tokenA The address of tokenA.
     * @param _tokenB The address of tokenB.
     * @return price The price of tokenA denominated in tokenB, scaled by 1e18.
     */
    function getPrice(
        address _tokenA,
        address _tokenB
    ) external view returns (uint256 price) {
        require(
            _tokenA == address(tokenA) && _tokenB == address(tokenB),
            "SimpleSwap: INVALID_TOKENS"
        );
        require(reserveA > 0, "SimpleSwap: INVALID_RESERVE");
        return (reserveB * 1e18) / reserveA;
    }
}
