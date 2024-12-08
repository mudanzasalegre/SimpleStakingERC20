// SPDX-License-Identifier: PropietarioUnico
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TTERC20 is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 11_000_000 * 10**8; // 11 millones * 10^8 (decimales)

    constructor() ERC20("TTERC20", "TT20") Ownable(msg.sender) {
        // Constructor "en blanco", no mint inicial
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }
}