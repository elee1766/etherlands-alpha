const { expect } = require("chai");


let LandPlot;
let landplot;
let accounts;
let deployer;
let A;

let ticketprice =  1000000000000000;

const init = async ()=>{

  LandPlot = await ethers.getContractFactory("LandPlot");
  landplot = await LandPlot.deploy();

  accounts = await ethers.getSigners()
  deployer = accounts[0]
  A = accounts[1]
}

describe("landplot", function() {
  before("deploy_contracts", init);
  it("genesis minter should mint themselves some chunks", async function() {
    await landplot.connect(deployer).mintMany(await deployer.getAddress(),[0,0,0,1,-1,-1],[0,1,-1,-1,1,0])
  });

  it("A is gonna buy 4 plots of land", async () => {
    await landplot.connect(A).genesisPurchase([2,2,3,3],[2,3,3,2],{value:ticketprice*4,from:await A.getAddress()})
  })
});
