// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Bundler is Ownable {
  using SafeERC20 for IERC20;

  struct Bundle {
    IERC1155 nftContract;
    uint256[] nftIds;
    uint256[] amounts;
    uint256 price;
    bool isActive;
  }

  IERC20 public paymentToken;
  Bundle[] public bundles;

  event BundleCreated(uint256 bundleId, address nftContract, uint256 price);
  event BundlePurchased(uint256 bundleId, address buyer);

  error InvalidZeroPrice();
  error MismatchedNftAmounts();
  error InsufficientNftBalance(uint256);
  error BundleNotActive(uint256);

  constructor(address _paymentToken) Ownable(msg.sender) {
    paymentToken = IERC20(_paymentToken);
  }

  function createBundle(
    IERC1155 _nftContract,
    uint256[] memory _nftIds,
    uint256[] memory _amounts,
    uint256 _price
  ) external returns (uint256) {
    if (_nftIds.length != _amounts.length) {
      revert MismatchedNftAmounts();
    }

    if (_price == 0) {
      revert InvalidZeroPrice();
    }

    for (uint256 i = 0; i < _nftIds.length; i++) {
      uint256 nftId = _nftIds[i];
      if (_nftContract.balanceOf(msg.sender, nftId) < _amounts[i]) {
        revert InsufficientNftBalance(nftId);
      }
    }

    Bundle memory newBundle = Bundle({
      nftContract: _nftContract,
      nftIds: _nftIds,
      amounts: _amounts,
      price: _price,
      isActive: true
    });

    bundles.push(newBundle);
    emit BundleCreated(bundles.length - 1, address(_nftContract), _price);
    return bundles.length - 1;
  }

  function purchaseBundle(uint256 _bundleId) external {
    Bundle storage bundle = bundles[_bundleId];
    if (!bundle.isActive) {
      revert BundleNotActive(_bundleId);
    }
    address owner = owner();
    paymentToken.safeTransferFrom(msg.sender, owner, bundle.price);

    for (uint256 i = 0; i < bundle.nftIds.length; i++) {
      bundle.nftContract.safeTransferFrom(owner, msg.sender, bundle.nftIds[i], bundle.amounts[i], "");
    }

    emit BundlePurchased(_bundleId, msg.sender);
  }

  function deactivateBundle(uint256 _bundleId) external onlyOwner {
    bundles[_bundleId].isActive = false;
  }
}
