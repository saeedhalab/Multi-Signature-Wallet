const MultiSigWallet = artifacts.require("MultiSigWallet");
const utils = require("./Helper/Utils");
contract("MultiSigWallet", (accounts) => {
    let [alice, bob, jack, pep, saeed] = accounts;
    let contractInstance;
    let owners = [accounts[0], accounts[1], accounts[2]];
    let submitTransaction;
    let TxId;
    beforeEach(async () => {

        //deploy contract with 3 owners and atleast 2 confirm for excute ownerForm
        contractInstance = await MultiSigWallet.new(owners, 2);

        submitTransaction = await contractInstance.submitTransaction(pep, 30, web3.utils.asciiToHex("confirm"), { from: alice });

        TxId = submitTransaction.logs[0].args.txIndex.toNumber();
    })

    it("Submit New Transaction", async () => {
        const transaction = await contractInstance.getTransaction(TxId);

        assert.equal(transaction.to, pep);
    })
    it("Cant Anyone Submit Transaction", async () => {

        await utils.shouldThrow(contractInstance.submitTransaction(pep, 50, web3.utils.asciiToHex("data"), { from: saeed }));
    })
    it("Confirm Transaction", async () => {
        await contractInstance.confirmTransaction(TxId, { from: bob });

        //cant owner confirm twice transaction
        await utils.shouldThrow(contractInstance.confirmTransaction(TxId, { from: bob }));

        const transaction = await contractInstance.getTransaction(TxId);

        assert.equal(transaction.numConfirmation, 1);
    })
    it("Revoke Confirmed Transaction ", async () => {
        await contractInstance.confirmTransaction(TxId, { from: bob });

        await contractInstance.revokeTransaction(TxId, { from: bob });

        const transaction = await contractInstance.getTransaction(TxId);

        assert.equal(transaction.numConfirmation, 0)
    })
    it("cant owner revoke confirm transaction when not confirmed ", async () => {
        await utils.shouldThrow(contractInstance.revokeTransaction(TxId, { from: bob }));
    })
    xit("Excuted Transaction", async () => {
        await contractInstance.confirmTransaction(TxId, { from: alice });
        await contractInstance.confirmTransaction(TxId, { from: bob });
        await contractInstance.confirmTransaction(TxId, { from: jack });
        await contractInstance.excuteTransaction(TxId, { from: alice });
    })
})