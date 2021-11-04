const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

let accounts;
let deployer;

async function main() {
  accounts = await ethers.getSigners();
  deployer = await accounts[0];
  const District = (await ethers.getContractFactory("Etherlands")).connect(
    deployer
  );
  const district = await upgrades.deployProxy(District, ["Etherlands", "DEED"]);
  await district.deployed();
  const TestUSDC = (await ethers.getContractFactory("TestUSDC")).connect(
    deployer
  );
  const testusdc = await upgrades.deployProxy(TestUSDC, [
    "Etherlands Playtest USDC",
    "EPTU",
  ]);

  const HOA = (await ethers.getContractFactory("EtherlandsToken")).connect(
    deployer
  );
  const hoa = await upgrades.deployProxy(HOA, [
    "Etherlands Playtest Reward Token",
    "HOA_TEST",
  ]);
  await district.deployed();
  await testusdc.deployed();
  await hoa.deployed();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
