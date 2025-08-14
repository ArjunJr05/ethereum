// Corrected version
const CarbonCreditMarketplace = artifacts.require("CarbonCreditMarketplace");

module.exports = function (deployer) {
  deployer.deploy(CarbonCreditMarketplace); // No arguments needed
};