const MultiSigWallet = artifacts.require("MultiSigWallet");
const utils = require("./Helper/Utils");

contract("MultiSigWallet", (accounts) => {
    let [alice, bob, jack, saeed] = accounts;
    let contractInstance;
    let owners = [accounts[0], accounts[1], accounts[2]];
    let submitOwnerForm;
    let submitRemovedOwnerForm;
    let formId;
    let removedFormId;
    beforeEach(async () => {

        //deploy contract with 3 owners and atleast 2 confirm for excute ownerForm
        contractInstance = await MultiSigWallet.new(owners, 2);

        //submit ownerForm for add a account to owners
        submitOwnerForm = await contractInstance.submitOwnerForm(web3.utils.asciiToHex("add owner"), 3, saeed, false, { from: alice });

        //submit ownerFomr for remove owner account
        submitRemovedOwnerForm = await contractInstance.submitOwnerForm(web3.utils.asciiToHex("removed owner"), 2, jack, true, { from: bob });

        formId = submitOwnerForm.logs[0].args.formIndex.toNumber();
        removedFormId = submitRemovedOwnerForm.logs[0].args.formIndex.toNumber();
    })

    it("Submit OwnerForm and RemovedOwnerForm", async () => {
        const OwnerForm = await contractInstance.getOwnerForm(formId);
        const removedOwnerForm = await contractInstance.getOwnerForm(removedFormId);

        assert.equal(OwnerForm._ownerAddress, saeed);
        assert.equal(removedOwnerForm._ownerAddress, jack);
    })
    it("Confirm OwnerForm and RemovedOwnerForm", async () => {
        //confirm ownerForm by alice and bob
        await contractInstance.confirmOwnerForm(formId, { from: alice });
        await contractInstance.confirmOwnerForm(removedFormId, { from: bob });

        //get ownerForm detail with id
        const OwnerForm = await contractInstance.getOwnerForm(formId);
        const removedOwnerForm = await contractInstance.getOwnerForm(removedFormId);

        assert.equal(OwnerForm._numConfirmation, 1);
        assert.equal(removedOwnerForm._numConfirmation, 1);
    })
    it("Revoke Confirmed OwnerForm and RemovedOwnerForm", async () => {
        //confirm ownerForm by alice and bob
        await contractInstance.confirmOwnerForm(formId, { from: alice });
        await contractInstance.confirmOwnerForm(formId, { from: bob });

        //confirm removedOwnerForm by bob
        await contractInstance.confirmOwnerForm(removedFormId, { from: bob });

        //reoke confirm by bob
        await contractInstance.revokeOwnerForm(formId, { from: bob });
        await contractInstance.revokeOwnerForm(removedFormId, { from: bob });

        //cant revoke confirm because not confirmed
        await utils.shouldThrow(contractInstance.revokeOwnerForm(formId, { from: jack }));
        await utils.shouldThrow(contractInstance.revokeOwnerForm(removedFormId, { from: alice }));

        //get ownerForm detail with id
        const OwnerForm = await contractInstance.getOwnerForm(formId);
        const removedOwnerForm = await contractInstance.getOwnerForm(removedFormId);

        assert.equal(OwnerForm._numConfirmation, 1);
        assert.equal(removedOwnerForm._numConfirmation, 0);
    })
    it("Excute OwnerForm", async () => {
        //confirm ownerForm by alice
        await contractInstance.confirmOwnerForm(formId, { from: alice });

        //alice cant excute ownerForm because not enough confirm
        await utils.shouldThrow(contractInstance.excuteOwnerForm(formId, { from: alice }));

        //confirm ownerForm by bob
        await contractInstance.confirmOwnerForm(formId, { from: bob });

        //excute ownerForm by alice 
        await contractInstance.excuteOwnerForm(formId, { from: alice });

        //get ownerForm detail with id
        const OwnerForm = await contractInstance.getOwnerForm(formId, { from: alice });

        assert.equal(OwnerForm._executed, true);

        const owners = await contractInstance.getOwnersCount();
        assert.equal(owners, 4);
    })
    it("Excute RemovedOwnerForm", async () => {
        await contractInstance.confirmOwnerForm(removedFormId, { from: alice });

        //alice cant excute RemovedOwnerForm because not enough confirm
        await utils.shouldThrow(contractInstance.excuteOwnerForm(removedFormId, { from: alice }));

        //confirm RemovedOwnerForm by bob
        await contractInstance.confirmOwnerForm(removedFormId, { from: bob });

        //excute RemovedOwnerForm by alice 
        await contractInstance.excuteOwnerForm(removedFormId, { from: alice });

        const removedOwnerForm = await contractInstance.getOwnerForm(removedFormId, { from: alice });

        assert.equal(removedOwnerForm._executed, true);
    })
})