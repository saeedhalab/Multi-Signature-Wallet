const MultiSigWallet = artifacts.require("MultiSigWallet");
const utils = require("./Helper/Utils");
contract("MultiSigWallet", (accounts) => {
    let [alice, bob, jack, pep, saeed] = accounts;
    let contractInstance;
    let owners = [accounts[0], accounts[1], accounts[2]];
    beforeEach(async () => {
        contractInstance = await MultiSigWallet.new(owners, 3);
    })
    it("should be able to submit new transacrion", async () => {

        const result = await contractInstance.submitTransaction(pep, 50, web3.utils.asciiToHex("data"), { from: alice });
        const txId = result.logs[0].args.txId.toNumber();
        const transaction = await contractInstance.getTransaction(txId);
        assert.equal(transaction.to, pep);
    })
    it("should just owner can submit new transaction", async () => {
        await utils.shouldThrow(contractInstance.submitTransaction(pep, 50, web3.utils.asciiToHex("data"), { from: saeed }));
    })
    it("should be owner to confirm transaction", async () => {
        const result = await contractInstance.submitTransaction(pep, 30, web3.utils.asciiToHex("confirm"), { from: bob });
        const TxId = result.logs[0].args.txId.toNumber();
        await contractInstance.confirmTransaction(TxId, { from: bob });
        const transaction = await contractInstance.getTransaction(TxId);
        assert.equal(transaction.numConfirmation, 1);
    })
    it("cant owner confirm twice transaction", async () => {
        const result = await contractInstance.submitTransaction(pep, 30, web3.utils.asciiToHex("confirm"), { from: bob });
        const TxId = result.logs[0].args.txId.toNumber();
        await contractInstance.confirmTransaction(TxId, { from: bob });
        await utils.shouldThrow(contractInstance.confirmTransaction(TxId, { from: bob }));
    })
})