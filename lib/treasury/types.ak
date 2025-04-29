///
/// Treasury types
///

use common/types.{
  Address, Amount, Id, PubKeyHash, Timestamp, TransactionStatus, TransactionType
}

/// Treasury information
pub type TreasuryInfo {
  entity_id: Id,
  balance: Amount,
  required_signatures: Int,
  admins: List<PubKeyHash>,
  locked_funds: Amount,
}

/// Transaction record
pub type Transaction {
  tx_id: Id,
  entity_id: Id,
  tx_type: TransactionType,
  amount: Amount,
  recipient: Address,
  proposer: PubKeyHash,
  timestamp: Timestamp,
  status: TransactionStatus,
  approvals: List<PubKeyHash>,
  rejections: List<PubKeyHash>,
  metadata_hash: ByteArray,
}

/// Treasury datum
pub type TreasuryDatum {
  treasury_info: TreasuryInfo,
  transactions: List<Transaction>,
}

/// Treasury redeemer - defines actions that can be performed
pub type TreasuryAction {
  /// Initialize a treasury for a SACCO entity
  InitializeTreasury {
    entity_id: Id,
    required_signatures: Int,
    admins: List<PubKeyHash>,
  }
  /// Make a deposit to the treasury
  Deposit {
    entity_id: Id,
    amount: Amount,
    member_pubkey: PubKeyHash,
    metadata_hash: ByteArray,
  }
  /// Propose a withdrawal from the treasury
  ProposeWithdrawal {
    entity_id: Id,
    amount: Amount,
    recipient: Address,
    metadata_hash: ByteArray,
  }
  /// Approve a pending transaction
  ApproveTransaction {
    entity_id: Id,
    tx_id: Id,
  }
  /// Reject a pending transaction
  RejectTransaction {
    entity_id: Id,
    tx_id: Id,
  }
  /// Execute an approved transaction
  ExecuteTransaction {
    entity_id: Id,
    tx_id: Id,
  }
}

/// Error codes for treasury operations
pub type TreasuryError {
  /// Treasury for the entity was not found
  TreasuryNotFound
  /// Transaction with the given ID was not found
  TransactionNotFound
  /// Insufficient funds in the treasury
  InsufficientFunds
  /// Transaction already approved by the signer
  AlreadyApproved
  /// Transaction already rejected by the signer
  AlreadyRejected
  /// Transaction is not in a valid state for the action
  InvalidTransactionState
  /// Caller is not authorized to perform the action
  Unauthorized
  /// Amount is not valid (e.g., zero or negative)
  InvalidAmount
}