import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';
import { expect } from 'chai';
import { BigNumberish, toBigInt, ZeroAddress, ZeroHash } from 'ethers';
import { ethers } from 'hardhat';

describe('MultiNft', function () {
  async function deployFixture() {
    const [owner, ...otherAccounts] = await ethers.getSigners();
    const uri = 'https://my.metadata.sample/';
    const nftAmounts = [5, 10, 20, 50, 100, 1000];

    const MultiNft = await ethers.getContractFactory('MultiNft');
    const nft = await MultiNft.deploy(owner.address, uri, nftAmounts, ZeroHash);

    return { nft, owner, otherAccounts, uri, nftAmounts, MultiNft };
  }

  describe('Constructor', function () {
    it('Should deploy with correct initial values', async function () {
      const { nft, owner, uri, nftAmounts } = await loadFixture(deployFixture);

      expect(await nft.owner()).to.equal(owner);
      expect(await nft.uri(0)).to.equal(`${uri}{id}`);

      for (let i = 0; i < nftAmounts.length; i++) {
        expect(await nft.getSupply(i + 1)).to.equal(nftAmounts[i]);
      }
    });

    it('Should emit transfer batch event on deployment', async function () {
      const { MultiNft, owner, uri, nftAmounts } = await loadFixture(deployFixture);
      const ids = nftAmounts.map((a, i) => i + 1);
      const multiNft = await MultiNft.deploy(owner.address, uri, nftAmounts, ZeroHash);

      await expect(multiNft.deploymentTransaction())
        .to.emit(multiNft, 'TransferBatch')
        .withArgs(owner.address, ZeroAddress, owner.address, ids, nftAmounts);
    });

    it('Should fail on zero amount', async function () {
      const { MultiNft, owner, uri } = await loadFixture(deployFixture);

      await expect(MultiNft.deploy(owner.address, uri, [100, 0, 200], ZeroHash))
        .to.revertedWithCustomError(MultiNft, 'InvalidAmountAt')
        .withArgs(1n);
    });
  });
});
