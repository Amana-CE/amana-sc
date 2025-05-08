// lib/governance/types.ak
use aiken/crypto.{VerificationKeyHash}
use cardano/transaction.{OutputReference}

/// Types for the Governance contract
/// These types represent the core data structures used for decision-making 
/// processes within a SACCO entity
/// Proposal status enumeration
pub type ProposalStatus {
  Active
  Approved
  Rejected
  Executed
  Cancelled
}

/// Vote options enumeration
pub type Vote {
  For
  Against
  Abstain
}

/// Proposal categories
pub type ProposalCategory {
  TreasuryAction
  ParameterChange
  MembershipChange
  Other
}

/// Proposal data structure
pub type Proposal {
  title: ByteArray,
  description: ByteArray,
  category: ProposalCategory,
  proposer: VerificationKeyHash,
  creation_time: Int,
  voting_deadline: Int,
  status: ProposalStatus,
  // Specific action to execute if approved
  execution_data: Data,
  // Voting record: list of (member hash, vote) pairs
  votes: List<Pair<VerificationKeyHash, Vote>>,
  // Vote tallies
  for_votes: Int,
  against_votes: Int,
  abstain_votes: Int,
}

/// Governance parameters
pub type GovernanceParams {
  // Percentage of votes needed to approve a proposal (0-100)
  approval_threshold: Int,
  // Minimum voting period in milliseconds
  minimum_voting_period: Int,
  // Quorum percentage required (0-100)
  quorum_percentage: Int,
}

/// Governance datum - stored on-chain
pub type GovernanceDatum {
  entity_utxo_ref: OutputReference,
  treasury_utxo_ref: OutputReference,
  params: GovernanceParams,
  proposals: List<Proposal>,
  next_proposal_id: Int,
}

/// Redeemer actions
pub type GovernanceAction {
  // Create a new proposal
  CreateProposal {
    title: ByteArray,
    description: ByteArray,
    category: ProposalCategory,
    voting_deadline: Int,
    execution_data: Data,
  }
  // Cast a vote on a proposal
  CastVote { proposal_id: Int, vote: Vote }
  // Execute an approved proposal
  ExecuteProposal { proposal_id: Int }
  // Cancel a proposal (only proposer or admin)
  CancelProposal { proposal_id: Int }
  // Update governance parameters (requires special approval)
  UpdateParams { new_params: GovernanceParams }
}
