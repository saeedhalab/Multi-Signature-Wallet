const MultiSigWallet = artifacts.require("MultiSigWallet");

contract("MultiSigWallet", (accounts) => {
    let [alice, bob, jack, pep, saeed] = accounts;
    let contractInstance;
    let owners = [accounts[0], accounts[1], accounts[2]];
    beforeEach(async () => {
        contractInstance = await MultiSigWallet.new(owners, 3);
    })
    it("should be able to submit new transacrion", async () => {

        await contractInstance.submitTransaction(pep, 50, web3.utils.asciiToHex("data"), { from: alice });
        const transaction = await contractInstance.getTransaction(0);
        assert.equal(transaction.to, pep);
    })
})