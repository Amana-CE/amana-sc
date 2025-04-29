///
/// Governance validation logic
///

use aiken/list
use aiken/transaction.{Transaction}

use common/constants
use common/types.{ProposalStatus, PropActive, PropApproved, PubKeyHash, Timestamp, VoteChoice}
use common/utils
use governance/types.{
  ExecutionParameters, GovernanceDatum, Proposal, Vote, VotingResults
}

/// Find a proposal by ID
pub fn find_proposal_by_id(
  proposals: List<Proposal>,
  proposal_id: ByteArray,
) -> Option<Proposal> {
  list.find(
    proposals,
    fn(proposal) { proposal.proposal_id == proposal_id },
  )
}

/// Get all votes for a specific proposal
pub fn get_votes_for_proposal(
  votes: List<Vote>,
  proposal_id: ByteArray,
) -> List<Vote> {
  list.filter(
    votes,
    fn(vote) { vote.proposal_id == proposal_id },
  )
}

/// Calculate voting results for a proposal
pub fn calculate_voting_results(
  votes: List<Vote>,
  proposal_id: ByteArray,
  total_eligible_voters: Int,
) -> VotingResults {
  let proposal_votes = get_votes_for_proposal(votes, proposal_id)
  
  let for_votes =
    list.count(
      proposal_votes,
      fn(vote) { vote.vote == VoteFor },
    )
  
  let against_votes =
    list.count(
      proposal_votes,
      fn(vote) { vote.vote == VoteAgainst },
    )
  
  let abstain_votes =
    list.count(
      proposal_votes,
      fn(vote) { vote.vote == VoteAbstain },
    )
  
  VotingResults {
    proposal_id,
    for_votes,
    against_votes,
    abstain_votes,
    total_eligible_voters,
  }
}

/// Validate proposal creation
pub fn validate_create_proposal(
  entity_id: ByteArray,
  title: ByteArray,
  description: ByteArray,
  voting_period: Int,
  proposer: PubKeyHash,
  tx: Transaction,
  current_time: Timestamp,
) -> Bool {
  // Title and description must not be empty
  list.length(title) > 0 &&
    list.length(title) <= constants.max_proposal_title_length &&
    list.length(description) > 0 &&
    list.length(description) <= constants.max_proposal_description_length &&
    // Voting period must be positive
    voting_period > 0 &&
    // Transaction must be signed by the proposer
    utils.is_signed_by(tx, proposer)
  // Note: In a full implementation, we would verify that the proposer is a valid member
}

/// Check if a user has already voted on a proposal
pub fn has_voted(
  votes: List<Vote>,
  proposal_id: ByteArray,
  voter: PubKeyHash,
) -> Bool {
  list.any(
    votes,
    fn(vote) {
      vote.proposal_id == proposal_id && vote.voter == voter
    },
  )
}

/// Validate vote casting
pub fn validate_cast_vote(
  proposals: List<Proposal>,
  votes: List<Vote>,
  proposal_id: ByteArray,
  voter: PubKeyHash,
  tx: Transaction,
  current_time: Timestamp,
) -> Bool {
  when find_proposal_by_id(proposals, proposal_id) is {
    Some(proposal) -> {
      // Proposal must be active
      proposal.status == PropActive &&
        // Voting period must not have ended
        current_time <= proposal.voting_end_timestamp &&
        // Voter must not have already voted
        !has_voted(votes, proposal_id, voter) &&
        // Transaction must be signed by the voter
        utils.is_signed_by(tx, voter)
      // Note: In a full implementation, we would verify that the voter is a valid member
    }
    None -> False
  }
}

/// Determine if a proposal passes based on voting results
pub fn does_proposal_pass(
  voting_results: VotingResults,
  voting_threshold_percent: Int,
) -> Bool {
  let participation = voting_results.for_votes + voting_results.against_votes + voting_results.abstain_votes
  
  // Require at least some participation
  if participation == 0 {
    False
  } else {
    // Calculate percentage of FOR votes out of total votes cast
    let for_percentage = (voting_results.for_votes * 100) / participation
    
    // Proposal passes if FOR votes exceed threshold
    for_percentage >= voting_threshold_percent
  }
}

/// Validate proposal finalization
pub fn validate_finalize_proposal(
  proposals: List<Proposal>,
  votes: List<Vote>,
  proposal_id: ByteArray,
  voting_threshold_percent: Int,
  tx: Transaction,
  current_time: Timestamp,
) -> Bool {
  when find_proposal_by_id(proposals, proposal_id) is {
    Some(proposal) -> {
      // Proposal must be active
      proposal.status == PropActive &&
        // Voting period must have ended
        current_time > proposal.voting_end_timestamp
      // Note: Anyone can finalize a proposal once the voting period has ended
    }
    None -> False
  }
}

/// Validate proposal execution
pub fn validate_execute_proposal(
  proposals: List<Proposal>,
  proposal_id: ByteArray,
  tx: Transaction,
) -> Bool {
  when find_proposal_by_id(proposals, proposal_id) is {
    Some(proposal) -> {
      // Proposal must be approved
      proposal.status == PropApproved
      // Note: In a full implementation, we would verify that the transaction
      // actually executes the proposed action
    }
    None -> False
  }
}

/// Validate proposal cancellation
pub fn validate_cancel_proposal(
  proposals: List<Proposal>,
  proposal_id: ByteArray,
  canceller: PubKeyHash,
  tx: Transaction,
) -> Bool {
  when find_proposal_by_id(proposals, proposal_id) is {
    Some(proposal) -> {
      // Proposal must be active
      proposal.status == PropActive &&
        // Only the proposer or an admin can cancel a proposal
        (canceller == proposal.proposer || 
         utils.is_signed_by(tx, canceller))
    }
    None -> False
  }
}