// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Contrato principal para el intercambio simple de tokens
contract SimpleSwap is ERC20 {    
    // Direcciones de los tokens ERC20
    IERC20 public tokenA;
    IERC20 public tokenB;

    // Reservas de cada token en el contrato
    uint256 public reserveA;
    uint256 public reserveB;

    // Constructor que inicializa el token de liquidez (LP).
    constructor() ERC20("SimpleSwap LP", "SSLP") {}

    // Funcion para agregar liquidez
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
        // Verifica que la transaccion no haya expirado
        require(deadline >= block.timestamp, "SimpleSwap: EXPIRED");

        // Se establecen los tokens
        if (address(tokenA) == address(0) && address(tokenB) == address(0)) {
            tokenA = IERC20(_tokenA);
            tokenB = IERC20(_tokenB);
        }

        // Verifica que los tokens proporcionados coincidan con los del pool
        require(
            _tokenA == address(tokenA) && _tokenB == address(tokenB),
            "SimpleSwap: INVALID_TOKENS"
        );

        (uint256 _reserveA, uint256 _reserveB) = (reserveA, reserveB);

        if (_reserveA == 0 && _reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            // Calcula la cantidad optima de token B a agregar
            uint256 amountBOptimal = (amountADesired * _reserveB) / _reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    "SimpleSwap: INSUFFICIENT_B_AMOUNT"
                );
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                // Calcula la cantidad optima de token A a agregar
                uint256 amountAOptimal = (amountBDesired * _reserveA) / _reserveB;
                require(
                    amountAOptimal >= amountAMin,
                    "SimpleSwap: INSUFFICIENT_A_AMOUNT"
                );
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }

        // Transfiere los tokens desde el usuario al contrato
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        // Actualiza las reservas
        reserveA += amountA;
        reserveB += amountB;

        // Calcula la cantidad de tokens de liquidez a mintear
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min(
                (amountA * _totalSupply) / _reserveA,
                (amountB * _totalSupply) / _reserveB
            );
        }

        // mintea los tokens de liquidez
        require(liquidity > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);
    }

    // Funcion interna para calcular la raiz cuadrada
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

    // Funcion interna para obtener el minimo de dos números
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // Funcion para remover liquidez del pool
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        // Verifica que la transacción no haya expirado
        require(deadline >= block.timestamp, "SimpleSwap: EXPIRED");
        // Verifica que los tokens proporcionados coincidan con los del pool
        require(
            _tokenA == address(tokenA) && _tokenB == address(tokenB),
            "SimpleSwap: INVALID_TOKENS"
        );
	// Verifica que el usuario tenga suficientes tokens de liquidez
        require(balanceOf(msg.sender) >= liquidity, "SimpleSwap: INSUFFICIENT_LP_TOKEN_BURNED");

        (uint256 _reserveA, uint256 _reserveB, uint256 _totalSupply) = (reserveA, reserveB, totalSupply());

        // Calcula la cantidad de cada token a devolver
        amountA = (liquidity * _reserveA) / _totalSupply;
        amountB = (liquidity * _reserveB) / _totalSupply;

        // Verifica que las cantidades a devolver no sean menores a las minimas esperadas
        require(amountA >= amountAMin, "SimpleSwap: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "SimpleSwap: INSUFFICIENT_B_AMOUNT");

        // Quema los tokens de liquidez del usuario.
        _burn(msg.sender, liquidity);

        // Actualiza las reservas.
        reserveA -= amountA;
        reserveB -= amountB;

        // Transfiere los tokens de vuelta al usuario.
        tokenA.transfer(to, amountA);
        tokenB.transfer(to, amountB);
    }

    // Funcion para intercambiar una cantidad exacta de tokens de entrada por tokens de salida
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        // Verifica que la transaccion no haya expirado
        require(deadline >= block.timestamp, "SimpleSwap: EXPIRED");
        require(path.length == 2, "SimpleSwap: INVALID_PATH");
        require(
            (path[0] == address(tokenA) && path[1] == address(tokenB)) ||
                (path[0] == address(tokenB) && path[1] == address(tokenA)),
            "SimpleSwap: INVALID_PATH"
        );

        // Determina las reservas de entrada y salida
        (uint256 _reserveIn, uint256 _reserveOut) = (path[0] == address(tokenA))
            ? (reserveA, reserveB)
            : (reserveB, reserveA);

        // Calcula la cantidad de tokens de salida
        uint256 amountOut = getAmountOut(amountIn, _reserveIn, _reserveOut);
        require(amountOut >= amountOutMin, "SimpleSwap: INSUFFICIENT_OUTPUT_AMOUNT");

        // Transfiere los tokens de entrada desde el usuario al contrato
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);


        if (path[0] == address(tokenA)) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        // Transfiere los tokens de salida al destinatario
        IERC20(path[1]).transfer(to, amountOut);
    }

    // Calcula la cantidad de salida para una cantidad de entrada dada
    function getAmountOut(
        uint256 amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        require(_reserveIn > 0 && _reserveOut > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY");

        // Fees del 0.3%.
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = (_reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // Obtiene el precio de un token en relacion al otro
    function getPrice(
        address _tokenA,
        address _tokenB
    ) external view returns (uint256 price) {
        require(
            _tokenA == address(tokenA) && _tokenB == address(tokenB),
            "SimpleSwap: INVALID_TOKENS"
        );
        require(reserveA > 0, "SimpleSwap: INVALID_RESERVE");
        // Devuelve el precio
        return (reserveB * 1e18) / reserveA;
    }
}