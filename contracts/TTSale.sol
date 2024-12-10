// SPDX-License-Identifier: PropietarioUnico
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./TTERC20.sol";

contract TTSale is Ownable, ReentrancyGuard {
    TTERC20 public token;

    // Precio: 1 ETH = 10,000 tokens con 8 decimales
    // 10,000 * 10^8 = 1,000,000,000,000 (1e12)
    uint256 public constant TOKENS_PER_ETH = 10_000 * 10**8;
    // 10% del total anterior:
    uint256 public constant STAKING_AMOUNT = 1_100_000 * 10**8; // (TOKENS_PER_ETH / 10)

    bool public stakingMintDone;

    // Custom errors para ahorrar gas
    error AlreadyMintedForStaking();
    error NotEnoughBalance();
    error NotEnoughETH();
    error NotEnoughTokens();
    error TransferFailed();
    error NoETHSent();

    event MintForStaking(address indexed stakingContract, uint256 stakingAmount);
    event TokensBought(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event WithdrawETH(address indexed owner, uint256 amount);
    event WithdrawAllETH(address indexed owner, uint256 amount);

    constructor(address _token) Ownable(msg.sender) {
        token = TTERC20(_token);
    }

    // Destinar el 10% al Staking sin hacer cálculos en runtime
    function mintForStaking(address stakingContract) external onlyOwner {
        if (stakingMintDone) revert AlreadyMintedForStaking();

        // Mint directo de STAKING_AMOUNT
        token.mint(stakingContract, STAKING_AMOUNT);
        stakingMintDone = true;

        emit MintForStaking(stakingContract, STAKING_AMOUNT);
    }

    // Comprar tokens con ETH: 
    // tokensToMint = (msg.value * TOKENS_PER_ETH) / 1e18
    function buyTokens() external payable nonReentrant {
        if (msg.value == 0) revert NoETHSent();
        // Multiplicaciones y divisiones simples, el compilador ya optimiza
        uint256 tokensToMint = (msg.value * TOKENS_PER_ETH) / 1e18;
        if (tokensToMint == 0) revert NotEnoughETH();

        token.mint(msg.sender, tokensToMint);

        emit TokensBought(msg.sender, msg.value, tokensToMint);
    }

    // Retirar ETH acumulado (monto específico)
    function withdrawETH(uint256 amount) external onlyOwner {
        if (amount > address(this).balance) revert NotEnoughBalance();

        (bool success, ) = owner().call{value: amount}("");
        if (!success) revert TransferFailed();

        emit WithdrawETH(owner(), amount);
    }

    // Retirar todo el ETH acumulado
    function withdrawAllETH() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = owner().call{value: balance}("");
        if (!success) revert TransferFailed();

        emit WithdrawAllETH(owner(), balance);
    }

    // fallback para recibir ETH sin data
    receive() external payable {
        // vacío
    }
}
