const MultiSigWallet = artifacts.require("MultiSigWallet");
const utils = require("./Helper/Utils");
contract("MultiSigWallet", (accounts) => {
  let [alice, bob, jack, pep, saeed] = accounts;
  let contractInstance;
  
  //alice - bob -jack are owners
  let owners = [accounts[0], accounts[1], accounts[2]];
  let submitTransaction;
  let txId;
  beforeEach(async () => {
    //deploy contract with 0.1ETH  3 owners and atleast 2 confirm for excute transaction
    contractInstance = await MultiSigWallet.new(owners, 2, {
      value: 100_000_000_000_000_000,
    });

    submitTransaction = await contractInstance.submitTransaction(
      pep,
      100_000_000_000_000_00n,
      {
        from: alice,
      }
    );

    txId = submitTransaction.logs[0].args.txIndex.toNumber();
  });

  it("Submit New Transaction", async () => {
    const transaction = await contractInstance.getTransaction(txId);

    assert.equal(transaction.to, pep);
  });
  it("Only owner can submit transaction", async () => {
    await utils.shouldThrow(
      contractInstance.submitTransaction(pep, 50, { from: saeed })
    );
  });
  it("Confirm Transaction", async () => {
    await contractInstance.confirmTransaction(txId, { from: bob });

    //cant owner confirm twice transaction
    await utils.shouldThrow(
      contractInstance.confirmTransaction(txId, { from: bob })
    );

    const transaction = await contractInstance.getTransaction(txId);

    assert.equal(transaction.numConfirmation, 1);
  });
  it("Revoke Confirmed Transaction ", async () => {
    await contractInstance.confirmTransaction(txId, { from: bob });

    await contractInstance.revokeTransaction(txId, { from: bob });

    const transaction = await contractInstance.getTransaction(txId);

    assert.equal(transaction.numConfirmation, 0);
  });
  it("Cant owners revoke confirm transaction when not confirmed ", async () => {
    await utils.shouldThrow(
      contractInstance.revokeTransaction(txId, { from: bob })
    );
  });
  it("Excuted Transaction", async () => {
    await contractInstance.confirmTransaction(txId, { from: alice });
    await contractInstance.confirmTransaction(txId, { from: bob });
    await contractInstance.confirmTransaction(txId, { from: jack });

    await contractInstance.excuteTransaction(txId, { from: jack });
  });
});
