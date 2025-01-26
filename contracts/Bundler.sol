// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Client } from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import { CCIPReceiver } from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";

contract Bundler is CCIPReceiver, Ownable, ReentrancyGuard, IERC1155Receiver {
  using SafeERC20 for IERC20;

  struct Bundle {
    address nftContract;
    uint256[] nftIds;
    uint256[] amounts;
    uint256 price;
    uint256 totalQuantity;
    uint256 remainingQuantity;
    bool isActive;
  }

  IERC20 public immutable paymentToken;
  Bundle[] public bundles;

  mapping(address => mapping(uint256 => uint256)) private lockedAmounts;

  event BundleCreated(uint256 indexed bundleId, address indexed nftContract, uint256 price, uint256 quantity);
  event BundlePurchased(uint256 indexed bundleId, address indexed buyer);

  error InvalidZeroPrice();
  error InvalidZeroQuantity();
  error InvalidZeroAddress();
  error MismatchedNftAmounts();
  error InsufficientNftBalance(uint256);
  error InvalidTokenAmount();
  error BundleNotActive(uint256);
  error TransferFailed();

  constructor(address _paymentToken, address _router) Ownable(msg.sender) CCIPReceiver(_router) {
    paymentToken = IERC20(_paymentToken);
  }

  function createBundle(
    IERC1155 _nftContract,
    uint256[] calldata _nftIds,
    uint256[] calldata _amounts,
    uint256 _price,
    uint256 _quantity
  ) external onlyOwner returns (uint256) {
    if (_nftIds.length != _amounts.length) revert MismatchedNftAmounts();
    if (_price == 0) revert InvalidZeroPrice();
    if (_quantity == 0) revert InvalidZeroQuantity();

    address nftContractAddress = address(_nftContract);

    for (uint256 i; i < _nftIds.length; ++i) {
      uint256 nftId = _nftIds[i];
      uint256 totalLocked = lockedAmounts[nftContractAddress][nftId];

      if (_nftContract.balanceOf(msg.sender, nftId) < (_amounts[i] * _quantity) + totalLocked) {
        revert InsufficientNftBalance(nftId);
      }

      lockedAmounts[nftContractAddress][nftId] += _amounts[i] * _quantity;
    }

    Bundle memory newBundle = Bundle({
      nftContract: nftContractAddress,
      nftIds: _nftIds,
      amounts: _amounts,
      price: _price,
      totalQuantity: _quantity,
      remainingQuantity: _quantity,
      isActive: true
    });

    uint256 bundleId = bundles.length;
    bundles.push(newBundle);
    emit BundleCreated(bundleId, nftContractAddress, _price, _quantity);
    return bundleId;
  }

  function purchaseBundle(uint256 _bundleId) external {
    _purchaseBundleInternal(_bundleId, msg.sender);
  }

  function deactivateBundle(uint256 _bundleId) external onlyOwner {
    Bundle storage bundle = bundles[_bundleId];
    address nftContractAddress = bundle.nftContract;

    for (uint256 i; i < bundle.nftIds.length; ++i) {
      lockedAmounts[nftContractAddress][bundle.nftIds[i]] -= bundle.amounts[i] * bundle.remainingQuantity;
    }

    bundle.isActive = false;
    bundle.remainingQuantity = 0;
  }

  function supportsInterface(bytes4 interfaceId) public pure override(IERC165, CCIPReceiver) returns (bool) {
    return
      interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
      interfaceId == 0x4e2312e0 || // ERC1155Receiver Interface ID
      interfaceId == 0x324cf6a8; // CCIP Receiver Interface ID
  }

  function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
    return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(
    address,
    address,
    uint256[] calldata,
    uint256[] calldata,
    bytes calldata
  ) external pure returns (bytes4) {
    return this.onERC1155BatchReceived.selector;
  }

  function _purchaseBundleInternal(uint256 _bundleId, address _buyer) internal nonReentrant {
    Bundle storage bundle = bundles[_bundleId];

    if (!bundle.isActive || bundle.remainingQuantity == 0) {
      revert BundleNotActive(_bundleId);
    }

    unchecked {
      bundle.remainingQuantity--;
    }

    if (bundle.remainingQuantity == 0) {
      bundle.isActive = false;
    }

    address nftContractAddress = bundle.nftContract;
    for (uint256 i; i < bundle.nftIds.length; ++i) {
      lockedAmounts[nftContractAddress][bundle.nftIds[i]] -= bundle.amounts[i];
    }

    address contractOwner = owner();
    if (!paymentToken.transferFrom(_buyer, contractOwner, bundle.price)) {
      revert TransferFailed();
    }

    IERC1155(nftContractAddress).safeBatchTransferFrom(contractOwner, _buyer, bundle.nftIds, bundle.amounts, "");

    emit BundlePurchased(_bundleId, _buyer);
  }

  function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
    (uint256 bundleId, address buyer) = abi.decode(message.data, (uint256, address));

    if (buyer == address(0)) {
      revert InvalidZeroAddress();
    }
    if (message.destTokenAmounts.length == 0) {
      revert InvalidTokenAmount();
    }

    _purchaseBundleInternal(bundleId, buyer);
  }
}
