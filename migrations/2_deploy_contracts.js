const Governance = artifacts.require("Governance");
const DTRUSTFactory = artifacts.require("DTRUSTFactory");
const ControlKey = artifacts.require("ControlKey");
const DTtoken = artifacts.require("DTtoken");
const PRtoken = artifacts.require("PRtoken");

module.exports = async function (deployer, network, accounts) {

    // const manager = "0x1Bb0ebE711a73347ae2F2A765A06AfAfB14c9A93";
    const manager = "0x49F67373f007aD8248f3ECDBA76f17b3e0DE3141";

    deployer.deploy(Governance)
        .then((governanceResult) => {

            deployer.deploy(DTtoken, manager, governanceResult.address)
                .then((dttokenResult) => {

                    governanceResult.registerDTtoken(dttokenResult.address)
                });

            deployer.deploy(DTRUSTFactory, governanceResult.address);
        })
        .then(() => deployer.deploy(PRtoken, manager))
        .then(() => deployer.deploy(ControlKey));

};
