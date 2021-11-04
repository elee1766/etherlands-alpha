const hre = require("hardhat");
const { ethers, upgrades } = require("hardhat");

let accounts;
let deployer;

let combo_x = [];
let combo_z = [];
let idx = 0;

let temp_x = [];
let temp_z = [];
for (var i = -20; i <= 20; i++) {
  for (var j = -20; j <= 20; j++) {
    if (Math.abs(i) > 2 && Math.abs(j) > 2) {
      temp_x.push(i);
      temp_z.push(j);
      idx = idx + 1;
    }
    if (idx == 50) {
      combo_x.push(temp_x);
      combo_z.push(temp_z);
      temp_x = [];
      temp_z = [];
      idx = 0;
    }
  }
}
combo_x.push(temp_x);
combo_z.push(temp_z);
temp_x = [];
temp_z = [];
idx = 0;

async function main() {
  accounts = await ethers.getSigners();
  deployer = await accounts[0];
  const District = (await ethers.getContractFactory("Etherlands")).connect(
    deployer
  );

  const district = District.attach(
    "0x23cb1d39e55aa8ab3893ef69cc9e01a3783e893a"
  );
  //for (let i = 0; i < 1; i++) {
  for (let i = 9; i < combo_x.length; i++) {
    const new_c = await district.connect(deployer);
    const txn = await new_c.adminClaim(combo_x[i], combo_z[i], 1);
    await txn.wait();
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
