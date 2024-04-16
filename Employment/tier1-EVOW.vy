# @dev Implementation of One tiered Employment contract
# CREATOR
# @c1im4cu5 - thebrotherscain@gmail.com

from vyper.interfaces import ERC20

# Define the state variables
Employer: public(address)
Contractor: public(address)
Intermediary: public(address)

ContractorComplete: public(bool)
ContractorPaid: public(bool)
ContractDisputed: public(bool)

DepositAmount: public(uint256)
PaymentAmount: public(uint256)
CurrentValue: public(uint256)

#State Values
#0 = Open
#1 = Initiated/Funded
#2 = Contractor Registered complete
#3 = Employer registered complete, funds dispersed and closed
#3 = Intermediary Closed with resolution of funds
#9 = disputed
state: uint32

#Token Address
evowAddress: address

#Define Events
event ContractInitiated:
  _stateChanged: bool

event ContractCompleted:
  _isComplete: bool

event Payout:
  _addr: address
  _amount: uint256

event IntermediaryResolvedDispute:
  _isComplete: bool

# Define the constructor function
@external
def __init__(_contractor: address, _intermediary: address, _amt: uint256):
  self.Employer = msg.sender
  self.PaymentAmount = _amt
  self.DepositAmount = _amt * 2
  self.Contractor = _contractor
  self.Intermediary = _intermediary
  self.ContractorComplete = False
  self.ContractorPaid = False
  self.ContractDisputed = False
  self.CurrentValue = 0
  self.state = 0
  self.evowAddress = 0x53FcFc3D3624402Eb828611a37d2CA4e8Ec47197

@external
def DepositEVOW(_amount: uint256) -> bool:

  #Cancel if msg.sender is not in participant list
  assert msg.sender == self.Employer or msg.sender == self.Intermediary, "Caller is not the employer."

  #Get user balance
  userBalance: uint256 = ERC20(self.evowAddress).balanceOf(msg.sender)

  #Cancel if user does not possess funds for transfer
  assert userBalance == _amount or userBalance > _amount, "Not enough USDC in wallet to proceed."

  #SWTH is native token.
  #Value is found in msg.value
  #Confirm value matches expected deposit
  #To help combast fraud, the employer must deposit 2x the payment amt.
  #The additional funds can/will be used in the event of a disputed contract
  #Intermediary can choose how to disperse funds
  assert _amount == self.DepositAmount, "Value does not match expected amount. (2x Payment)."

  #Perform transfer from predefinded allowance (Set by user)
  ERC20(self.evowAddress).transferFrom(msg.sender, self, _amount)

  self.CurrentValue += _amount

  #Change state to initiated (1)
  #See states above
  self.state = 1

  #Log Initiation event
  log ContractInitiated(True)

  return True

@external
def ContractorRegisterComplete() -> bool:

  #Check user is the contractor
  assert msg.sender == self.Contractor, "Only the contractor can register their completion."

  #Confirm state
  assert self.state == 1, "State does not allow for registered completion"

  #Confirm not already complete
  assert self.ContractorComplete == False, "Contract already registered complete."

  #Change state
  #2 = Contractor complete
  self.state = 2

  #Change contractor complete to True
  self.ContractorComplete = True

  return True

@external
def EmployerDispute() -> bool:

  #Only the employer can access this function
  assert msg.sender == self.Employer, "Only the employer can enter a dispute for work completed."

  #Confirm state
  assert self.state == 2, "State does not allow for registered completion"

  #Confirm contractor registered complete
  assert self.ContractorComplete == True, "Contractor not registered completion"

  #Confirm contractor registered complete
  assert self.ContractDisputed == False, "Contract already disputed"

  self.ContractDisputed = True

  self.state = 9

  return True

@external
def EmployerRegisterComplete() -> bool:

  #Check user is the contractor
  assert msg.sender == self.Employer, "Only the employer can register their acceptance."

  #Confirm state
  assert self.state == 2, "State does not allow for registered completion"

  #Confirm contractor registered complete
  assert self.ContractorComplete == True, "Contractor not registered completion"

  #Change state
  #3 = Employer agreed
  self.state = 3

  #Send monies to contractor
  ERC20(self.evowAddress).transfer(self.Contractor, self.PaymentAmount)

  self.CurrentValue -= self.PaymentAmount

  #Log Payment Event
  log Payout(self.Contractor, self.PaymentAmount)

  #Send Held deposit monies back to employer
  ERC20(self.evowAddress).transfer(self.Employer, self.PaymentAmount)

  log Payout(self.Employer, self.PaymentAmount)

  self.CurrentValue -= self.PaymentAmount

  return True

@external
def Intervention(PercentContractor: uint256, PercentEmployer: uint256) -> bool:

  assert msg.sender == self.Intermediary, "Only the intermediary can access this function."

  PercentIntermediary: uint256 = 10

  totalPaidPercentage: uint256 = PercentEmployer + PercentContractor + PercentIntermediary

  assert totalPaidPercentage == 100, "Paid total should meet 100. 10% is given to the mediator"

  intermediaryPayout:uint256 = (self.DepositAmount * PercentIntermediary) / 100

  ERC20(self.evowAddress).transfer(self.Intermediary, intermediaryPayout)

  self.CurrentValue -= intermediaryPayout

  log Payout(self.Intermediary, intermediaryPayout)

  if PercentEmployer != 0:

    employerPayout: uint256 = (self.DepositAmount * PercentEmployer) / 100

    ERC20(self.evowAddress).transfer(self.Employer, employerPayout)

    log Payout(self.Employer, employerPayout)

    self.CurrentValue -= employerPayout


  if PercentContractor != 0:

    contractorPayout: uint256 = (self.DepositAmount * PercentContractor) / 100

    ERC20(self.evowAddress).transfer(self.Contractor, contractorPayout)

    self.CurrentValue -= contractorPayout

    log Payout(self.Contractor, contractorPayout)

  log IntermediaryResolvedDispute(True)

  self.state = 3

  return True
