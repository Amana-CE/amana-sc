use cardano/assets.{from_lovelace}
use mocktail.{
  complete, mock_script_address, mocktail_tx, required_signer_hash, tx_out,
  tx_out_inline_datum,
}
use mocktail/virgin_key_hash.{mock_pub_key_hash}
use mocktail/virgin_output_reference.{mock_utxo_ref}
use treasury_management/treasury_management
use treasury_management/types.{
  PendingTransaction, TransactionType, TreasuryAction, TreasuryDatum,
}

test initial_contribution_success() {
  let signer = mock_pub_key_hash(0)
  let new_datum =
    TreasuryDatum {
      entity_utxo_ref: mock_utxo_ref(1, 0),
      pending_transactions: [],
      approval_thresholds: [
        Pair(TransactionType.Withdrawal, 2),
        Pair(TransactionType.Loan, 2),
      ],
    }

  let tx =
    mocktail_tx()
      |> required_signer_hash(True, signer)
      |> tx_out(True, mock_script_address(0, None), from_lovelace(10_000_000))
      |> tx_out_inline_datum(True, new_datum)
      |> complete()

  treasury_management.treasury_management.spend(
    #"",
    None,
    TreasuryAction.Contribute,
    mock_utxo_ref(0, 0),
    tx,
  ) == True
}

test propose_transaction_success() {
  let proposer = mock_pub_key_hash(0)
  let recipient = mock_pub_key_hash(1)
  let datum =
    TreasuryDatum {
      entity_utxo_ref: mock_utxo_ref(0, 0),
      pending_transactions: [],
      approval_thresholds: [Pair(TransactionType.Withdrawal, 2)],
    }

  let expected_pending =
    PendingTransaction {
      id: 0,
      transaction_type: TransactionType.Withdrawal,
      amount: 2_000_000,
      recipient,
      proposer,
      approvals: [],
      required_approvals: 2,
    }

  let new_datum =
    TreasuryDatum {
      entity_utxo_ref: datum.entity_utxo_ref,
      pending_transactions: [expected_pending],
      approval_thresholds: datum.approval_thresholds,
    }

  let tx =
    mocktail_tx()
      |> required_signer_hash(True, proposer)
      |> tx_out(True, mock_script_address(0, None), from_lovelace(5_000_000))
      |> tx_out_inline_datum(True, new_datum)
      |> complete()

  treasury_management.treasury_management.spend(
    #"",
    Some(datum),
    TreasuryAction.ProposeTransaction {
      transaction_type: TransactionType.Withdrawal,
      amount: 2_000_000,
      recipient,
    },
    mock_utxo_ref(0, 0),
    tx,
  ) == True
}

test approve_transaction_success() {
  let proposer = mock_pub_key_hash(0)
  let approver = mock_pub_key_hash(1)
  let recipient = mock_pub_key_hash(2)

  let pending_tx =
    PendingTransaction {
      id: 0,
      transaction_type: TransactionType.Withdrawal,
      amount: 2_000_000,
      recipient,
      proposer,
      approvals: [],
      required_approvals: 2,
    }

  let datum =
    TreasuryDatum {
      entity_utxo_ref: mock_utxo_ref(0, 0),
      pending_transactions: [pending_tx],
      approval_thresholds: [Pair(TransactionType.Withdrawal, 2)],
    }

  let updated_pending =
    PendingTransaction {
      id: 0,
      transaction_type: TransactionType.Withdrawal,
      amount: 2_000_000,
      recipient,
      proposer,
      approvals: [approver],
      required_approvals: 2,
    }

  let new_datum =
    TreasuryDatum {
      entity_utxo_ref: datum.entity_utxo_ref,
      pending_transactions: [updated_pending],
      approval_thresholds: datum.approval_thresholds,
    }

  let tx =
    mocktail_tx()
      |> required_signer_hash(True, approver)
      |> tx_out(True, mock_script_address(0, None), from_lovelace(5_000_000))
      |> tx_out_inline_datum(True, new_datum)
      |> complete()

  treasury_management.treasury_management.spend(
    #"",
    Some(datum),
    TreasuryAction.ApproveTransaction { transaction_id: 0 },
    mock_utxo_ref(0, 0),
    tx,
  ) == True
}

test prevent_double_approval() {
  let approver = mock_pub_key_hash(1)
  let recipient = mock_pub_key_hash(2)

  let pending_tx =
    PendingTransaction {
      id: 0,
      transaction_type: TransactionType.Withdrawal,
      amount: 2_000_000,
      recipient,
      proposer: mock_pub_key_hash(0),
      approvals: [approver],
      required_approvals: 2,
    }

  let datum =
    TreasuryDatum {
      entity_utxo_ref: mock_utxo_ref(0, 0),
      pending_transactions: [pending_tx],
      approval_thresholds: [Pair(TransactionType.Withdrawal, 2)],
    }

  let tx =
    mocktail_tx()
      |> required_signer_hash(True, approver)
      |> tx_out(True, mock_script_address(0, None), from_lovelace(5_000_000))
      |> tx_out_inline_datum(True, datum)
      |> complete()

  treasury_management.treasury_management.spend(
    #"",
    Some(datum),
    TreasuryAction.ApproveTransaction { transaction_id: 0 },
    mock_utxo_ref(0, 0),
    tx,
  ) == False
}
