import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { ZeroHash } from 'ethers';

describe('Bundler', function () {
  async function deployBundlerFixture() {
    const [owner, buyer, another] = await ethers.getSigners();
    const uri = 'https://my.metadata.sample/';
    const nftAmounts = [50, 100, 200, 500, 1000, 10000];

    const MultiNft = await ethers.getContractFactory('MultiNft');
    const nft = await MultiNft.deploy(owner.address, uri, nftAmounts, ZeroHash);

    const MockERC20 = await ethers.getContractFactory('MockERC20');
    const mockPaymentToken = await MockERC20.deploy('MockToken', 'MTK', 18);

    const Bundler = await ethers.getContractFactory('Bundler');
    const bundler = await Bundler.deploy(await mockPaymentToken.getAddress());

    // Transfer nfts to the bundler
    await nft.safeBatchTransferFrom(owner, bundler.getAddress(), [1, 2, 3], [5, 5, 5], ZeroHash);

    // Mint payment tokens to buyer
    await mockPaymentToken.mint(buyer.address, ethers.parseEther('1000'));
    await mockPaymentToken.connect(buyer).approve(await bundler.getAddress(), ethers.parseEther('1000'));

    return {
      bundler,
      nft,
      mockPaymentToken,
      owner,
      buyer,
      another,
    };
  }

  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      const { bundler, owner } = await loadFixture(deployBundlerFixture);
      expect(await bundler.owner()).to.equal(owner.address);
    });
  });

  describe('Bundle Creation', function () {
    it('Should create a bundle successfully', async function () {
      const { bundler, nft, owner } = await loadFixture(deployBundlerFixture);

      await nft.setApprovalForAll(await bundler.getAddress(), true);

      const tx = await bundler.createBundle(await nft.getAddress(), [1, 2], [5, 5], ethers.parseEther('0.1'), 5);

      const bundle = await bundler.bundles(0);
      expect(bundle.nftContract).to.equal(await nft.getAddress());
      expect(bundle.totalQuantity).to.equal(5);
      expect(bundle.remainingQuantity).to.equal(5);
    });

    it('Should revert on zero price', async function () {
      const { bundler, nft, owner } = await loadFixture(deployBundlerFixture);

      await nft.setApprovalForAll(await bundler.getAddress(), true);

      await expect(bundler.createBundle(await nft.getAddress(), [1, 2], [5, 5], 0, 5)).to.be.revertedWithCustomError(
        bundler,
        'InvalidZeroPrice'
      );
    });

    it('Should revert on insufficient NFT balance', async function () {
      const { bundler, nft, owner } = await loadFixture(deployBundlerFixture);

      await expect(
        bundler
          .connect(owner)
          .createBundle(await nft.getAddress(), [1, 2, 3, 4, 5, 6], [10, 5, 5, 5, 5, 5], ethers.parseEther('0.1'), 5)
      ).to.be.revertedWithCustomError(bundler, 'InsufficientNftBalance');
    });
  });

  describe('Bundle Purchase', function () {
    it('Should allow purchasing a bundle', async function () {
      const { bundler, nft, mockPaymentToken, owner, buyer } = await loadFixture(deployBundlerFixture);

      await nft.setApprovalForAll(await bundler.getAddress(), true);

      await bundler.createBundle(await nft.getAddress(), [1, 2], [5, 5], ethers.parseEther('0.1'), 5);

      const initialOwnerBalance = await nft.balanceOf(owner.address, 1);
      const initialBuyerBalance = await nft.balanceOf(buyer.address, 1);

      await bundler.connect(buyer).purchaseBundle(0);

      const finalOwnerBalance = await nft.balanceOf(owner.address, 1);
      const finalBuyerBalance = await nft.balanceOf(buyer.address, 1);

      expect(finalOwnerBalance).to.equal(initialOwnerBalance - 5n);
      expect(finalBuyerBalance).to.equal(initialBuyerBalance + 5n);
    });

    it('Should deactivate bundle when quantity reaches zero', async function () {
      const { bundler, nft, owner, buyer } = await loadFixture(deployBundlerFixture);

      await nft.setApprovalForAll(await bundler.getAddress(), true);

      await bundler.createBundle(await nft.getAddress(), [1, 2], [5, 5], ethers.parseEther('0.1'), 1);

      await bundler.connect(buyer).purchaseBundle(0);

      const bundle = await bundler.bundles(0);
      expect(bundle.isActive).to.be.false;
      expect(bundle.remainingQuantity).to.equal(0);
    });
  });

  describe('Bundle Deactivation', function () {
    it('Should allow owner to deactivate bundle', async function () {
      const { bundler, nft, owner } = await loadFixture(deployBundlerFixture);

      await nft.setApprovalForAll(await bundler.getAddress(), true);

      await bundler.createBundle(await nft.getAddress(), [1, 2], [5, 5], ethers.parseEther('0.1'), 5);

      await bundler.deactivateBundle(0);

      const bundle = await bundler.bundles(0);
      expect(bundle.isActive).to.be.false;
      expect(bundle.remainingQuantity).to.equal(0);
    });
  });
});
