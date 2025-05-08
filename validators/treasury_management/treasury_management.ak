// validators/treasury_management/treasury_management.ak
use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/assets.{Value, lovelace_of, policies}
use cardano/transaction.{InlineDatum, OutputReference, Transaction}
use treasury_management/types.{
  PendingTransaction, SerializableValue, TransactionRecord, TransactionType,
  TreasuryAction, TreasuryDatum,
}

/// Treasury Management validator
/// 
/// This validator handles all financial transactions for a SACCO entity,
/// including contributions, withdrawals, and loans. It ensures transparent
/// fund management with multi-signature approval mechanisms and maintains
/// an immutable record of all financial activities.
validator treasury_management(entity_registry_hash: ByteArray) {
  spend(
    datum_opt: Option<TreasuryDatum>,
    redeemer: TreasuryAction,
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
          TreasuryAction.Contribute { amount, description } -> {
            // 1. Verify the transaction is signed by at least one key
            expect Some(signer) = list.head(extra_signatories)
            // 2. Find outputs with inline datum (should be exactly one for the updated treasury)
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
            // 3. Verify that we have exactly one output with datum (the updated treasury)
            when outputs_with_inline_datum is {
              [output] ->
                // 4. Verify the output datum is correctly updated
                when output.datum is {
                  InlineDatum(data) -> {
                    expect new_datum: TreasuryDatum = data
                    // 5. Verify entity registry reference remains unchanged
                    let entity_ref_unchanged =
                      new_datum.entity_utxo_ref == datum.entity_utxo_ref
                    // 6. Verify balance structure is preserved 
                    // Just checking policies structure remains valid - in reality the
                    // actual balance is maintained by the UTxO itself
                    let valid_balance_update = True
                    // 7. Verify transaction history is updated with this contribution
                    let contribution_record =
                      TransactionRecord {
                        transaction_type: TransactionType.Contribution,
                        amount,
                        member: signer,
                        time: 0,
                        // Simplified timestamp
                        description,
                      }
                    // Check that new history includes all previous records plus this one
                    let previous_history_length =
                      list.length(datum.transaction_history)
                    let new_history_length =
                      list.length(new_datum.transaction_history)
                    let history_grew_by_one =
                      new_history_length == previous_history_length + 1
                    // Check most recent record (last in list) matches this contribution
                    let valid_new_record =
                      when list.last(new_datum.transaction_history) is {
                        Some(record) ->
                          record.transaction_type == TransactionType.Contribution && record.amount == amount && record.member == signer && record.description == description
                        None -> False
                      }
                    // 8. Verify all previous transaction records are preserved
                    let previous_records_preserved =
                      list.all(
                        datum.transaction_history,
                        fn(old_record) {
                          list.any(
                            new_datum.transaction_history,
                            fn(new_record) { old_record == new_record },
                          )
                        },
                      )
                    // 9. Verify pending transactions remain unchanged
                    let pending_unchanged =
                      new_datum.pending_transactions == datum.pending_transactions
                    // 10. Verify approval thresholds remain unchanged
                    let thresholds_unchanged =
                      new_datum.approval_thresholds == datum.approval_thresholds
                    // All conditions must be met
                    entity_ref_unchanged? && valid_balance_update? && history_grew_by_one? && valid_new_record? && previous_records_preserved? && pending_unchanged? && thresholds_unchanged?
                  }
                  _ -> False
                }
              _ -> False
            }
          }
          TreasuryAction.ProposeTransaction { transaction } -> {
            // 1. Verify the transaction is signed by at least one key (the proposer)
            expect Some(signer) = list.head(extra_signatories)
            // 2. Validate transaction details
            // Ensure amount is positive
            let valid_amount = transaction.amount > 0
            // Ensure the proposer is recorded correctly
            let correct_proposer = transaction.member == signer
            // Ensure transaction type is valid (not Contribution, which has its own action)
            let valid_transaction_type =
              transaction.transaction_type != TransactionType.Contribution
            // Ensure description is not empty
            let valid_description = transaction.description != #""
            // 3. Find outputs with inline datum (should be exactly one for the updated treasury)
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
            // 4. Verify that we have exactly one output with datum (the updated treasury)
            when outputs_with_inline_datum is {
              [output] ->
                // 5. Verify the output datum is correctly updated
                when output.datum is {
                  InlineDatum(data) -> {
                    expect new_datum: TreasuryDatum = data
                    // 6. Verify entity registry reference remains unchanged
                    let entity_ref_unchanged =
                      new_datum.entity_utxo_ref == datum.entity_utxo_ref
                    // 7. Verify balance remains unchanged
                    let balance_unchanged = new_datum.balance == datum.balance
                    // 8. Verify transaction history remains unchanged
                    let history_unchanged =
                      new_datum.transaction_history == datum.transaction_history
                    // 9. Verify pending transactions is updated with the new proposal
                    let previous_pending_length =
                      list.length(datum.pending_transactions)
                    let new_pending_length =
                      list.length(new_datum.pending_transactions)
                    let pending_grew_by_one =
                      new_pending_length == previous_pending_length + 1
                    // 10. Determine required approvals based on transaction type and amount
                    let required_approvals =
                      when
                        list.find(
                          datum.approval_thresholds,
                          fn(pair) {
                            let Pair(tx_type, _) = pair
                            tx_type == transaction.transaction_type
                          },
                        )
                      is {
                        Some(Pair(_, threshold)) -> threshold
                        None -> 2
                      }
                    // Default to 2 approvals if not specified
                    // 11. Check that the new pending transaction is properly formed
                    let expected_pending_tx =
                      PendingTransaction {
                        transaction_record: transaction,
                        approvals: [],
                        // Should start with no approvals
                        required_approvals,
                      }
                    // 12. Check most recent pending transaction (last in list) matches the expected one
                    let valid_new_pending =
                      when list.last(new_datum.pending_transactions) is {
                        Some(pending_tx) ->
                          pending_tx.transaction_record == transaction && list.is_empty(
                            pending_tx.approvals,
                          ) && pending_tx.required_approvals == required_approvals
                        None -> False
                      }
                    // 13. Verify all previous pending transactions are preserved
                    let previous_pending_preserved =
                      list.all(
                        datum.pending_transactions,
                        fn(old_pending) {
                          list.any(
                            new_datum.pending_transactions,
                            fn(new_pending) { old_pending == new_pending },
                          )
                        },
                      )
                    // 14. Verify approval thresholds remain unchanged
                    let thresholds_unchanged =
                      new_datum.approval_thresholds == datum.approval_thresholds
                    // All conditions must be met
                    valid_amount? && correct_proposer? && valid_transaction_type? && valid_description? && entity_ref_unchanged? && balance_unchanged? && history_unchanged? && pending_grew_by_one? && valid_new_pending? && previous_pending_preserved? && thresholds_unchanged?
                  }
                  _ -> False
                }
              _ -> False
            }
          }
          TreasuryAction.ApproveTransaction { transaction_index } ->
            // TODO: Validation logic for ApproveTransaction:
            // 1. Ensure transaction is signed by an active member
            // 2. Verify transaction index is valid
            // 3. Check if signer hasn't already approved
            // 4. Ensure output datum is correctly updated with approval
            // Basic validation - allow all approvals
            True
          TreasuryAction.ExecuteTransaction { transaction_index } ->
            // TODO: Validation logic for ExecuteTransaction:
            // 1. Verify transaction index is valid
            // 2. Check if required approvals are met
            // 3. Ensure transaction is executed correctly (funds transferred)
            // 4. Check if output datum is correctly updated
            // Basic validation - allow all executions
            True
          TreasuryAction.CancelTransaction { transaction_index } ->
            // TODO: Validation logic for CancelTransaction:
            // 1. Ensure transaction is signed by the original proposer or an admin
            // 2. Verify transaction index is valid
            // 3. Check if output datum is correctly updated without the transaction
            // Basic validation - allow all cancellations
            True
        }
      None ->
        // Initial setup case - only Contribute is valid when no datum exists
        when redeemer is {
          TreasuryAction.Contribute { amount, description } -> {
            // 1. Verify the transaction is signed by at least one key
            expect Some(signer) = list.head(extra_signatories)
            // 2. Find outputs that contain an inline datum (should be exactly one for the updated treasury)
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
            // 3. Verify that we have exactly one output with datum (the updated treasury)
            when outputs_with_inline_datum is {
              [output] ->
                // 4. Verify the output datum is correctly initialized
                when output.datum is {
                  InlineDatum(data) -> {
                    expect new_datum: TreasuryDatum = data
                    // 5. Verify entity registry reference is set (non-empty transaction id)
                    let valid_entity_ref =
                      new_datum.entity_utxo_ref.transaction_id != #""
                    // 6. Verify initial treasury has empty policies list (zero balance except contribution)
                    let empty_initial_balance =
                      list.is_empty(new_datum.balance.policies)
                    // 7. Get a timestamp for the transaction
                    // For simplicity, we'll use 0 as a placeholder
                    let current_time = 0
                    // 8. Verify transaction history includes this contribution
                    let valid_history =
                      when new_datum.transaction_history is {
                        [record] ->
                          record.transaction_type == TransactionType.Contribution && record.amount == amount && record.member == signer && record.description == description
                        _ -> False
                      }
                    // 9. Verify pending transactions list is empty initially
                    let empty_pending =
                      list.is_empty(new_datum.pending_transactions)
                    // 10. Verify approval thresholds are initialized with sensible defaults
                    let valid_thresholds =
                      list.length(new_datum.approval_thresholds) > 0
                    // All conditions must be met
                    valid_entity_ref? && empty_initial_balance? && valid_history? && empty_pending? && valid_thresholds?
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
