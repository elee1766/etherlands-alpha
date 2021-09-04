// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

let accounts;
let deployer;

let combo_x = [];
let combo_y = [];
const array1 = [-3, -2, -1, 0, 1, 2, 3];
const array2 = [-3, -2, -1, 0, 1, 2, 3];
for (var i = 0; i < array1.length; i++) {
  for (var j = 0; j < array2.length; j++) {
    //you would access the element of the array as array1[i] and array2[j]
    //create and array with as many elements as the number of arrays you are to combine
    //add them in
    //you could have as many dimensions as you need
    combo_x.push(array1[i]);
    combo_y.push(array2[j]);
  }
}

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  accounts = await ethers.getSigners();
  deployer = accounts[0];
  A = accounts[1];
  const District = await ethers.getContractFactory("District");
  const district = await upgrades.deployProxy(District, ["District", "DEED"]);
  await district.deployed();
  district.connect(deployer).adminClaim(combo_x, combo_y, 0);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
