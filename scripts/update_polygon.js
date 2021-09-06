const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

const abis = require("./abis");

let accounts;
let deployer;

let combo_x = [];
let combo_y = [];

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  accounts = await ethers.getSigners();
  deployer = await accounts[0];
  const District = (await ethers.getContractFactory("District")).connect(
    deployer
  );
  console.log("deploying new contract");
  const district = await District.deploy();
  const impl = district.address;

  const proxy = new ethers.Contract(
    "0xc7B4Cdf2c8ff3FC94D4f9f882D86CE824e0FB985",
    abis.proxy,
    deployer
  );
  console.log("upgraded");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });