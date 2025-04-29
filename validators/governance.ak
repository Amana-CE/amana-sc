///
/// Governance Validator
///
/// This validator enables transparent and democratic decision-making within SACCOs.
/// It facilitates proposal creation, voting, and execution of approved decisions.
///

use aiken/list
use aiken/transaction.{ScriptContext, Spend, Transaction}

use common/constants
use common/types.{ProposalStatus, PropActive, PubKeyHash, VoteChoice}
use common/utils
use governance/types.{
  ExecutionParameters, GovernanceDatum, Proposal, GovernanceAction, Vote
}
use governance/validators

/// Governance validator
validator {
  fn spend(datum_opt: Option<GovernanceDatum>, redeemer: GovernanceAction, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } = ctx
    
    when purpose is {
      Spend(own_ref) -> {
        when redeemer is {
          GovernanceAction.CreateProposal { entity_id, title, description, proposal_type, voting_period, execution_params, metadata_hash } -> {
            // Need existing datum for governance operations
            expect Some(datum) = datum_opt
            
            // Get proposer's public key (must be a signer)
            expect Some(proposer) = list.head(transaction.extra_signatories)
            
            // Get current time from transaction validity range
            expect Some(current_time) = utils.get_current_time(transaction)
            
            // Validate proposal creation
            validators.validate_create_proposal(
              entity_id,
              title,
              description,
              voting_period,
              proposer,
              transaction,
              current_time,
            )
          }
          
          GovernanceAction.CastVote { proposal_id, vote } -> {
            // Need existing datum for governance operations
            expect Some(datum) = datum_opt
            
            // Get voter's public key (must be a signer)
            expect Some(voter) = list.head(transaction.extra_signatories)
            
            // Get current time from transaction validity range
            expect Some(current_time) = utils.get_current_time(transaction)
            
            // Validate vote casting
            validators.validate_cast_vote(
              datum.proposals,
              datum.votes,
              proposal_id,
              voter,
              transaction,
              current_time,
            )
          }
          
          GovernanceAction.FinalizeProposal { proposal_id } -> {
            // Need existing datum for governance operations
            expect Some(datum) = datum_opt
            
            // Get current time from transaction validity range
            expect Some(current_time) = utils.get_current_time(transaction)
            
            // Find the proposal
            expect Some(proposal) = validators.find_proposal_by_id(datum.proposals, proposal_id)
            
            // Voting threshold from entity is assumed to be stored or passed somehow
            // For now, we'll use a hardcoded threshold percentage
            let voting_threshold_percent = constants.default_voting_threshold
            
            // Validate proposal finalization
            validators.validate_finalize_proposal(
              datum.proposals,
              datum.votes,
              proposal_id,
              voting_threshold_percent,
              transaction,
              current_time,
            )
          }
          
          GovernanceAction.ExecuteProposal { proposal_id } -> {
            // Need existing datum for governance operations
            expect Some(datum) = datum_opt
            
            // Validate proposal execution
            validators.validate_execute_proposal(
              datum.proposals,
              proposal_id,
              transaction,
            )
          }
          
          GovernanceAction.CancelProposal { proposal_id } -> {
            // Need existing datum for governance operations
            expect Some(datum) = datum_opt
            
            // Get canceller's public key (must be a signer)
            expect Some(canceller) = list.head(transaction.extra_signatories)
            
            // Validate proposal cancellation
            validators.validate_cancel_proposal(
              datum.proposals,
              proposal_id,
              canceller,
              transaction,
            )
          }
        }
      }
      
      _ -> {
        // This validator only handles spend purposes
        False
      }
    }
  }
}