const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { ethers, upgrades } = require("hardhat");
const { expect } = chai;
const {
  weeks,
  units,
  currentBlockNumber,
  mineBlocks,
  ethBalance,
  timeTravel,
} = require("./utils");

chai.use(solidity);

describe("Marketplace", () => {
  let landPlot, marketplace;
  let owner, userA, userB;

  before(async () => {
    [owner, userA, userB] = await ethers.getSigners();

    const LandPlot = await ethers.getContractFactory("LandPlot");
    landPlot = await upgrades.deployProxy(LandPlot, ["LandPlot", "CHUNK"]);
    await landPlot.deployed();

    const Marketplace = await ethers.getContractFactory("Marketplace");
    marketplace = await upgrades.deployProxy(Marketplace, []);
    await marketplace.deployed();
  });

  it("Owner can mint multiple tokens", async () => {
    const xs = [-3, -2, -1, 0, 1, 2, 3];
    const zs = [-3, -2, -1, 0, 1, 2, 3];

    await landPlot.mintMany(owner.address, xs, zs);
    expect(await landPlot.totalSupply()).to.be.equal(7);
  });

  it("Should be able to create auction", async () => {
    await expect(
      marketplace.connect(userA).createAuction(landPlot.address, 0, 10)
    ).to.be.revertedWith("ERC721: operator query for nonexistent token");
    await expect(
      marketplace.connect(userA).createAuction(landPlot.address, 1, 10)
    ).to.be.revertedWith("ERC721: transfer caller is not owner nor approved");
    await expect(
      marketplace.createAuction(landPlot.address, 1, 10)
    ).to.be.revertedWith("ERC721: transfer caller is not owner nor approved");

    await landPlot.approve(marketplace.address, 1);
    await marketplace.createAuction(landPlot.address, 1, 10);

    const blockNumber = await currentBlockNumber();
    const auction = await marketplace.getAuctionInfo(0);
    expect(auction[0]).to.be.equal(owner.address);
    expect(auction[1]).to.be.equal(landPlot.address);
    expect(auction[2][0]).to.be.equal(1);
    expect(auction[3]).to.be.equal(blockNumber.add(10));
    expect(auction[4]).to.be.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(auction[5]).to.be.equal(0);
    expect(auction[6]).to.be.equal(0);
  });

  it("Should be able to create auction with multiple tokens", async () => {
    await expect(
      marketplace
        .connect(userA)
        .createAuctionWithMultipleTokens(landPlot.address, [], 10)
    ).to.be.revertedWith("empty tokenId array");
    await expect(
      marketplace
        .connect(userA)
        .createAuctionWithMultipleTokens(landPlot.address, [0, 2], 10)
    ).to.be.revertedWith("ERC721: operator query for nonexistent token");
    await expect(
      marketplace
        .connect(userA)
        .createAuctionWithMultipleTokens(landPlot.address, [2, 3], 10)
    ).to.be.revertedWith("ERC721: transfer caller is not owner nor approved");
    await expect(
      marketplace.createAuctionWithMultipleTokens(landPlot.address, [2, 3], 10)
    ).to.be.revertedWith("ERC721: transfer caller is not owner nor approved");

    await landPlot.approve(marketplace.address, 2);
    await landPlot.approve(marketplace.address, 3);
    await marketplace.createAuctionWithMultipleTokens(
      landPlot.address,
      [2, 3],
      10
    );

    const blockNumber = await currentBlockNumber();
    let auction = await marketplace.getAuctionInfo(1);
    expect(auction[0]).to.be.equal(owner.address);
    expect(auction[1]).to.be.equal(landPlot.address);
    expect(auction[2][0]).to.be.equal(2);
    expect(auction[2][1]).to.be.equal(3);
    expect(auction[3]).to.be.equal(blockNumber.add(10));
    expect(auction[4]).to.be.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(auction[5]).to.be.equal(0);
    expect(auction[6]).to.be.equal(0);
  });

  it("Should be able to cancel auction", async () => {
    await expect(marketplace.cancelAuction(2)).to.be.revertedWith(
      "invalid auction id"
    );
    await expect(
      marketplace.connect(userA).cancelAuction(0)
    ).to.be.revertedWith("not auction creator");

    expect(await landPlot.ownerOf(1)).to.be.equal(marketplace.address);

    await marketplace.cancelAuction(0);

    expect(await landPlot.ownerOf(1)).to.be.equal(owner.address);

    await expect(marketplace.cancelAuction(0)).to.be.revertedWith(
      "auction finished"
    );

    let auction = await marketplace.getAuctionInfo(0);
    expect(auction[0]).to.be.equal(owner.address);
    expect(auction[1]).to.be.equal(landPlot.address);
    expect(auction[2][0]).to.be.equal(1);
    expect(auction[4]).to.be.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(auction[5]).to.be.equal(0);
    expect(auction[6]).to.be.equal(1);
  });

  it("Should be able to bid auction", async () => {
    await expect(marketplace.bid(2)).to.be.revertedWith("invalid auction id");

    await expect(marketplace.bid(1)).to.be.revertedWith(
      "less than current bid amount"
    );
    await expect(marketplace.bid(0, { value: units(1) })).to.be.revertedWith(
      "auction finished"
    );

    await mineBlocks(10);
    await expect(marketplace.bid(1, { value: units(1) })).to.be.revertedWith(
      "auction finished"
    );

    expect(await landPlot.ownerOf(2)).to.be.equal(marketplace.address);
    expect(await landPlot.ownerOf(3)).to.be.equal(marketplace.address);

    await marketplace.cancelAuction(1);

    expect(await landPlot.ownerOf(2)).to.be.equal(owner.address);
    expect(await landPlot.ownerOf(3)).to.be.equal(owner.address);

    await landPlot.approve(marketplace.address, 1);
    await marketplace.createAuction(landPlot.address, 1, 10);

    let balanceBeforeA = await ethBalance(userA.address);

    await marketplace.connect(userA).bid(2, { value: units(1) });

    let balanceAfterA = await ethBalance(userA.address);
    expect(balanceBeforeA.sub(units(1))).to.be.gt(balanceAfterA);

    // try outbid
    balanceBeforeA = await ethBalance(userA.address);
    let balanceBeforeB = await ethBalance(userB.address);

    await marketplace.connect(userB).bid(2, { value: units(1.5) });

    balanceAfterA = await ethBalance(userA.address);
    let balanceAfterB = await ethBalance(userB.address);
    expect(balanceBeforeA.add(units(1))).to.be.equal(balanceAfterA);
    expect(balanceBeforeB.sub(units(1.5))).to.be.gt(balanceAfterB);

    let auction = await marketplace.getAuctionInfo(2);
    expect(auction[0]).to.be.equal(owner.address);
    expect(auction[1]).to.be.equal(landPlot.address);
    expect(auction[2][0]).to.be.equal(1);
    expect(auction[4]).to.be.equal(userB.address);
    expect(auction[5]).to.be.equal(units(1.5));
    expect(auction[6]).to.be.equal(0);

    // try cancel
    balanceBeforeB = await ethBalance(userB.address);
    expect(await landPlot.ownerOf(1)).to.be.equal(marketplace.address);

    await marketplace.cancelAuction(2);

    balanceAfterB = await ethBalance(userB.address);
    expect(await landPlot.ownerOf(1)).to.be.equal(owner.address);
    expect(balanceBeforeB.add(units(1.5))).to.be.equal(balanceAfterB);

    auction = await marketplace.getAuctionInfo(2);
    expect(auction[0]).to.be.equal(owner.address);
    expect(auction[1]).to.be.equal(landPlot.address);
    expect(auction[2][0]).to.be.equal(1);
    expect(auction[4]).to.be.equal(
      "0x0000000000000000000000000000000000000000"
    );
    expect(auction[5]).to.be.equal(0);
    expect(auction[6]).to.be.equal(1);
  });

  it("Should be able to claim auction", async () => {
    await landPlot.approve(marketplace.address, 1);
    await marketplace.createAuction(landPlot.address, 1, 10);
    await marketplace.connect(userA).bid(3, { value: units(1) });

    await expect(marketplace.claim(4)).to.be.revertedWith("invalid auction id");

    await expect(marketplace.claim(3)).to.be.revertedWith(
      "auction not finished"
    );

    await mineBlocks(10);

    let auction = await marketplace.getAuctionInfo(3);
    expect(auction[0]).to.be.equal(owner.address);
    expect(auction[1]).to.be.equal(landPlot.address);
    expect(auction[2][0]).to.be.equal(1);
    expect(auction[4]).to.be.equal(userA.address);
    expect(auction[5]).to.be.equal(units(1));
    expect(auction[6]).to.be.equal(2);

    await expect(marketplace.claim(3)).to.be.revertedWith("not winner");

    const balanceBefore = await ethBalance(owner.address);
    expect(await landPlot.ownerOf(1)).to.be.equal(marketplace.address);

    await marketplace.connect(userA).claim(3);

    const balanceAfter = await ethBalance(owner.address);
    expect(balanceBefore.add(units(1))).to.be.equal(balanceAfter);
    expect(await landPlot.ownerOf(1)).to.be.equal(userA.address);

    await expect(marketplace.connect(userA).claim(3)).to.be.revertedWith(
      "auction finished"
    );

    auction = await marketplace.getAuctionInfo(3);
    expect(auction[0]).to.be.equal(owner.address);
    expect(auction[1]).to.be.equal(landPlot.address);
    expect(auction[2][0]).to.be.equal(1);
    expect(auction[4]).to.be.equal(userA.address);
    expect(auction[5]).to.be.equal(units(1));
    expect(auction[6]).to.be.equal(3);
  });

  it("Should be able to create purchase", async () => {
    const balanceBefore = await ethBalance(userB.address);
    await marketplace
      .connect(userB)
      .createPurchase(landPlot.address, 1, weeks(1), {
        value: units(1),
      });
    const balanceAfter = await ethBalance(userB.address);
    expect(balanceBefore.sub(units(1))).gt(balanceAfter);

    let purchase = await marketplace.getPurchaseInfo(0);
    expect(purchase[0]).to.be.equal(userB.address);
    expect(purchase[1]).to.be.equal(landPlot.address);
    expect(purchase[2]).to.be.equal(1);
    expect(purchase[3]).to.be.equal(units(1));
    expect(purchase[5]).to.be.equal(0);
  });

  it("Should be able to cancel purchase", async () => {
    await timeTravel(weeks(2));

    let purchase = await marketplace.getPurchaseInfo(0);
    expect(purchase[0]).to.be.equal(userB.address);
    expect(purchase[1]).to.be.equal(landPlot.address);
    expect(purchase[2]).to.be.equal(1);
    expect(purchase[3]).to.be.equal(units(1));
    expect(purchase[5]).to.be.equal(2);

    await expect(marketplace.cancelPurchase(1)).to.be.revertedWith(
      "invalid purchase id"
    );

    await expect(marketplace.cancelPurchase(0)).to.be.revertedWith(
      "not purchaser"
    );

    const balanceBefore = await ethBalance(userB.address);

    await marketplace.connect(userB).cancelPurchase(0);

    const balanceAfter = await ethBalance(userB.address);
    expect(balanceBefore).lt(balanceAfter);

    purchase = await marketplace.getPurchaseInfo(0);
    expect(purchase[0]).to.be.equal(userB.address);
    expect(purchase[1]).to.be.equal(landPlot.address);
    expect(purchase[2]).to.be.equal(1);
    expect(purchase[3]).to.be.equal(units(1));
    expect(purchase[5]).to.be.equal(1);

    await expect(
      marketplace.connect(userB).cancelPurchase(0)
    ).to.be.revertedWith("purchase finished");
  });

  it("Should be able to accept purchase", async () => {
    await expect(marketplace.accept(1)).to.be.revertedWith(
      "invalid purchase id"
    );
    await expect(marketplace.accept(0)).to.be.revertedWith("purchase expired");

    await marketplace
      .connect(userB)
      .createPurchase(landPlot.address, 1, weeks(1), {
        value: units(1),
      });

    await expect(marketplace.accept(1)).to.be.revertedWith(
      "ERC721: transfer caller is not owner nor approved"
    );

    await expect(marketplace.connect(userA).accept(1)).to.be.revertedWith(
      "ERC721: transfer caller is not owner nor approved"
    );

    await landPlot.connect(userA).approve(marketplace.address, 1);
    await marketplace.connect(userA).accept(1);

    const purchase = await marketplace.getPurchaseInfo(1);
    expect(purchase[0]).to.be.equal(userB.address);
    expect(purchase[1]).to.be.equal(landPlot.address);
    expect(purchase[2]).to.be.equal(1);
    expect(purchase[3]).to.be.equal(units(1));
    expect(purchase[5]).to.be.equal(3);

    await expect(marketplace.connect(userA).accept(1)).to.be.revertedWith(
      "purchase finished"
    );
  });
});
