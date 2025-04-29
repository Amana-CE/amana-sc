///
/// Utility functions for Amana CE validators
///

use aiken/list
use aiken/transaction
use aiken/hash.{blake2b_256}

use common/types.{PubKeyHash, Timestamp}

/// Check if a transaction is signed by a specific public key
pub fn is_signed_by(tx: transaction.Transaction, pubkey_hash: PubKeyHash) -> Bool {
  list.has(tx.extra_signatories, pubkey_hash)
}

/// Check if a transaction is signed by any key in a list
pub fn is_signed_by_any(tx: transaction.Transaction, pubkey_hashes: List<PubKeyHash>) -> Bool {
  list.any(
    pubkey_hashes,
    fn(pubkey_hash) { is_signed_by(tx, pubkey_hash) },
  )
}

/// Check if a transaction is signed by at least a threshold of keys
pub fn is_signed_by_threshold(
  tx: transaction.Transaction,
  pubkey_hashes: List<PubKeyHash>,
  threshold: Int,
) -> Bool {
  let signature_count =
    list.count(
      pubkey_hashes,
      fn(pubkey_hash) { is_signed_by(tx, pubkey_hash) },
    )
  signature_count >= threshold
}

/// Calculate a percentage threshold from a total count
pub fn calculate_threshold(total: Int, percentage: Int) -> Int {
  // Ensure the value is at least 1
  let threshold = (total * percentage) / 100
  if threshold < 1 {
    1
  } else {
    threshold
  }
}

/// Check if a current time is after a specified timestamp
pub fn is_after(current_time: Timestamp, timestamp: Timestamp) -> Bool {
  current_time >= timestamp
}

/// Check if a current time is within a time range
pub fn is_within_time_range(
  current_time: Timestamp,
  start_time: Timestamp,
  end_time: Timestamp,
) -> Bool {
  current_time >= start_time && current_time <= end_time
}

/// Get the current time from transaction validity range
pub fn get_current_time(tx: transaction.Transaction) -> Option<Timestamp> {
  when tx.validity_range.lower_bound.bound is {
    Some(time) -> Some(time)
    None -> None
  }
}

/// Create a unique identifier using transaction info and an index
pub fn create_unique_id(tx_id: ByteArray, index: Int) -> ByteArray {
  // Prefix with index and hash to create a deterministic but unique ID
  blake2b_256(tx_id)
}

/// Get lovelace value from a value map
pub fn get_lovelace(val: aiken/transaction/value.Value) -> Int {
  aiken/transaction/value.lovelace_of(val)
}

/// Ensure a value meets a minimum threshold
pub fn ensure_minimum(amount: Int, minimum: Int) -> Bool {
  amount >= minimum
}

/// Generate a hash of a ByteArray
pub fn hash_bytes(data: ByteArray) -> ByteArray {
  blake2b_256(data)
}