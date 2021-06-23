const { ethers } = require("hardhat");

const units = (value) => ethers.utils.parseUnits(value.toString());

module.exports = {
  units,
};
