const CoinFlip = artifacts.require('CoinFlip');

module.exports = async function (deployer) {

    await deployer.deploy(
        CoinFlip,
        "0xB1310c700699eC24D67beAc7164cea0792069080", // Deployed ULP Address
        "0xC238001552195f0E159798CdA94DC22a71993bC9", // Deployed GBTS Address
        "0xfe18A7673bAa26870B4f8df6a9cCE811E1f88e52", // // Deployed RNG Address
    );

    return;
};
