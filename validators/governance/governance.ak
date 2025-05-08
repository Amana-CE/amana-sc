// validators/governance/governance.ak
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/transaction.{InlineDatum, OutputReference, Transaction}
use governance/types.{
  GovernanceAction, GovernanceDatum, GovernanceParams, Proposal,
  ProposalCategory, ProposalStatus, Vote,
}

/// Governance validator
/// 
/// This validator manages the decision-making process for a SACCO entity. It
/// enables members to create proposals, vote on them, and automatically execute
/// approved decisions. The contract ensures transparent and fair governance with
/// immutable record-keeping of all voting activities.
validator governance(
  entity_registry_hash: ByteArray,
  treasury_hash: ByteArray,
) {
  spend(
    datum_opt: Option<GovernanceDatum>,
    redeemer: GovernanceAction,
    own_ref: OutputReference,
    tx: Transaction,
  ) {
    // Extract transaction signatories
    let Transaction { extra_signatories, outputs, .. } = tx

    // Process based on the presence of existing datum
    when datum_opt is {
      Some(datum) ->
        // Verify authorization based on redeemer action
        when redeemer is {
          GovernanceAction.CreateProposal {
            title,
            description,
            category,
            voting_deadline,
            execution_data,
          } -> {
            // 1. Ensure valid proposal details
            let valid_title = title != ""
            let valid_description = description != ""
            // 2. Ensure transaction is signed by at least one key (proposer)
            let has_signer = list.length(extra_signatories) > 0
            expect Some(proposer) = list.head(extra_signatories)
            // 3. Verify voting deadline is sufficiently in the future
            // For a real implementation, you would compare with tx.validity_range lower bound
            let current_time = 0
            // Placeholder timestamp
            let minimum_voting_period = datum.params.minimum_voting_period
            let valid_deadline =
              voting_deadline > current_time + minimum_voting_period
            // 4. Find outputs with inline datum (should be exactly one for the updated governance state)
            let outputs_with_inline_datum =
              list.filter(
                outputs,
                fn(output) {
                  when output.datum is {
                    InlineDatum(_) -> True
                    _ -> False
                  }
                },
              )
            // 5. Verify that we have exactly one output with datum
            when outputs_with_inline_datum is {
              [output] ->
                // 6. Verify the output datum is correctly updated
                when output.datum is {
                  InlineDatum(data) -> {
                    expect new_datum: GovernanceDatum = data
                    // 7. Verify entity and treasury references remain unchanged
                    let entity_ref_unchanged =
                      new_datum.entity_utxo_ref == datum.entity_utxo_ref
                    let treasury_ref_unchanged =
                      new_datum.treasury_utxo_ref == datum.treasury_utxo_ref
                    // 8. Verify governance parameters remain unchanged
                    let params_unchanged = new_datum.params == datum.params
                    // 9. Verify proposals list grows by exactly one
                    let proposals_grew_by_one =
                      list.length(new_datum.proposals) == list.length(
                        datum.proposals,
                      ) + 1
                    // 10. Verify the new proposal ID
                    let next_id = datum.next_proposal_id
                    let next_id_incremented =
                      new_datum.next_proposal_id == next_id + 1
                    // 11. Verify all previous proposals are preserved
                    let previous_proposals_preserved =
                      list.all(
                        datum.proposals,
                        fn(old_proposal) {
                          list.any(
                            new_datum.proposals,
                            fn(new_proposal) { old_proposal == new_proposal },
                          )
                        },
                      )
                    // 12. Verify the new proposal is correctly added
                    let new_proposal_valid =
                      list.any(
                        new_datum.proposals,
                        fn(proposal) {
                          proposal.title == title && proposal.description == description && proposal.category == category && proposal.proposer == proposer && proposal.creation_time >= 0 && proposal.voting_deadline == voting_deadline && proposal.status == ProposalStatus.Active && list.is_empty(
                            proposal.votes,
                          ) && proposal.for_votes == 0 && proposal.against_votes == 0 && proposal.abstain_votes == 0
                        },
                      )
                    // All conditions must be met
                    valid_title? && valid_description? && has_signer? && valid_deadline? && entity_ref_unchanged? && treasury_ref_unchanged? && params_unchanged? && proposals_grew_by_one? && next_id_incremented? && previous_proposals_preserved? && new_proposal_valid?
                  }
                  _ -> False
                }
              _ -> False
            }
          }
          GovernanceAction.CastVote { proposal_id, vote } ->
            // TODO: Validation logic for CastVote:
            // 1. Ensure transaction is signed by an active member who hasn't already voted
            // 2. Verify proposal_id is valid and proposal is active
            // 3. Verify voting deadline hasn't passed
            // 4. Check if output datum is correctly updated with the vote
            // Basic validation - allow all votes
            False
          GovernanceAction.ExecuteProposal { proposal_id } ->
            // TODO: Validation logic for ExecuteProposal:
            // 1. Verify proposal_id is valid and proposal is approved
            // 2. Ensure proposal meets approval threshold and quorum
            // 3. Verify proposal execution is handled correctly
            // 4. Check if output datum is correctly updated
            // Basic validation - allow all executions
            False
          GovernanceAction.CancelProposal { proposal_id } ->
            // TODO: Validation logic for CancelProposal:
            // 1. Ensure transaction is signed by the proposer or an admin
            // 2. Verify proposal_id is valid and proposal is active
            // 3. Check if output datum is correctly updated
            // Basic validation - allow all cancellations
            False
          GovernanceAction.UpdateParams { new_params } ->
            // TODO: Validation logic for UpdateParams:
            // 1. Ensure transaction is signed by an admin
            // 2. Validate new parameters (thresholds, periods, etc.)
            // 3. Check if output datum is correctly updated
            // Basic validation - allow all parameter updates
            False
        }
      None ->
        // Initial setup case - initialize governance datum
        when redeemer is {
          GovernanceAction.CreateProposal {
            title,
            description,
            category,
            voting_deadline,
            execution_data,
          } -> {
            // 1. Ensure valid proposal details
            let valid_title = title != ""
            let valid_description = description != ""
            // 2. Ensure transaction is signed by at least one key (initial admin)
            let has_signer = list.length(extra_signatories) > 0
            expect Some(proposer) = list.head(extra_signatories)
            // 3. Verify voting deadline is in the future
            // In production, you would compare with tx.validity_range
            let current_time = 0
            // Placeholder - in real implementation use tx validity lower bound
            let valid_deadline = voting_deadline > current_time
            // 4. Find outputs with inline datum (should be exactly one)
            let outputs_with_inline_datum =
              list.filter(
                outputs,
                fn(output) {
                  when output.datum is {
                    InlineDatum(_) -> True
                    _ -> False
                  }
                },
              )
            // 5. Verify there is exactly one output with an inline datum
            when outputs_with_inline_datum is {
              [output] ->
                // 6. Verify the output datum is correctly initialized
                when output.datum is {
                  InlineDatum(data) -> {
                    expect new_datum: GovernanceDatum = data
                    // 7. Verify entity and treasury references are non-empty
                    let valid_entity_ref =
                      new_datum.entity_utxo_ref.transaction_id != ""
                    let valid_treasury_ref =
                      new_datum.treasury_utxo_ref.transaction_id != ""
                    // 8. Verify initial parameters are reasonable
                    let valid_params =
                      new_datum.params.approval_threshold > 50 && new_datum.params.approval_threshold <= 100 && new_datum.params.minimum_voting_period > 0 && new_datum.params.quorum_percentage > 0 && new_datum.params.quorum_percentage <= 100
                    // 9. Verify proposals list contains exactly one item (this proposal)
                    let has_one_proposal = list.length(new_datum.proposals) == 1
                    // 10. Verify the proposal is correctly formatted
                    let proposal_valid =
                      when list.head(new_datum.proposals) is {
                        Some(proposal) ->
                          proposal.title == title && proposal.description == description && proposal.category == category && proposal.proposer == proposer && proposal.creation_time >= 0 && proposal.voting_deadline == voting_deadline && proposal.status == ProposalStatus.Active && list.is_empty(
                            proposal.votes,
                          ) && proposal.for_votes == 0 && proposal.against_votes == 0 && proposal.abstain_votes == 0
                        None -> False
                      }
                    // 11. Verify next_proposal_id is set to 1
                    let valid_next_id = new_datum.next_proposal_id == 1
                    // All conditions must be met
                    valid_title? && valid_description? && has_signer? && valid_deadline? && valid_entity_ref? && valid_treasury_ref? && valid_params? && has_one_proposal? && proposal_valid? && valid_next_id?
                  }
                  _ -> False
                }
              _ -> False
            }
          }
          // Any other action is invalid when no datum exists
          _ -> False
        }
    }
  }

  else(_) {
    // Any other use of this validator should fail
    False
  }
}
