# @dev Implementation of Savings Contract
# CREATOR
# @c1im4cu5 - thebrotherscain@gmail.com

# How To
# User Inputs amount of blocks before contract will release funds.
# Contract accepts funds, but will not distribute until designated
# block number has passed. 

from vyper.interfaces import ERC20

currentBlock: uint256
savingsBlocks: public(uint256)
releasableBlock: public(uint256)

customers: public(address[2])

evowAddress: address

event CustomerDeposit:
  _address: address
  _token: String[4]
  _amount: uint256

event CustomerWithdrawal:
  _address: address
  _token: String[4]
  _amount: uint256

# Define the constructor function
@external
def __init__(_customer: address, _savingsBlocks: uint256):
  self.evowAddress = 0x53FcFc3D3624402Eb828611a37d2CA4e8Ec47197

  self.customers[0] = msg.sender
  self.customers[1] = _customer

  self.savingsBlocks = _savingsBlocks
  self.currentBlock = block.number
  self.releasableBlock = self.currentBlock + self.savingsBlocks

@view
@external
def BalanceEVOW() -> uint256:
  contractBalanceEVOW: uint256 = ERC20(self.evowAddress).balanceOf(self)
  return contractBalanceEVOW

@external
def DepositEVOW(_amount: uint256) -> bool:

  #Cancel if msg.sender is not in participant list
  assert msg.sender in self.customers, "Caller is not a participant."

  #Get user balance
  userBalance: uint256 = ERC20(self.evowAddress).balanceOf(msg.sender)

  #Make sure user balance can accommodate movement
  assert userBalance == _amount or userBalance > _amount, "Not enough USDC in wallet to proceed."

  #Perform transfer
  ERC20(self.evowAddress).transferFrom(msg.sender, self, _amount)

  #Log Deposit event
  log CustomerDeposit(msg.sender, "EVOW", _amount)

  #Return bool
  return True

@external
def WithdrawEVOW(_amount: uint256) -> bool:

  #Confirm sender is a customer of the contract
  assert msg.sender in self.customers, "Caller is not a participant"

  #Retrieve contract balance for USC
  contractBalance: uint256 = ERC20(self.evowAddress).balanceOf(self)

  #Confirm requested amount does not exceed contract balancce
  assert _amount == contractBalance or _amount < contractBalance, "Requested amount exceeds contract"

  #Confirm releasable block number has been reached
  #Input at contract Initiatiion
  assert block.number > self.releasableBlock or block.number == self.releasableBlock, "Funds cannot be released until saving period has ended. See releasableBlock"

  #Transfer funds
  ERC20(self.evowAddress).transfer(msg.sender, _amount)

  #Log Withdrawal event
  log CustomerWithdrawal(msg.sender, "EVOW", _amount)

  return True
