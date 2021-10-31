/* Contracts in this test */
const DTRUSTFactory = artifacts.require("../contracts/DTRUSTFactory.sol");

contract("DTRUSTFactory", (accounts) => {
    const NAME = 'DTRUST Test Contract';
    const SYMBOL = 'DTRUSTTest';

    const INITIAL_TOKEN_ID = 1;
    const NON_EXISTENT_TOKEN_ID = 99999999;

    const owner = accounts[0];
    const settlor = accounts[1];
    const beneficiary = accounts[2];
    const trustee = accounts[3];

    let instance;
    let deployedDtrust;

    before(async () => {
        instance = await DTRUSTFactory.new();
    });

    describe("#constructor()", () => {
        it("should create new constructor", async () => {

        }
        )
    });

    describe("#createDTRUST()", () => {
        it('should create new DTRUST', async () => {
            await instance.createDTRUST(SYMBOL, "HELLO", NAME, "PrivateKey", settlor, beneficiary, trustee, { from: owner });

        });
    });

    describe("#createPromoteToken()", () => {
        it("Successfully created", async () => {
            const isCreated = await instance.createPromoteToken(deployedDtrust, 1, "PrToken", "TokenKey");
            console.log(isCreated);
        })
    })
})
