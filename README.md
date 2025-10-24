# Мост между сетями

### Тесты

Для контрактов моста и токена разработы unit-тесты, а также интеграционные тесты

Для запуска всех тестов:
```
forge test
```

Должны получить:

<img width="754" height="843" alt="Screenshot 2025-10-24 at 4 05 48 AM" src="https://github.com/user-attachments/assets/64655423-12fa-49df-91c0-7361e4e21c80" />


### Тестирование в локальное среде

Структура .env:
```
PRIVATE_KEY=
ADDRESS=

BRIDGE_ADDRESS=

BRIDGE_DEPOSIT=
```
PRIVATE_KEY, ADDRESS - Приватный ключ и адрес кошелька владельца
BRIDGE_ADDRESS - Адрес моста для операции минт
BRIDGE_DEPOSIT - Адрес моста для вызова депозит

Запускаем сервер:
```
anvil
```

Вызывам деплой 2 раза, каждый вызов создает токен и мост в сети:

```
forge script scripts/Deploy.sol:Deploy --fork-url http://localhost:8545 --broadcast
```

<img width="912" height="251" alt="Screenshot 2025-10-24 at 4 14 29 AM" src="https://github.com/user-attachments/assets/e0080200-e16c-472d-95e7-18497d4b3809" />
<img width="911" height="221" alt="Screenshot 2025-10-24 at 4 14 14 AM" src="https://github.com/user-attachments/assets/f7f95207-8d62-4a27-ad0f-aa82cbca482d" />

Вызываем минт два раза указывая адрес в BRIDGE_ADDRESS:

```
forge script scripts/Mint.sol:Mint --fork-url http://localhost:8545 --broadcast
```
<img width="736" height="65" alt="Screenshot 2025-10-24 at 4 17 43 AM" src="https://github.com/user-attachments/assets/bca3db59-7831-44b7-a6ff-4e16f7017db9" />
<img width="709" height="69" alt="Screenshot 2025-10-24 at 4 18 02 AM" src="https://github.com/user-attachments/assets/68985a49-78c7-4667-b9c8-29f3ce41da90" />


Заполняем конфиг в server.py:

```
CONFIG = {
    'first_network': {
        'rpc': 'http://localhost:8545',
        'contract_address': '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
        'abi_path': 'source_contract_abi.json',
        'chain_id': 11155111 
    },
    'second_network': {
        'rpc': 'http://localhost:8545', 
        'contract_address': '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9',
        'abi_path': 'source_contract_abi.json',
        'chain_id': 11155111
    },
    'private_key': '',
    'poll_interval': 2
}
```

Переходим в папку сервер и запускаем его:
```
python server.py
```

Вызываем депозит в сети указав адрес в BRIDGE_DEPOSIT:

```
forge script scripts/TryDeposit.sol --fork-url http://localhost:8545 --broadcast 
```

Сервер получил event о депозите и вызвал release
<img width="987" height="143" alt="Screenshot 2025-10-24 at 4 23 19 AM" src="https://github.com/user-attachments/assets/a9095550-28f3-4ea4-a71f-98976b924b62" />


### Тестирование на тестнете

Шаги запуска такие же как для локальной, только указываем настоящий rpc

Контракты 1 токена и моста:

Токен: https://sepolia.etherscan.io/address/0x1F3165C160FB183D2eeb48E45FF0Ef67b519E091

Мост: https://sepolia.etherscan.io/address/0x6BDe0416a7b8b8672699cE80b16f8b4668649dBd

Контракты 2 токена и моста:

Токен: https://sepolia.etherscan.io/address/0x1CEEe2c2495D395f5aD587fa3C90a8158fDD2517

Мост: https://sepolia.etherscan.io/address/0x828014441e9926E9B3F2Ee1Fc5843cd61df51e52

Транзакции минта:

https://sepolia.etherscan.io/tx/0x590540d9d949d23a1086980b1e4238f325437faff884b34c1c6ed6df51b7d739

https://sepolia.etherscan.io/tx/0xae1276198e57886318a14cf3935c2b769f588a73ad1591ad855ad747e4a2d763

Транзакции deposit и release:

https://sepolia.etherscan.io/tx/0x0073c37d736d6a35c1d69b12be469eec172ec305970f81f7488f598dac4aa46c

https://sepolia.etherscan.io/tx/0x367a89aa7b604f73cb49533a9d6c0f7698d8d2dde30faf7536928309d1ca6ddb

<img width="890" height="171" alt="Screenshot 2025-10-24 at 4 37 46 AM" src="https://github.com/user-attachments/assets/aff1f4b3-ebc2-4ec5-93a6-625964173ff7" />


