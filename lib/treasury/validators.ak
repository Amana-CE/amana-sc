///
/// Treasury validation logic
///

use aiken/list
use aiken/transaction
use aiken/transaction/value

use common/constants
use common/types.{TransactionStatus, TransactionType, TxApproved, TxPending, TxWithdrawal}
use common/utils
use treasury/types.{Transaction, TreasuryAction, TreasuryDatum, TreasuryInfo}

/// Validate treasury initialization
pub fn validate_initialize_treasury(
  entity_id: ByteArray,
  required_signatures: Int,
  admins: List<ByteArray>,
  tx: transaction.Transaction,
) -> Bool {
  // Must have at least one admin
  list.length(admins) > 0 &&
    // Required signatures must be less than or equal to number of admins
    required_signatures <= list.length(admins) &&
    required_signatures > 0 &&
    // Transaction must be signed by at least one admin
    utils.is_signed_by_any(tx, admins)
}

/// Validate deposit transaction
pub fn validate_deposit(
  treasury_info: TreasuryInfo,
  amount: Int,
  member_pubkey: ByteArray,
  metadata_hash: ByteArray,
  tx: transaction.Transaction,
  current_time: Int,
  tx_id: ByteArray,
) -> Bool {
  // Amount must be positive and at least the minimum
  amount > 0 &&
    amount >= constants.min_transaction_amount &&
    // Transaction must be signed by the depositor
    utils.is_signed_by(tx, member_pubkey)
  // Note: In a full implementation, we would verify that the transaction 
  // actually transfers the specified amount to the treasury
}

/// Find a transaction by ID
pub fn find_transaction_by_id(
  transactions: List<Transaction>,
  tx_id: ByteArray,
) -> Option<Transaction> {
  list.find(
    transactions,
    fn(tx) { tx.tx_id == tx_id },
  )
}

/// Validate withdrawal proposal
pub fn validate_propose_withdrawal(
  treasury_info: TreasuryInfo,
  transactions: List<Transaction>,
  amount: Int,
  recipient: ByteArray,
  proposer: ByteArray,
  metadata_hash: ByteArray,
  tx: transaction.Transaction,
  current_time: Int,
  tx_id: ByteArray,
) -> Bool {
  // Amount must be positive and at least the minimum
  amount > 0 &&
    amount >= constants.min_transaction_amount &&
    // Amount must be less than or equal to available balance
    amount <= treasury_info.balance - treasury_info.locked_funds &&
    // Transaction must be signed by the proposer
    utils.is_signed_by(tx, proposer) &&
    // Verify proposer is an admin
    list.has(treasury_info.admins, proposer)
}

/// Validate transaction approval
pub fn validate_approve_transaction(
  treasury_info: TreasuryInfo,
  transactions: List<Transaction>,
  tx_id: ByteArray,
  approver: ByteArray,
  tx: transaction.Transaction,
  current_time: Int,
) -> Bool {
  when find_transaction_by_id(transactions, tx_id) is {
    Some(transaction) -> {
      // Transaction must be in Pending status
      transaction.status == TxPending &&
        // Approver must be an admin
        list.has(treasury_info.admins, approver) &&
        // Approver must not have already approved
        !list.has(transaction.approvals, approver) &&
        // Approver must not have already rejected
        !list.has(transaction.rejections, approver) &&
        // Transaction must be signed by the approver
        utils.is_signed_by(tx, approver)
    }
    None -> False
  }
}

/// Validate transaction rejection
pub fn validate_reject_transaction(
  treasury_info: TreasuryInfo,
  transactions: List<Transaction>,
  tx_id: ByteArray,
  rejecter: ByteArray,
  tx: transaction.Transaction,
  current_time: Int,
) -> Bool {
  when find_transaction_by_id(transactions, tx_id) is {
    Some(transaction) -> {
      // Transaction must be in Pending status
      transaction.status == TxPending &&
        // Rejecter must be an admin
        list.has(treasury_info.admins, rejecter) &&
        // Rejecter must not have already approved
        !list.has(transaction.approvals, rejecter) &&
        // Rejecter must not have already rejected
        !list.has(transaction.rejections, rejecter) &&
        // Transaction must be signed by the rejecter
        utils.is_signed_by(tx, rejecter)
    }
    None -> False
  }
}

/// Check if a transaction has enough approvals
pub fn has_enough_approvals(
  tx: Transaction,
  required_signatures: Int,
) -> Bool {
  list.length(tx.approvals) >= required_signatures
}

/// Validate transaction execution
pub fn validate_execute_transaction(
  treasury_info: TreasuryInfo,
  transactions: List<Transaction>,
  tx_id: ByteArray,
  tx: transaction.Transaction,
  current_time: Int,
) -> Bool {
  when find_transaction_by_id(transactions, tx_id) is {
    Some(transaction) -> {
      // Transaction must be in Approved status or have enough approvals
      (transaction.status == TxApproved || 
       has_enough_approvals(transaction, treasury_info.required_signatures)) &&
        // Treasury must have sufficient funds
        treasury_info.balance >= transaction.amount &&
        // For outgoing transactions, verify the transaction creates the appropriate output
        when transaction.tx_type is {
          TxWithdrawal -> {
            // Note: In a full implementation, we would verify that the transaction 
            // actually transfers the specified amount to the recipient
            True
          }
          _ -> True
        }
    }
    None -> False
  }
}