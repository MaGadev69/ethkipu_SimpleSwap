pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MyToken
 * @author Gasquez_Jonatan
 * @notice A basic ERC20 token with a minting function.
 */
contract MyToken is ERC20 {
    constructor(string memory sym, string memory name)
        ERC20(name, sym)
    {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
