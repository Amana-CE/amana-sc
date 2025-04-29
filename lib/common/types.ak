///
/// Common type definitions shared across all Amana CE validators
///

/// PubKeyHash is a hash of a verification key
pub type PubKeyHash = ByteArray

/// General status types for active/inactive state
pub type Status {
  StatusActive
  StatusInactive
}

/// Role types for members
pub type MemberRole {
  RoleAdmin
  RoleMember
}

/// Member status
pub type MemberStatus {
  MemberActive
  MemberSuspended
  MemberRemoved
}

/// Entity status
pub type EntityStatus {
  EntityActive
  EntitySuspended
  EntityDissolved
}

/// Types of transaction actions
pub type TransactionType {
  TxDeposit
  TxWithdrawal
  TxLoan
  TxRepayment
  TxFee
}

/// Status of a transaction
pub type TransactionStatus {
  TxPending
  TxApproved
  TxRejected
  TxExecuted
  TxExpired
}

/// Types of proposals
pub type ProposalType {
  PropParameterUpdate
  PropMemberAction
  PropTreasuryAction
  PropGeneric
}

/// Status of a proposal
pub type ProposalStatus {
  PropActive
  PropApproved
  PropRejected
  PropExecuted
  PropExpired
  PropCanceled
}

/// Voting choices
pub type VoteChoice {
  VoteFor
  VoteAgainst
  VoteAbstain
}

/// Address type representing a destination on the blockchain
pub type Address = ByteArray

/// Time representation in milliseconds since epoch
pub type Timestamp = Int

/// Amount type for financial values in lovelace
pub type Amount = Int

/// Unique identifier type
pub type Id = ByteArray

/// Result type for operations that can succeed or fail
pub type Result<a, e> {
  Ok(a)
  Error(e)
}

/// Option type for optional values - note: this is already defined in Aiken's prelude
/// but included here for clarity
pub type Option<a> {
  Some(a)
  None
}