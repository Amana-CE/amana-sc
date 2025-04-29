///
/// Governance types
///

use common/types.{
  Id, ProposalStatus, ProposalType, PubKeyHash, Timestamp, VoteChoice
}

/// Execution parameters for a proposal
pub type ExecutionParameters {
  Parameter {
    // Parameters for updating entity parameters
    entity_id: Id,
    new_parameters: ByteArray, // Serialized parameters
  }
  Member {
    // Parameters for member actions
    entity_id: Id,
    member_id: Id,
    action_data: ByteArray, // Serialized action data
  }
  Treasury {
    // Parameters for treasury actions
    entity_id: Id,
    action_data: ByteArray, // Serialized action data
  }
  Generic {
    // Generic action parameters
    data: ByteArray, // Serialized generic data
  }
}

/// Proposal record
pub type Proposal {
  proposal_id: Id,
  entity_id: Id,
  title: ByteArray,
  description: ByteArray,
  proposal_type: ProposalType,
  proposer: PubKeyHash,
  creation_timestamp: Timestamp,
  voting_end_timestamp: Timestamp,
  status: ProposalStatus,
  execution_params: ExecutionParameters,
  metadata_hash: ByteArray,
}

/// Vote record
pub type Vote {
  proposal_id: Id,
  voter: PubKeyHash,
  vote: VoteChoice,
  timestamp: Timestamp,
}

/// Voting results
pub type VotingResults {
  proposal_id: Id,
  for_votes: Int,
  against_votes: Int,
  abstain_votes: Int,
  total_eligible_voters: Int,
}

/// Governance datum
pub type GovernanceDatum {
  entity_id: Id,
  proposals: List<Proposal>,
  votes: List<Vote>,
}

/// Governance redeemer - defines actions that can be performed
pub type GovernanceAction {
  /// Create a new proposal for voting
  CreateProposal {
    entity_id: Id,
    title: ByteArray,
    description: ByteArray,
    proposal_type: ProposalType,
    voting_period: Int,
    execution_params: ExecutionParameters,
    metadata_hash: ByteArray,
  }
  /// Cast a vote on a proposal
  CastVote {
    proposal_id: Id,
    vote: VoteChoice,
  }
  /// Finalize a proposal after voting period ends
  FinalizeProposal {
    proposal_id: Id,
  }
  /// Execute an approved proposal
  ExecuteProposal {
    proposal_id: Id,
  }
  /// Cancel an active proposal
  CancelProposal {
    proposal_id: Id,
  }
}

/// Error codes for governance operations
pub type GovernanceError {
  /// Proposal with the given ID was not found
  ProposalNotFound
  /// Voter has already voted on the proposal
  AlreadyVoted
  /// The voting period for the proposal has ended
  VotingPeriodEnded
  /// The voting period for the proposal has not ended
  VotingPeriodNotEnded
  /// Proposal is not in the correct state for the action
  InvalidProposalState
  /// Caller is not authorized to perform the action
  Unauthorized
  /// Invalid parameters provided
  InvalidParameters
}