// SPDX-License-Identifier: PropietarioUnico
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is ReentrancyGuard, Ownable {
    IERC20 public token; // mismo token para staking y recompensas

    // Constantes para mayor claridad
    // Nota: 10 segundos por epoch es sólo un ejemplo. Ajustar a 43200 (12h) en producción.
    uint256 public constant EPOCH_DURATION = 10; 

    uint256 public constant PRECISION = 1e8;

    // Suponemos ya transferidos 1,100,000 tokens al contrato antes de startRewards
    // 1,100,000 * 10^8 = 110,000,000,000,000 (1.1e14)
    uint256 public totalRewardsFor4Years = 1_100_000 * 10**8;

    // Supuestamente pone 4 años aunque en realidad hacer el cálculo para 1500 días.
    // Que son 4 años y poco... 
    uint256 public totalEpochsIn4Years = 12_960_000; 
    uint256 public rewardRatePerEpoch;

    uint256 public totalStaked;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTimestamp;

    bool public rewardsStarted; // false = pausado, true = iniciado

    struct StakeInfo {
        uint256 amount; 
        uint256 userRewardPerTokenPaid; 
        uint256 accruedRewards; 
    }

    mapping(address => StakeInfo) public stakes;

    // Eventos
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsStarted(uint256 startTime);
    event Exited(address indexed user, uint256 stakedAmount, uint256 rewardPaid);

    // Custom errors para ahorrar gas
    error AlreadyStarted();
    error ContractNotStarted();
    error CannotStakeZero();
    error NotEnoughStaked();
    error NoTokensStaked();
    error NotEnoughTokensForRewards();

    constructor(address _token) Ownable(msg.sender) {
        token = IERC20(_token);
        rewardRatePerEpoch = totalRewardsFor4Years / totalEpochsIn4Years;
        // Al desplegar, rewardsStarted = false (pausado)
    }

    // Inicia las recompensas y "despausa" el contrato
    function startRewards() external onlyOwner {
        if (rewardsStarted) revert AlreadyStarted();
        uint256 balance = token.balanceOf(address(this));
        if (balance < totalRewardsFor4Years) revert NotEnoughTokensForRewards();

        rewardsStarted = true; 
        lastUpdateTimestamp = block.timestamp;

        emit RewardsStarted(block.timestamp);
    }

    function updateReward() internal {
        if (!rewardsStarted || totalStaked == 0 || totalRewardsFor4Years == 0) {
            return;
        }

        uint256 timeSinceLastUpdate = block.timestamp - lastUpdateTimestamp;
        if (timeSinceLastUpdate >= EPOCH_DURATION) {
            uint256 epochsPassed = timeSinceLastUpdate / EPOCH_DURATION;
            uint256 totalToDistribute = epochsPassed * rewardRatePerEpoch;
            if (totalToDistribute > totalRewardsFor4Years) {
                totalToDistribute = totalRewardsFor4Years;
            }

            rewardPerTokenStored += (totalToDistribute * PRECISION) / totalStaked;
            totalRewardsFor4Years -= totalToDistribute;
            lastUpdateTimestamp += epochsPassed * EPOCH_DURATION;
        }
    }

    function earned(address account) public view returns (uint256) {
        StakeInfo memory staker = stakes[account];

        uint256 tempRewardPerToken = rewardPerTokenStored;
        if (rewardsStarted && totalStaked > 0 && totalRewardsFor4Years > 0) {
            uint256 timeSinceLastUpdate = block.timestamp - lastUpdateTimestamp;
            if (timeSinceLastUpdate >= EPOCH_DURATION) {
                uint256 epochsPassed = timeSinceLastUpdate / EPOCH_DURATION;
                uint256 totalToDistribute = epochsPassed * rewardRatePerEpoch;
                if (totalToDistribute > totalRewardsFor4Years) {
                    totalToDistribute = totalRewardsFor4Years;
                }
                tempRewardPerToken += (totalToDistribute * PRECISION) / totalStaked;
            }
        }

        // Cálculo: recompensas = (staker.amount * (temp - staker.userRewardPerTokenPaid))/PRECISION + staker.accruedRewards
        return (staker.amount * (tempRewardPerToken - staker.userRewardPerTokenPaid)) / PRECISION + staker.accruedRewards;
    }

    function stake(uint256 amount) external nonReentrant {
        if (!rewardsStarted) revert ContractNotStarted();
        if (amount == 0) revert CannotStakeZero();

        updateReward();

        StakeInfo storage staker = stakes[msg.sender];
        uint256 pending = earned(msg.sender);

        staker.accruedRewards = pending;
        staker.userRewardPerTokenPaid = rewardPerTokenStored;

        token.transferFrom(msg.sender, address(this), amount);
        totalStaked += amount;
        staker.amount += amount;

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (!rewardsStarted) revert ContractNotStarted();
        if (amount == 0) revert CannotStakeZero();

        StakeInfo storage staker = stakes[msg.sender];
        if (staker.amount < amount) revert NotEnoughStaked();

        updateReward();
        uint256 pending = earned(msg.sender);

        staker.accruedRewards = pending;
        staker.userRewardPerTokenPaid = rewardPerTokenStored;

        staker.amount -= amount;
        totalStaked -= amount;
        token.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function claim() external nonReentrant {
        if (!rewardsStarted) revert ContractNotStarted();

        updateReward();
        StakeInfo storage staker = stakes[msg.sender];
        uint256 reward = earned(msg.sender);
        
        if (reward > 0) {
            staker.accruedRewards = 0;
            staker.userRewardPerTokenPaid = rewardPerTokenStored;
            token.transfer(msg.sender, reward);

            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external nonReentrant {
        if (!rewardsStarted) revert ContractNotStarted();

        updateReward();
        StakeInfo storage staker = stakes[msg.sender];
        
        uint256 reward = earned(msg.sender);
        uint256 stakedBalance = staker.amount;
        if (stakedBalance == 0) revert NoTokensStaked();

        // Resetear info
        staker.accruedRewards = 0;
        staker.userRewardPerTokenPaid = rewardPerTokenStored;
        staker.amount = 0;
        totalStaked -= stakedBalance;

        // Devolver principal
        token.transfer(msg.sender, stakedBalance);

        uint256 rewardPaid = 0;
        if (reward > 0) {
            token.transfer(msg.sender, reward);
            rewardPaid = reward;
            emit RewardPaid(msg.sender, reward);
        }

        emit Exited(msg.sender, stakedBalance, rewardPaid);
    }
}
