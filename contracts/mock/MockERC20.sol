// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
  uint8 private immutable _decimals;
  bool private _isFrozen;

  constructor(string memory _name, string memory _symbol, uint8 _decimalsValue) ERC20(_name, _symbol) {
    _decimals = _decimalsValue;
  }

  function mint(address _to, uint256 _amount) external {
    _mint(_to, _amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return _decimals;
  }

  function freeze(bool _frozen) public {
    _isFrozen = _frozen;
  }

  function transferFrom(address _from, address _to, uint256 _value) public override returns (bool) {
    if (_isFrozen) {
      return false;
    }

    address spender = msg.sender;
    _spendAllowance(_from, spender, _value);
    _transfer(_from, _to, _value);
    return true;
  }
}
