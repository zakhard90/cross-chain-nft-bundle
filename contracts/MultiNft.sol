// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MultiNft is Ownable, ERC1155 {
  mapping(uint256 => uint256) private _supplies;

  error InvalidAmountAt(uint256 index);

  constructor(
    address _owner,
    string memory _uri,
    uint256[] memory _amounts,
    bytes memory _data
  ) ERC1155(_uri) Ownable(_owner) {
    uint256[] memory ids = new uint256[](_amounts.length);

    for (uint256 i; i < _amounts.length; ) {
      uint256 id = i + 1;
      uint256 amount = _amounts[i];

      if (amount == 0) {
        revert InvalidAmountAt(i);
      }

      ids[i] = id;
      _supplies[id] = amount;

      unchecked {
        ++i;
      }
    }
    _mintBatch(_owner, ids, _amounts, _data);
  }

  function uri(uint256) public view override returns (string memory) {
    return string.concat(ERC1155.uri(0), "{id}");
  }

  function getSupply(uint256 id) external view returns (uint256 amount) {
    return _supplies[id];
  }
}
