const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { ethers, upgrades } = require("hardhat");
const { expect } = chai;
const { units } = require("./utils");

chai.use(solidity);

describe("LandPlot", () => {
  let landPlot;
  let owner, userA, userB;

  before(async () => {
    [owner, userA, userB] = await ethers.getSigners();

    const LandPlot = await ethers.getContractFactory("LandPlot");
    landPlot = await upgrades.deployProxy(LandPlot, ["LandPlot", "CHUNK"]);
    await landPlot.deployed();
  });

  it("Owner can set claimable status", async () => {
    expect(await landPlot.claimable()).to.be.false;

    await expect(landPlot.connect(userA).setClaimable(true)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    );

    await landPlot.setClaimable(true);

    expect(await landPlot.claimable()).to.be.true;

    await landPlot.setClaimable(false);

    expect(await landPlot.claimable()).to.be.false;
  });

  it("Owner can set plot prices", async () => {
    await expect(landPlot.plotPrices(0)).to.be.reverted;
    await expect(landPlot.plotPriceDistances(0)).to.be.reverted;

    const distances = ["10", "100", "500", "1000", "2000", "5000"];
    const prices = [units(1), "1000000", "10000", "100", "10", "1"];
    await expect(
      landPlot.connect(userA).setPlotPrices(prices, distances)
    ).to.be.revertedWith("Ownable: caller is not the owner");
    await expect(
      landPlot.setPlotPrices(prices, [...distances, 1])
    ).to.be.revertedWith("length doesn't match");

    await landPlot.setPlotPrices(prices, distances);

    expect(await landPlot.plotPrices(0)).to.be.equal(units(1));
    expect(await landPlot.plotPriceDistances(0)).to.be.equal(10);
  });

  it("Owner can set claimable status", async () => {
    expect(await landPlot.worldSize()).to.be.equal(2000);

    await expect(landPlot.connect(userA).setWorldSize(1000)).to.be.revertedWith(
      "Ownable: caller is not the owner"
    );

    await landPlot.setWorldSize(1000);

    expect(await landPlot.worldSize()).to.be.equal(1000);

    await landPlot.setWorldSize(2000);

    expect(await landPlot.worldSize()).to.be.equal(2000);
  });

  it("Owner can mint token", async () => {
    await expect(
      landPlot.connect(userA).mintOne(owner.address, 0, 0)
    ).to.be.revertedWith("Ownable: caller is not the owner");

    await expect(landPlot.mintOne(owner.address, -3000, 0)).to.be.revertedWith(
      "the claim is beyond the specified world size"
    );

    await landPlot.mintOne(owner.address, 0, 0);
    expect(await landPlot.tokenIdOf(0, 0)).to.be.equal(1);
    expect(await landPlot.totalSupply()).to.be.equal(1);
  });

  it("Owner can mint multiple tokens", async () => {
    const xs = [-3, -2, -1, 0, 1, 2, 3];
    const zs = [-5, -1, 0, 1, 2, 3, 4];

    await expect(
      landPlot.connect(userA).mintMany(owner.address, xs, zs)
    ).to.be.revertedWith("Ownable: caller is not the owner");
    await expect(
      landPlot.mintMany(owner.address, xs, [...zs, 1])
    ).to.be.revertedWith("xs and ys coordinate count must match");
    await expect(
      landPlot.mintMany(owner.address, [...xs, 0], [...zs, 0])
    ).to.be.revertedWith("attempting to mint already minted land");
    await expect(
      landPlot.mintMany(owner.address, [...xs, -3000], [...zs, 0])
    ).to.be.revertedWith("the claim is beyond the specified world size");

    await landPlot.mintMany(owner.address, xs, zs);
    expect(await landPlot.tokenIdOf(-3, -5)).to.be.equal(2);
    expect(await landPlot.tokenIdOf(3, 4)).to.be.equal(8);
    expect(await landPlot.totalSupply()).to.be.equal(8);
  });

  it("Should be able to get chunk of tokenId", async () => {
    await expect(landPlot.chunkOf(9)).to.be.reverted;
    await expect(landPlot.chunkOf(0)).to.be.reverted;

    const [x, z] = await landPlot.chunkOf(8);
    expect(x).to.be.equal(3);
    expect(z).to.be.equal(4);
  });

  it("Should be able to calculate land cost", async () => {
    expect(await landPlot.calculateLandCost(0, 0)).to.be.equal(units(1));
    expect(await landPlot.calculateLandCost(120, 150)).to.be.equal(10000);
    expect(await landPlot.calculateLandCost(1200, 1300)).to.be.equal(10);
  });

  it("Should be able to transfer tokens", async () => {
    expect(await landPlot.ownerOf(1)).to.be.equal(owner.address);

    await expect(
      landPlot.connect(userA).transferFrom(owner.address, userB.address, 1)
    ).to.be.revertedWith("ERC721: transfer caller is not owner nor approved");
    await landPlot.transferFrom(owner.address, userB.address, 1);

    expect(await landPlot.ownerOf(1)).to.be.equal(userB.address);
  });

  it("Should be able to transfer multiple tokens", async () => {
    expect(await landPlot.ownerOf(2)).to.be.equal(owner.address);
    expect(await landPlot.ownerOf(3)).to.be.equal(owner.address);

    await expect(
      landPlot.connect(userA).multiTransfer(userB.address, [2, 3])
    ).to.be.revertedWith("ERC721: transfer caller is not owner nor approved");
    await landPlot.multiTransfer(userB.address, [2, 3]);

    expect(await landPlot.ownerOf(2)).to.be.equal(userB.address);
    expect(await landPlot.ownerOf(3)).to.be.equal(userB.address);
  });

  it("Should be able to claim lands by paying eth", async () => {
    const xs = [1, 120, 1200];
    const zs = [0, 150, 1300];
    const price = units(1).add(10010);

    await expect(
      landPlot.connect(userA).claimLands(xs, zs, {
        value: price,
      })
    ).to.be.revertedWith("claiming is currently disabled");

    await landPlot.setClaimable(true);

    await expect(
      landPlot.connect(userA).claimLands(new Array(129).fill(0), zs, {
        value: price,
      })
    ).to.be.revertedWith("cannot claim more than 128 chunks at a time!");

    await expect(
      landPlot.connect(userA).claimLands(xs, [0], {
        value: price,
      })
    ).to.be.revertedWith("xs and zs array lengths must match!");

    await expect(
      landPlot.connect(userA).claimLands(xs, zs, {
        value: "10",
      })
    ).to.be.revertedWith("not enough eth sent to purchase land");

    let balanceBefore = ethers.BigNumber.from(
      await ethers.provider.getBalance(userA.address)
    );

    await landPlot.connect(userA).claimLands(xs, zs, {
      value: price,
    });

    let balanceAfter = ethers.BigNumber.from(
      await ethers.provider.getBalance(userA.address)
    );
    expect(balanceBefore.sub(price)).to.be.gt(balanceAfter);

    // trying to pay more

    balanceBefore = ethers.BigNumber.from(
      await ethers.provider.getBalance(userA.address)
    );

    await landPlot.connect(userA).claimLands([8, 121, 1201], [0, 150, 1300], {
      value: price.add(units(1)),
    });

    balanceAfter = ethers.BigNumber.from(
      await ethers.provider.getBalance(userA.address)
    );
    expect(balanceBefore.sub(price)).to.be.gt(balanceAfter);
    expect(balanceBefore.sub(price.add(units(1)))).to.be.lt(balanceAfter);
  });
});
