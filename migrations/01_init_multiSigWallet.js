const MultiSigWallet = artifacts.require("MultiSigWallet");

module.exports =function (deployer, network, accounts) {
    deployer.deploy(MultiSigWallet,["0x68C5051F25Ef386Fc60fb985E4536A9F3B2eC955","0x319294e2E1744b31F7d9664a6dB3c2A590C55ecC","0x0E38Bf2d466B77eD6FDaD2A0AdD32Ec7a73Cf631"],2);
}