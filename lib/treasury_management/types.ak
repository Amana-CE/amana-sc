// treasury_management/types.ak
use aiken/crypto.{VerificationKeyHash}
use cardano/transaction.{OutputReference}

pub type TreasuryDatum {
  entity_utxo_ref: OutputReference,
  pending_transactions: List<PendingTransaction>,
  approval_thresholds: List<Pair<TransactionType, Int>>,
}

pub type PendingTransaction {
  id: Int,
  transaction_type: TransactionType,
  amount: Int,
  recipient: VerificationKeyHash,
  proposer: VerificationKeyHash,
  approvals: List<VerificationKeyHash>,
  required_approvals: Int,
}

pub type TransactionType {
  Withdrawal
  Loan
}

pub type TreasuryAction {
  Contribute
  ProposeTransaction {
    transaction_type: TransactionType,
    amount: Int,
    recipient: VerificationKeyHash,
  }
  ApproveTransaction { transaction_id: Int }
  ExecuteTransaction { transaction_id: Int }
}
