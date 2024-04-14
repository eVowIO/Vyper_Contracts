
from vyper.interfaces import ERC20

evowAddress: address
owner: address
mediator: address

Participants: public(address[6])

CurrentPeriod: public(uint256)
UserPayment: public(uint256)
CurrentValue: public(uint256)
expectedMonthlyPayout: uint256

paymentMapping: HashMap[address, HashMap[uint256, bool]]

event ParticipantPayment:
  _participant: address
  _amount: uint256

event AllowanceApproval:
  _participant: address
  _amount: uint256

event PayoutEvent:
  _address: address
  _amount: uint256

# Define the constructor function
@external
def __init__(_mediator: address, _Participants: address[6], _UserPayment: uint256):

  #Initiatiion variables
  #_evow contract address will be sent as a variable each time to replicate
  # between chains
  self.evowAddress = 0x53FcFc3D3624402Eb828611a37d2CA4e8Ec47197
  self.owner = msg.sender
  self.mediator = _mediator
  self.Participants = _Participants
  self.UserPayment = _UserPayment
  self.expectedMonthlyPayout = self.UserPayment * 6
  self.CurrentPeriod = 1
  self.CurrentValue = 0

  for addr in _Participants:

    #Map all addresses and periods to false payment
    self.paymentMapping[addr][0] = False
    self.paymentMapping[addr][1] = False
    self.paymentMapping[addr][2] = False
    self.paymentMapping[addr][3] = False
    self.paymentMapping[addr][4] = False
    self.paymentMapping[addr][5] = False

@view
@external
def IsPeriodPaid() -> bool:
  for addr in self.Participants:
    if self.paymentMapping[addr][self.CurrentPeriod] == True:
      pass
    if self.paymentMapping[addr][self.CurrentPeriod] == False:
      return False
  return True

@view
@external
def CurrentPeriodAddressPaidStatus(_address: address) -> bool:
  return self.paymentMapping[_address][self.CurrentPeriod]

@external
def DepositEVOW(_amount: uint256) -> bool:

  #Assert value matches expected value
  assert _amount == self.UserPayment, "Amount must match expected user period deposit."

  #Cancel if msg.sender is not in participant list
  assert msg.sender in self.Participants, "Caller is not a participant."

  #Check if payment has already occurred for the current period
  assert self.paymentMapping[msg.sender][self.CurrentPeriod] == False, "Payment already submitted for current period"

  #Get user balance
  userBalance: uint256 = ERC20(self.evowAddress).balanceOf(msg.sender)

  #Assert user balance can accommodate the deposit
  assert userBalance == self.UserPayment or userBalance > self.UserPayment, "Not enough EVOW in wallet to proceed."

  #Perform transfer
  ERC20(self.evowAddress).transferFrom(msg.sender, self, self.UserPayment)

  #Emit event log
  log ParticipantPayment(msg.sender, self.UserPayment)

  #Set Mapping to Period Paid for Address
  self.paymentMapping[msg.sender][self.CurrentPeriod] = True

  #Add value to overall current running total
  self.CurrentValue += self.UserPayment

  #Return bool
  return True

@external
def InitiatePeriodPayout() -> bool:

  assert msg.sender == self.owner or msg.sender == self.mediator, "Only the owner or mediator can submit a payout request."

  #Get and assert period is closed
  periodStatus: bool = self.checkPeriodStatus()
  assert periodStatus == True, "The period is not close for payout due to missing transfers from participant(s). Please check unpaidAddresses() function to acquire the missing participants."

  poAddress: address = self.Participants[self.CurrentPeriod-1]

  assert self.expectedMonthlyPayout == self.CurrentValue or self.expectedMonthlyPayout > self.CurrentValue, "The current value of the contract is less than expected payout."

  ERC20(self.evowAddress).transfer(poAddress, self.expectedMonthlyPayout)

  log PayoutEvent(poAddress, self.expectedMonthlyPayout)

  self.CurrentValue = 0
  self.CurrentPeriod += 1

  return True

@external
def Intervention(_address: address) -> bool:
  assert msg.sender == self.mediator, "Only the mediator can access this function."
  assert _address in self.Participants, "Send-To Address must be associated with a participant."
  ERC20(self.evowAddress).transfer(_address, self.CurrentValue)
  self.CurrentValue = 0
  return True

@internal
def checkPeriodStatus() -> bool:

  for addr in self.Participants:
    if self.paymentMapping[addr][self.CurrentPeriod] == True:
      pass
    if self.paymentMapping[addr][self.CurrentPeriod] == False:
      return False
  return True
