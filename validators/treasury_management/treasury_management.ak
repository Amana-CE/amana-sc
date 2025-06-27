// treasury_management/treasury_management.ak
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/assets.{lovelace_of}
use cardano/script_context.{ScriptContext}
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}
use treasury_management/types.{
  PendingTransaction, TransactionType, TreasuryAction, TreasuryDatum,
}

validator treasury_management(entity_registry_hash: ByteArray) {
  spend(
    datum_opt: Option<TreasuryDatum>,
    redeemer: TreasuryAction,
    _own_ref: OutputReference,
    ctx: ScriptContext,
  ) {
    let ScriptContext { transaction, .. } = ctx
    let Transaction { inputs, outputs, extra_signatories, .. } = transaction

    when datum_opt is {
      Some(datum) ->
        when redeemer is {
          TreasuryAction.Contribute -> {
            // Allow anyone to contribute funds
            expect Some(treasury_output) = find_treasury_output(outputs)
            // Treasury value must increase (someone sent funds)
            lovelace_of(treasury_output.value) > get_own_input_value(inputs)
          }

          TreasuryAction.ProposeTransaction {
            transaction_type,
            amount,
            recipient,
          } -> {
            expect Some(signer) = list.head(extra_signatories)
            expect Some(treasury_output) = find_treasury_output(outputs)
            // Basic validations
            amount > 0 && // Update datum with new pending transaction
            when treasury_output.datum is {
              InlineDatum(data) -> {
                expect new_datum: TreasuryDatum = data
                let new_pending =
                  PendingTransaction {
                    id: get_next_id(datum.pending_transactions),
                    transaction_type,
                    amount,
                    recipient,
                    proposer: signer,
                    approvals: [],
                    required_approvals: get_threshold(
                      datum.approval_thresholds,
                      transaction_type,
                    ),
                  }
                new_datum.entity_utxo_ref == datum.entity_utxo_ref && new_datum.approval_thresholds == datum.approval_thresholds && new_datum.pending_transactions == [
                  new_pending,
                  ..datum.pending_transactions
                ]
              }
              _ -> False
            }
          }

          TreasuryAction.ApproveTransaction { transaction_id } -> {
            expect Some(signer) = list.head(extra_signatories)
            expect Some(treasury_output) = find_treasury_output(outputs)
            expect Some(pending_tx) =
              find_pending_transaction(
                datum.pending_transactions,
                transaction_id,
              )
            // Prevent double approval
            !list.has(pending_tx.approvals, signer) && when
              treasury_output.datum
            is {
              InlineDatum(data) -> {
                expect new_datum: TreasuryDatum = data
                let updated_pending =
                  PendingTransaction {
                    ..pending_tx,
                    approvals: [signer, ..pending_tx.approvals],
                  }
                new_datum.entity_utxo_ref == datum.entity_utxo_ref && new_datum.approval_thresholds == datum.approval_thresholds && new_datum.pending_transactions == list.map(
                  datum.pending_transactions,
                  fn(tx) {
                    if tx.id == transaction_id {
                      updated_pending
                    } else {
                      tx
                    }
                  },
                )
              }
              _ -> False
            }
          }

          TreasuryAction.ExecuteTransaction { transaction_id } -> {
            expect Some(treasury_output) = find_treasury_output(outputs)
            expect Some(pending_tx) =
              find_pending_transaction(
                datum.pending_transactions,
                transaction_id,
              )
            // Check sufficient approvals
            list.length(pending_tx.approvals) >= pending_tx.required_approvals && // Verify funds are sent (simplified for MVP)
            list.any(
              outputs,
              fn(output) { lovelace_of(output.value) >= pending_tx.amount },
            ) && // Verify treasury balance decreases by exact amount
            lovelace_of(treasury_output.value) == get_own_input_value(inputs) - pending_tx.amount && when
              treasury_output.datum
            is {
              InlineDatum(data) -> {
                expect new_datum: TreasuryDatum = data
                // Remove executed transaction from pending
                new_datum.entity_utxo_ref == datum.entity_utxo_ref && new_datum.approval_thresholds == datum.approval_thresholds && new_datum.pending_transactions == list.filter(
                  datum.pending_transactions,
                  fn(tx) { tx.id != transaction_id },
                )
              }
              _ -> False
            }
          }
        }
      None ->
        // Initial treasury setup - only allow contribution
        when redeemer is {
          TreasuryAction.Contribute -> {
            expect Some(treasury_output) = find_treasury_output(outputs)
            when treasury_output.datum is {
              InlineDatum(data) -> {
                expect new_datum: TreasuryDatum = data
                // Initialize with basic approval thresholds
                new_datum.entity_utxo_ref.transaction_id != #"" && new_datum.pending_transactions == [] && new_datum.approval_thresholds == [
                  Pair(TransactionType.Withdrawal, 2),
                  Pair(TransactionType.Loan, 2),
                ]
              }
              _ -> False
            }
          }
          _ -> False
        }
    }
  }

  else(_) {
    False
  }
}

// FIXED: Use concrete Output type instead of generic 'o'
fn find_treasury_output(outputs: List<Output>) -> Option<Output> {
  list.find(
    outputs,
    fn(output) {
      when output.datum is {
        InlineDatum(data) ->
          if data is TreasuryDatum {
            True
          } else {
            False
          }
        _ -> False
      }
    },
  )
}

fn get_own_input_value(inputs: List<Input>) -> Int {
  expect Some(own_input) =
    list.find(
      inputs,
      fn(input) {
        when input.output.datum is {
          InlineDatum(data) ->
            if data is TreasuryDatum {
              True
            } else {
              False
            }
          _ -> False
        }
      },
    )
  lovelace_of(own_input.output.value)
}

fn find_pending_transaction(
  pending_transactions: List<PendingTransaction>,
  transaction_id: Int,
) -> Option<PendingTransaction> {
  list.find(pending_transactions, fn(tx) { tx.id == transaction_id })
}

fn get_next_id(pending_transactions: List<PendingTransaction>) -> Int {
  list.foldl(
    pending_transactions,
    0,
    fn(tx, acc) {
      if tx.id >= acc {
        tx.id + 1
      } else {
        acc
      }
    },
  )
}

fn get_threshold(
  thresholds: List<Pair<TransactionType, Int>>,
  tx_type: TransactionType,
) -> Int {
  when
    list.find(
      thresholds,
      fn(pair) {
        let Pair(threshold_type, _) = pair
        threshold_type == tx_type
      },
    )
  is {
    Some(Pair(_, threshold)) -> threshold
    None -> 2
  }
  // Default threshold
}
