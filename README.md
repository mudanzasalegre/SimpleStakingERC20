# Proyecto Token + Tienda + Staking

Este repositorio contiene tres contratos principales que interactúan entre sí para ofrecer un ecosistema de token ERC20 con:

1. Un token con suministro máximo (`TTERC20`).
2. Una "tienda" (`TTSale`) que vende tokens a cambio de ETH, controla la acuñación dentro del límite máximo y destina un 10% de los tokens al contrato de staking.
3. Un contrato de `Staking` que distribuye recompensas durante 4 años a los participantes que depositen (stake) sus tokens.

## Características

- **TTERC20**:  
  - Máximo suministro de 11,000,000 tokens con 8 decimales.  
  - Permite acuñar tokens siempre que no se supere el máximo y el minteo solo puede hacerlo el `owner`.  
  - Inicialmente el `owner` es la cuenta que despliega el contrato.

- **TTSale (tienda)**:  
  - Recibe el `ownership` del token `TTERC20` tras el despliegue para poder acuñar tokens y venderlos.  
  - Vende tokens a razón de 1 ETH = 11,000 tokens (ajustable si se modifica el contrato).  
  - Destina el 10% del total (1,100,000 tokens) al contrato de Staking mediante `mintForStaking()`.  
  - Permite al `owner` retirar el ETH acumulado por las ventas de tokens.

- **Staking**:  
  - Recibe 1,100,000 tokens desde la `tienda` para usarlos como recompensas.  
  - Comienza pausado; no se puede hacer stake ni reclamar recompensas hasta que el `owner` llame a `startRewards()`.  
  - Distribuye las recompensas proporcionalmente entre los participantes cada epoch (por defecto cada 10 segundos en este ejemplo; ajustable a 12 horas según necesidad).  
  - Permite `stake`, `withdraw`, `claim` y `exit`.  
  - Controla la tasa de emisión a lo largo del tiempo (4 años, configurados mediante `totalEpochsIn4Years`).
  - **ACTUALMENTE**: El sistema está pensado para 1500 días, que son alrededor de 4 años y poco. De ahí el valor de totalEpochsIn4Years es de 12.960.000, porque el EPOCH_DURATION es de 10 segundos. Está configurado así para que se vayan produciendo cambios más rápidamente en un entorno de pruebas. En producción se debe ajustar antes el sistema automático de recompensas.
  - El sistema de nombres es algo arbitrario. Para la variable 'totalEpochsIn4Years', que corresponde a esos 1500 dias en segundos, podríamos haberla llamado 'bicicleta' y el sistema la hubiera interpretado igual. Cosas de la abstracción.

## Dependencias

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)

Instalar dependencias (ejemplo con npm):

```bash
npm install @openzeppelin/contracts
```

## Despliegue

### Orden de despliegue sugerido

1. **Desplegar `TTERC20`**  
    ```javascript
    const TTERC20 = await ethers.getContractFactory("TTERC20");
    const myToken = await TTERC20.deploy();
    await myToken.deployed();
    console.log("TTERC20 deployed at:", myToken.address);
    ```

2. **Desplegar `TTSale` (tienda)**  
    ```javascript
    const TTSale = await ethers.getContractFactory("TTSale");
    const tokenStore = await TTSale.deploy(myToken.address);
    await tokenStore.deployed();
    console.log("TTSale deployed at:", tokenStore.address);
    ```

3. **Transferir el ownership del token a la tienda**  
    ```javascript
    await myToken.transferOwnership(tokenStore.address);
    ```

4. **Desplegar el contrato de `Staking`**  
    ```javascript
    const Staking = await ethers.getContractFactory("Staking");
    const staking = await Staking.deploy(myToken.address);
    await staking.deployed();
    console.log("Staking deployed at:", staking.address);
    ```

5. **Destinar el 10% al Staking**  
    ```javascript
    await tokenStore.mintForStaking(staking.address);
    ```
    Esto acuñará los 1,100,000 tokens al contrato de `Staking`.

6. **Iniciar las recompensas en el Staking**  
    ```javascript
    await staking.startRewards();
    ```
    Asegúrate de que el Staking tenga los tokens antes de llamar `startRewards()`.

## Uso

- **Comprar tokens con ETH:**
    ```javascript
    // Comprar tokens enviando 0.1 ETH
    await tokenStore.connect(user).buyTokens({ value: ethers.utils.parseEther("0.1") });
    ```

- **Hacer stake en el Staking:**
    ```javascript
    await myToken.connect(user).approve(staking.address, ethers.utils.parseUnits("1000", 8));
    await staking.connect(user).stake(ethers.utils.parseUnits("1000", 8));
    ```

- **Reclamar recompensas:**
    ```javascript
    await staking.connect(user).claim();
    ```

- **Retirar principal (withdraw) o salir completamente (exit):**
    ```javascript
    // Retira parte del stake
    await staking.connect(user).withdraw(ethers.utils.parseUnits("500", 8));
    
    // Sale del todo, retira principal y reclama recompensas
    await staking.connect(user).exit();
    ```

- **Owner retira ETH del `TTSale`:**
    ```javascript
    await tokenStore.withdrawETH(ethers.utils.parseEther("10")); // Retira 10 ETH
    await tokenStore.withdrawAllETH(); // Retira todo el ETH restante
    ```

## Ajustes

- Cambia `EPOCH_DURATION` en el Staking a `43200` para tener epochs de 12 horas.
- Ajusta `TOKENS_PER_ETH` en la tienda para cambiar el precio del token.
- Usa `Hardhat`, `Truffle` o `Foundry` para probar, desplegar y verificar.

## Licencia

Este código se distribuye bajo una licencia de uso restringido, denominada aquí como `PropietarioUnico`. Esto implica:

- **Derechos de copia y modificación:**  
  Solo el propietario original del código (o la entidad designada por este) tiene el derecho de copiar, modificar, distribuir o sublicenciar el software en cualquier forma.

- **Uso comercial y no comercial:**  
  Se autoriza el uso del código exclusivamente a la persona o entidad propietaria, ya sea con fines comerciales o no comerciales, siempre que no se vulnere ninguna otra disposición.

- **Responsabilidad limitada:**  
  Este código se proporciona "tal cual", sin garantías de ningún tipo, ya sean expresas o implícitas. El propietario no será responsable por ningún daño directo, indirecto, incidental, especial o consecuente que surja del uso o la imposibilidad de uso del software.

- **Cambio de licencia:**  
  El propietario puede, a su sola discreción, cambiar la licencia a cualquier otra en el futuro, notificando a los usuarios con la debida anticipación.


