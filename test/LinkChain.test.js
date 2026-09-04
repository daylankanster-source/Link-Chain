const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LinkChain", function () {
  let c, owner, alice, bob;
  const FEE = ethers.parseEther("0.01");

  beforeEach(async () => {
    [owner, alice, bob] = await ethers.getSigners();
    const F = await ethers.getContractFactory("LinkChain");
    c = await F.deploy();
    await c.waitForDeployment();
  });

  describe("Registration", () => {
    it("registers a link with fee", async () => {
      await expect(c.connect(alice).registerLink("hello", "https://example.com", "Example", { value: FEE }))
        .to.emit(c, "LinkRegistered");
      const link = await c.getLink(1);
      expect(link.slug).to.equal("hello");
      expect(link.owner).to.equal(alice.address);
    });

    it("rejects duplicate slug", async () => {
      await c.connect(alice).registerLink("hello", "https://example.com", "", { value: FEE });
      await expect(c.connect(bob).registerLink("hello", "https://other.com", "", { value: FEE }))
        .to.be.revertedWith("Slug already taken");
    });

    it("rejects insufficient fee", async () => {
      await expect(c.connect(alice).registerLink("s", "https://x.com", "", { value: 1 }))
        .to.be.revertedWith("Insufficient registration fee");
    });

    it("resolveSlug returns the link", async () => {
      await c.connect(alice).registerLink("news", "https://news.com", "News", { value: FEE });
      const link = await c.resolveSlug("news");
      expect(link.url).to.equal("https://news.com");
    });
  });

  describe("Boost", () => {
    beforeEach(async () => {
      await c.connect(alice).registerLink("hi", "https://hi.com", "", { value: FEE });
    });

    it("boosts and forwards to owner minus fee", async () => {
      const before = await ethers.provider.getBalance(alice.address);
      await c.connect(bob).boostLink(1, { value: ethers.parseEther("1") });
      const after = await ethers.provider.getBalance(alice.address);
      // owner should receive 95% of 1 BOT
      expect(after - before).to.equal(ethers.parseEther("0.95"));
    });

    it("increases totalBoost", async () => {
      await c.connect(bob).boostLink(1, { value: ethers.parseEther("1") });
      const link = await c.getLink(1);
      expect(link.totalBoost).to.equal(ethers.parseEther("0.95"));
    });

    it("records boost history", async () => {
      await c.connect(bob).boostLink(1, { value: ethers.parseEther("0.5") });
      expect(await c.getBoostCount(1)).to.equal(1);
    });
  });

  describe("Update", () => {
    it("owner can update", async () => {
      await c.connect(alice).registerLink("s", "https://a.com", "A", { value: FEE });
      await c.connect(alice).updateLink(1, "https://b.com", "B");
      const link = await c.getLink(1);
      expect(link.url).to.equal("https://b.com");
    });

    it("non-owner cannot update", async () => {
      await c.connect(alice).registerLink("s", "https://a.com", "A", { value: FEE });
      await expect(c.connect(bob).updateLink(1, "https://b.com", "B"))
        .to.be.revertedWith("Not owner");
    });
  });

  describe("Admin", () => {
    it("owner can withdraw fees", async () => {
      await c.connect(alice).registerLink("s", "https://a.com", "", { value: FEE });
      await c.connect(bob).boostLink(1, { value: ethers.parseEther("1") });
      // fees = registration + 5% of boost = 0.01 + 0.05 = 0.06
      const before = await ethers.provider.getBalance(owner.address);
      const tx = await c.connect(owner).withdrawFees(owner.address);
      await tx.wait();
      const after = await ethers.provider.getBalance(owner.address);
      expect(after).to.be.gt(before);
    });

    it("non-owner cannot pause", async () => {
      await expect(c.connect(alice).pause()).to.be.reverted;
    });
  });
});
