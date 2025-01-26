import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';
import { expect } from 'chai';
import { BigNumberish, toBigInt, ZeroAddress, ZeroHash } from 'ethers';
import { ethers } from 'hardhat';

describe('MultiNft', function () {
  const nftAmounts = [5, 10, 20, 50, 100, 1000];

  async function deployFixture() {
    const [owner, ...otherAccounts] = await ethers.getSigners();
    const uri = 'https://my.metadata.sample/';

    const MultiNft = await ethers.getContractFactory('MultiNft');
    const nft = await MultiNft.deploy(owner.address, uri, nftAmounts);

    return { nft, owner, otherAccounts, uri, nftAmounts };
  }

  describe('Constructor', function () {
    it('Should deploy with correct initial values', async function () {
      const { nft, owner, uri, nftAmounts } = await loadFixture(deployFixture);

      expect(await nft.owner()).to.equal(owner);
      expect(await nft.uri(0)).to.equal(`${uri}{id}`);
    });
  });
});
