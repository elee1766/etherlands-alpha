const { ethers } = require("hardhat");

const days = (value) => value * 24 * 60 * 60;
const weeks = (value) => days(value * 7);
const months = (value) => days(value * 30);
const years = (value) => days(value * 365);

const units = (value) => ethers.utils.parseUnits(value.toString());

const ethBalance = async (address) => {
  return ethers.BigNumber.from(await ethers.provider.getBalance(address));
};

const currentBlockNumber = async () => {
  return ethers.BigNumber.from(await ethers.provider.getBlockNumber());
};

const mineBlocks = async (count) => {
  for (let i = 0; i < count; i++) {
    await ethers.provider.send("evm_mine");
  }
};

const timeTravel = async (seconds) => {
  await ethers.provider.send("evm_increaseTime", [seconds]);
  await ethers.provider.send("evm_mine");
};

module.exports = {
  days,
  weeks,
  months,
  years,
  units,
  currentBlockNumber,
  ethBalance,
  mineBlocks,
  timeTravel,
};
