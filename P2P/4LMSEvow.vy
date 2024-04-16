# @dev Implementation of 4 Person Last Man Standing/ Battle Royale
# CREATOR
# @c1im4cu5 - thebrotherscain@gmail.com

from vyper.interfaces import ERC20

#Define the state variables
owner: public(address)
intermediary: public(address)
evowAddress: address
groupAddresses: public(address[4])
group1: HashMap[address, bool]

TotalGroupDeposit: public(uint256)
IndividualDeposit: public(uint256)
CurrentValue: public(uint256)
Disputed: public(bool)
WinnerSubmissionTime: public(uint256)
DisputePeriod: public(uint256)

#States
# 0 = Initiated
# 1 = Betting complete
# 2 = Winner Chosen
# 3 = Payout Complete (Closed)
state: uint32
Winner: public(address)

# Define events
event Deposit:
 _peer: address
 _amount: uint256

event ScoreSubmitted:
 _peer: address

event PayoutToAddress:
 _peer: address
 _amount: uint256

event ScoreDisputed:
  _disputer: address

# Define the constructor function
@external
def __init__(_groupAddresses: address[4], _intermediary: address, _individualDeposit: uint256):
  self.owner = msg.sender
  self.TotalGroupDeposit = _individualDeposit * 4
  self.IndividualDeposit = _individualDeposit
  self.intermediary = _intermediary
  self.CurrentValue = 0

  self.state = 0
  self.Disputed = False
  self.groupAddresses = _groupAddresses
  self.DisputePeriod = (15 * 60) / 2 #15 minutes multiplied by 60 seconds divided by 2 seconds (block processing time)
  self.evowAddress = 0x53FcFc3D3624402Eb828611a37d2CA4e8Ec47197

  self.group1[_groupAddresses[0]] = False
  self.group1[_groupAddresses[1]] = False
  self.group1[_groupAddresses[2]] = False
  self.group1[_groupAddresses[3]] = False

@view
@external
def HaveAllDeposited() -> bool:

  for addr in self.groupAddresses:
    if self.group1[addr] == False:
      return False

  return True

@external
def DepositEVOW(_amount: uint256) -> bool:

  # Check that the contract state is open
  assert self.state == 0, "Deposits are closed"

  #Confirm sender is in group
  assert msg.sender in self.groupAddresses, "Sender is not in the peer group."

  #Find sender in group
  for addr in self.groupAddresses:

    # Check if the target address matches the address in the sublist
    if addr == msg.sender:

      #Cehcek sender has not made deposit
      assert self.group1[addr] == False, "Sender has already made their deposit"

      #Check _amount matches individual deposit
      assert _amount == self.IndividualDeposit, "Deposit does not match IndividualDeposit"

      #Get user balance
      userBalance: uint256 = ERC20(self.evowAddress).balanceOf(msg.sender)

      #Cancel if user does not possess funds for transfer
      assert userBalance == _amount or userBalance > _amount, "Not enough EVOW in wallet to proceed."

      #Perform transfer from predefinded allowance (Set by user)
      ERC20(self.evowAddress).transferFrom(msg.sender, self, _amount)

      #Add amount to CurrentValue amount
      self.CurrentValue += _amount

      #Set deposited to True for group peer address
      self.group1[addr] = True

      # Emit an event to notify listeners of the new deposit
      log Deposit(msg.sender, _amount)
      return True

  return False

@external
def DestroyContract() -> bool:

  assert self.state == 3, "State does not allow destruction."

  assert msg.sender == self.owner or msg.sender == self.intermediary, "Only the owner or intermediary can destroy the contract"

  if self.CurrentValue != 0:

    ERC20(self.evowAddress).transfer(msg.sender, self.CurrentValue)

  return True

@external
def SubmitWinner(_address: address) -> bool:

  # Check that the caller is the game leader
  assert msg.sender == self.owner, "Only the owner can submit the score."

  #Confirm winner in group
  assert _address in self.groupAddresses, "Winner must be in peer group"

  for addr in self.groupAddresses:
    if self.group1[addr] == False:
      return False

  self.Winner = _address

  self.WinnerSubmissionTime = block.timestamp

  self.state = 1

  # Emit an event
  log ScoreSubmitted(_address)

  return True

@external
def DisputeWinner() -> bool:
  # Check that the contract state is open
  assert self.state == 1, "Can only dispute in state one (Scores submitted)"

  # Check if the dispute period has elapsed
  assert block.timestamp < (self.WinnerSubmissionTime + self.DisputePeriod), "Dispute period has ended"

  # Check if the caller is group one or two
  assert msg.sender in self.groupAddresses, "Only a peer can dispute the score"

  #Set Disputed to True
  #Set state to 2 (Disputed)
  self.Disputed = True
  self.state = 2

  # Emit an event to notify listeners of the score dispute
  log ScoreDisputed(msg.sender)

  return True

@external
def Payout() -> bool:

  assert self.state == 1, "Unfit state"

  #Check dispute period expiration
  assert block.timestamp > (self.WinnerSubmissionTime + self.DisputePeriod), "Dispute period has not expired."

  #Check the initiator is the owner or intermediary
  assert msg.sender == self.owner or msg.sender == self.intermediary or msg.sender == self.Winner, "Only the contract initiator or the intermediary can initiate a payout."

  #Check if everyone has deposited
  for addr in self.groupAddresses:
    if self.group1[addr] == False:
      return False

  #Send to group one bettors
  ERC20(self.evowAddress).transfer(self.Winner, self.CurrentValue)

  log PayoutToAddress(self.Winner, self.CurrentValue)

  self.CurrentValue = 0

  self.state = 3

  return True

@external
def Intervention(_groupPercentages : uint256[4] ):

  #Confirm user is intermediary
  assert msg.sender == self.intermediary, "Only the intermediary can move disputed funds."

  assert _groupPercentages[0] + _groupPercentages[1] + _groupPercentages[2] + _groupPercentages[3] + 10 == 100, "Total percent should equal 100. Ten percent is automatically given to intermediary."

  #Breakout percentage payments
  addr1Payout: uint256 = (self.CurrentValue * _groupPercentages[0]) / 100
  addr2Payout: uint256 = (self.CurrentValue * _groupPercentages[1]) / 100
  addr3Payout: uint256 = (self.CurrentValue * _groupPercentages[2]) / 100
  addr4Payout: uint256 = (self.CurrentValue * _groupPercentages[3]) / 100
  intermediaryPayout: uint256 = (self.CurrentValue * 10) / 100

  #Payout to Intermediary and Log event
  ERC20(self.evowAddress).transfer(msg.sender, intermediaryPayout)
  log PayoutToAddress(msg.sender, intermediaryPayout)

  self.CurrentValue -= intermediaryPayout

  if addr1Payout != 0:

    #Send to group two bettors
    ERC20(self.evowAddress).transfer(self.groupAddresses[0], addr1Payout)
    log PayoutToAddress(self.groupAddresses[0], addr1Payout)

    self.CurrentValue -= addr1Payout

  if addr2Payout != 0:

    #Send to group two bettors
    ERC20(self.evowAddress).transfer(self.groupAddresses[1], addr2Payout)
    log PayoutToAddress(self.groupAddresses[1], addr2Payout)

    self.CurrentValue -= addr2Payout

  if addr3Payout != 0:

    #Send to group two bettors
    ERC20(self.evowAddress).transfer(self.groupAddresses[2], addr3Payout)
    log PayoutToAddress(self.groupAddresses[2], addr3Payout)

    self.CurrentValue -= addr3Payout

  if addr4Payout != 0:

    #Send to group two bettors
    ERC20(self.evowAddress).transfer(self.groupAddresses[3], addr4Payout)
    log PayoutToAddress(self.groupAddresses[3], addr4Payout)

    self.CurrentValue -= addr4Payout
