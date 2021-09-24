const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

let accounts;
let deployer;

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  accounts = await ethers.getSigners();
  deployer = await accounts[0];
  const District = (await ethers.getContractFactory("TestUSDC")).connect(
    deployer
  );
  const district = await upgrades.deployProxy(District, [
    "Etherlands Playtest USDC",
    "EPTU",
  ]);
  await district.deployed();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
