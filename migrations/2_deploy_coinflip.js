const CoinFlip = artifacts.require('CoinFlip');

module.exports = async function (deployer) {

    await deployer.deploy(
        CoinFlip,
        "0xbD658acCb3364b292E2f7620F941d4662Fd25749", // Deployed ULP Address
        "0xbe9512e2754cb938dd69bbb96c8a09cb28a02d6d", // Deployed GBTS Address
        "0x30eE5c68B3d5fADAaFA293cC8E5d2D6651a3524e", // // Deployed RNG Address
    );

    return;
};
