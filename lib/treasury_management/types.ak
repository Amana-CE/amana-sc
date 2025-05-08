// lib/treasury_management/types.ak
use aiken/crypto.{VerificationKeyHash}
use cardano/transaction.{OutputReference}

/// Types for the Treasury Management contract
/// These types represent the core data structures used for financial operations
/// in a SACCO entity
/// Serializable representation of Value for on-chain storage
/// Instead of using the opaque Value type directly, we use a serializable
/// representation that can be converted to/from Value when needed
pub type SerializableValue {
  // Structure to store assets as a list of policy_id -> [(asset_name, quantity)]
  policies: List<Pair<ByteArray, List<Pair<ByteArray, Int>>>>,
}

/// Transaction types
pub type TransactionType {
  Contribution
  Withdrawal
  Loan
  LoanRepayment
  AdminFee
}

/// Transaction record
pub type TransactionRecord {
  transaction_type: TransactionType,
  amount: Int,
  member: VerificationKeyHash,
  time: Int,
  description: ByteArray,
}

/// Pending transaction
pub type PendingTransaction {
  transaction_record: TransactionRecord,
  approvals: List<VerificationKeyHash>,
  required_approvals: Int,
}

/// Treasury datum - stored on-chain
pub type TreasuryDatum {
  entity_utxo_ref: OutputReference,
  // Use SerializableValue instead of the opaque Value
  balance: SerializableValue,
  transaction_history: List<TransactionRecord>,
  pending_transactions: List<PendingTransaction>,
  // Thresholds for different transaction types
  approval_thresholds: List<Pair<TransactionType, Int>>,
}

/// Redeemer actions
pub type TreasuryAction {
  // Add funds to treasury
  Contribute { amount: Int, description: ByteArray }
  // Create transaction that requires approval
  ProposeTransaction { transaction: TransactionRecord }
  // Approve a pending transaction
  ApproveTransaction { transaction_index: Int }
  // Execute an approved transaction
  ExecuteTransaction { transaction_index: Int }
  // Cancel a pending transaction
  CancelTransaction { transaction_index: Int }
}
