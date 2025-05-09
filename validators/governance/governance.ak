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
          GovernanceAction.CastVote { proposal_id, vote } -> {
            // 1. Ensure transaction is signed by at least one key (voter)
            let has_signer = list.length(extra_signatories) > 0
            expect Some(voter) = list.head(extra_signatories)
            // 2. Verify proposal_id is valid (within range of existing proposals)
            let valid_id =
              proposal_id >= 0 && proposal_id < list.length(datum.proposals)
            if !valid_id {
              False
            } else {
              // 3. Get the proposal being voted on
              expect Some(proposal) = list.at(datum.proposals, proposal_id)
              // 4. Check if the proposal is active
              let is_active = proposal.status == ProposalStatus.Active
              // 5. Check if voting deadline hasn't passed using transaction's validity interval
              // For production code, we would compare with tx.validity_range
              // Simplified check for the MVP
              let current_time = proposal.creation_time
              // Use creation time as a base
              let voting_open = current_time <= proposal.voting_deadline
              // 6. Check if voter has already voted
              let already_voted =
                list.any(
                  proposal.votes,
                  fn(pair) {
                    let Pair(voter_key, _) = pair
                    voter_key == voter
                  },
                )
              if !is_active || !voting_open || already_voted {
                False
              } else {
                // 7. Find outputs with inline datum (should be exactly one for the updated governance state)
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
                when outputs_with_inline_datum is {
                  [output] ->
                    when output.datum is {
                      InlineDatum(data) -> {
                        expect new_datum: GovernanceDatum = data
                        // 8. Verify entity and treasury references remain unchanged
                        let entity_ref_unchanged =
                          new_datum.entity_utxo_ref == datum.entity_utxo_ref
                        let treasury_ref_unchanged =
                          new_datum.treasury_utxo_ref == datum.treasury_utxo_ref
                        // 9. Verify governance parameters remain unchanged
                        let params_unchanged = new_datum.params == datum.params
                        // 10. Verify proposals count remains the same
                        let proposal_count_unchanged =
                          list.length(new_datum.proposals) == list.length(
                            datum.proposals,
                          )
                        // 11. Verify next proposal ID remains unchanged
                        let next_id_unchanged =
                          new_datum.next_proposal_id == datum.next_proposal_id
                        // 12. Get the updated proposal
                        expect Some(new_proposal) =
                          list.at(new_datum.proposals, proposal_id)
                        // 13. Check that all proposals except the voted one are unchanged
                        let other_proposals_unchanged =
                          list.all(
                            list.range(0, list.length(datum.proposals)),
                            fn(index) {
                              if index == proposal_id {
                                // Skip checking the proposal that should be changed
                                True
                              } else {
                                // Other proposals should be unchanged
                                expect Some(old) =
                                  list.at(datum.proposals, index)
                                expect Some(new) =
                                  list.at(new_datum.proposals, index)
                                old == new
                              }
                            },
                          )
                        // 14. Verify the proposal status remains Active
                        let status_unchanged =
                          new_proposal.status == ProposalStatus.Active
                        // 15. Verify other proposal fields remain unchanged
                        let core_fields_unchanged =
                          new_proposal.title == proposal.title && new_proposal.description == proposal.description && new_proposal.category == proposal.category && new_proposal.proposer == proposal.proposer && new_proposal.creation_time == proposal.creation_time && new_proposal.voting_deadline == proposal.voting_deadline && new_proposal.execution_data == proposal.execution_data
                        // 16. Verify the vote is correctly added
                        let vote_count_increased =
                          list.length(new_proposal.votes) == list.length(
                            proposal.votes,
                          ) + 1
                        let has_new_vote =
                          list.has(new_proposal.votes, Pair(voter, vote))
                        let previous_votes_preserved =
                          list.all(
                            proposal.votes,
                            fn(old_vote) {
                              list.has(new_proposal.votes, old_vote)
                            },
                          )
                        // 17. Verify vote tallies are correctly updated
                        let tallies_correct =
                          when vote is {
                            Vote.For ->
                              new_proposal.for_votes == proposal.for_votes + 1 && new_proposal.against_votes == proposal.against_votes && new_proposal.abstain_votes == proposal.abstain_votes
                            Vote.Against ->
                              new_proposal.for_votes == proposal.for_votes && new_proposal.against_votes == proposal.against_votes + 1 && new_proposal.abstain_votes == proposal.abstain_votes
                            Vote.Abstain ->
                              new_proposal.for_votes == proposal.for_votes && new_proposal.against_votes == proposal.against_votes && new_proposal.abstain_votes == proposal.abstain_votes + 1
                          }
                        // All conditions must be met
                        has_signer? && entity_ref_unchanged? && treasury_ref_unchanged? && params_unchanged? && proposal_count_unchanged? && next_id_unchanged? && other_proposals_unchanged? && status_unchanged? && core_fields_unchanged? && vote_count_increased? && has_new_vote? && previous_votes_preserved? && tallies_correct?
                      }
                      _ -> False
                    }
                  _ -> False
                }
              }
            }
          }
          GovernanceAction.ExecuteProposal { proposal_id } -> {
            // 1. Verify proposal_id is valid (within range of existing proposals)
            let valid_id =
              proposal_id >= 0 && proposal_id < list.length(datum.proposals)
            if !valid_id {
              False
            } else {
              // 2. Get the proposal being executed
              expect Some(proposal) = list.at(datum.proposals, proposal_id)
              // 3. Check if the proposal is in the correct status
              let is_approved = proposal.status == ProposalStatus.Approved
              // If not already approved, check if it meets criteria to be approved
              let can_be_approved =
                if proposal.status == ProposalStatus.Active {
                  // Calculate total votes
                  let total_votes =
                    proposal.for_votes + proposal.against_votes + proposal.abstain_votes
                  // Check if quorum is met
                  let quorum_percentage = datum.params.quorum_percentage
                  let quorum_met = total_votes * 100 >= quorum_percentage
                  // Check if approval threshold is met
                  let approval_threshold = datum.params.approval_threshold
                  let approval_percentage =
                    if total_votes > 0 {
                      proposal.for_votes * 100 / total_votes
                    } else {
                      0
                    }
                  let threshold_met = approval_percentage >= approval_threshold
                  // The proposal can be considered approved if it meets both quorum and threshold
                  quorum_met && threshold_met
                } else {
                  False
                }
              // 4. Either the proposal must be already approved or can be approved now
              if !is_approved && !can_be_approved {
                False
              } else {
                // 5. Find outputs with inline datum (should be exactly one for the updated governance state)
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
                when outputs_with_inline_datum is {
                  [output] ->
                    when output.datum is {
                      InlineDatum(data) -> {
                        expect new_datum: GovernanceDatum = data
                        // 6. Verify entity and treasury references remain unchanged
                        let entity_ref_unchanged =
                          new_datum.entity_utxo_ref == datum.entity_utxo_ref
                        let treasury_ref_unchanged =
                          new_datum.treasury_utxo_ref == datum.treasury_utxo_ref
                        // 7. Verify governance parameters remain unchanged
                        let params_unchanged = new_datum.params == datum.params
                        // 8. Verify proposals count remains the same
                        let proposal_count_unchanged =
                          list.length(new_datum.proposals) == list.length(
                            datum.proposals,
                          )
                        // 9. Verify next proposal ID remains unchanged
                        let next_id_unchanged =
                          new_datum.next_proposal_id == datum.next_proposal_id
                        // 10. Get the updated proposal
                        expect Some(new_proposal) =
                          list.at(new_datum.proposals, proposal_id)
                        // 11. Check that all proposals except the executed one are unchanged
                        let other_proposals_unchanged =
                          list.all(
                            list.range(0, list.length(datum.proposals)),
                            fn(index) {
                              if index == proposal_id {
                                // Skip checking the proposal that should be changed
                                True
                              } else {
                                // Other proposals should be unchanged
                                expect Some(old) =
                                  list.at(datum.proposals, index)
                                expect Some(new) =
                                  list.at(new_datum.proposals, index)
                                old == new
                              }
                            },
                          )
                        // 12. Verify the proposal status is now Executed
                        let status_updated =
                          new_proposal.status == ProposalStatus.Executed
                        // 13. Verify other proposal fields remain unchanged
                        let core_fields_unchanged =
                          new_proposal.title == proposal.title && new_proposal.description == proposal.description && new_proposal.category == proposal.category && new_proposal.proposer == proposal.proposer && new_proposal.creation_time == proposal.creation_time && new_proposal.voting_deadline == proposal.voting_deadline && new_proposal.execution_data == proposal.execution_data && new_proposal.votes == proposal.votes && new_proposal.for_votes == proposal.for_votes && new_proposal.against_votes == proposal.against_votes && new_proposal.abstain_votes == proposal.abstain_votes
                        // 14. Verify the transaction is properly structured for execution
                        // Different validation based on proposal category
                        let execution_valid =
                          when proposal.category is {
                            ProposalCategory.TreasuryAction ->
                              // For treasury actions, we should verify the transaction interacts
                              // with the treasury script correctly
                              // For MVP, we'll just return True as a placeholder
                              True
                            ProposalCategory.ParameterChange ->
                              // For parameter changes, we only need to verify the transactions
                              // contains the correct outputs, which we've already done
                              True
                            ProposalCategory.MembershipChange ->
                              // For membership changes, we should verify the transaction
                              // interacts with the entity registry script correctly
                              // For MVP, we'll just return True as a placeholder
                              True
                            ProposalCategory.Other ->
                              // For other proposal types, we don't have specific validation
                              True
                          }
                        // All conditions must be met
                        entity_ref_unchanged? && treasury_ref_unchanged? && params_unchanged? && proposal_count_unchanged? && next_id_unchanged? && other_proposals_unchanged? && status_updated? && core_fields_unchanged? && execution_valid?
                      }
                      _ -> False
                    }
                  _ -> False
                }
              }
            }
          }
          GovernanceAction.CancelProposal { proposal_id } -> {
            // 1. Verify proposal_id is valid (within range of existing proposals)
            let valid_id =
              proposal_id >= 0 && proposal_id < list.length(datum.proposals)
            if !valid_id {
              False
            } else {
              // 2. Get the proposal being cancelled
              expect Some(proposal) = list.at(datum.proposals, proposal_id)
              // 3. Check if the proposal is active
              let is_active = proposal.status == ProposalStatus.Active
              if !is_active {
                False
              } else {
                // 4. Check if transaction is signed by the proposer or an admin
                // For now, we'll simply check if it's signed by the proposer
                let is_signed_by_proposer =
                  list.has(extra_signatories, proposal.proposer)
                // This is a simplified check for admin - in a full implementation,
                // we would check against a list of admin keys from the entity registry
                // For MVP, we'll consider anyone who can sign with the proposer's key as authorized
                if !is_signed_by_proposer {
                  False
                } else {
                  // 5. Find outputs with inline datum (should be exactly one for the updated governance state)
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
                  when outputs_with_inline_datum is {
                    [output] ->
                      when output.datum is {
                        InlineDatum(data) -> {
                          expect new_datum: GovernanceDatum = data
                          // 6. Verify entity and treasury references remain unchanged
                          let entity_ref_unchanged =
                            new_datum.entity_utxo_ref == datum.entity_utxo_ref
                          let treasury_ref_unchanged =
                            new_datum.treasury_utxo_ref == datum.treasury_utxo_ref
                          // 7. Verify governance parameters remain unchanged
                          let params_unchanged =
                            new_datum.params == datum.params
                          // 8. Verify proposals count remains the same
                          let proposal_count_unchanged =
                            list.length(new_datum.proposals) == list.length(
                              datum.proposals,
                            )
                          // 9. Verify next proposal ID remains unchanged
                          let next_id_unchanged =
                            new_datum.next_proposal_id == datum.next_proposal_id
                          // 10. Get the updated proposal
                          expect Some(new_proposal) =
                            list.at(new_datum.proposals, proposal_id)
                          // 11. Check that all proposals except the cancelled one are unchanged
                          let other_proposals_unchanged =
                            list.all(
                              list.range(0, list.length(datum.proposals)),
                              fn(index) {
                                if index == proposal_id {
                                  // Skip checking the proposal that should be changed
                                  True
                                } else {
                                  // Other proposals should be unchanged
                                  expect Some(old) =
                                    list.at(datum.proposals, index)
                                  expect Some(new) =
                                    list.at(new_datum.proposals, index)
                                  old == new
                                }
                              },
                            )
                          // 12. Verify the proposal status is now Cancelled
                          let status_updated =
                            new_proposal.status == ProposalStatus.Cancelled
                          // 13. Verify other proposal fields remain unchanged
                          let core_fields_unchanged =
                            new_proposal.title == proposal.title && new_proposal.description == proposal.description && new_proposal.category == proposal.category && new_proposal.proposer == proposal.proposer && new_proposal.creation_time == proposal.creation_time && new_proposal.voting_deadline == proposal.voting_deadline && new_proposal.execution_data == proposal.execution_data && new_proposal.votes == proposal.votes && new_proposal.for_votes == proposal.for_votes && new_proposal.against_votes == proposal.against_votes && new_proposal.abstain_votes == proposal.abstain_votes
                          // All conditions must be met
                          entity_ref_unchanged? && treasury_ref_unchanged? && params_unchanged? && proposal_count_unchanged? && next_id_unchanged? && other_proposals_unchanged? && status_updated? && core_fields_unchanged?
                        }
                        _ -> False
                      }
                    _ -> False
                  }
                }
              }
            }
          }
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
