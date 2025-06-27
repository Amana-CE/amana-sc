// lib/nft_policy/types.ak
// Member NFT Policy Types - MVP with Entity Registry Integration
// Types for NFT-based member identity certificates

use aiken/crypto.{VerificationKeyHash}

/// NFT metadata structure for member certificates
pub type MemberNFTMetadata {
  member_name: ByteArray,
  entity_name: ByteArray,
  member_vkh: VerificationKeyHash,
  join_date: Int,
  membership_level: MembershipLevel,
  voting_power: Int,
  entity_id: ByteArray,
}

/// Membership level enumeration
pub type MembershipLevel {
  Standard
  Premium
  Admin
  Founder
}

/// Redeemer actions for NFT minting/burning
pub type MintAction {
  // Mint member NFT - must be linked to entity registry transaction
  MintMember {
    member_hash: VerificationKeyHash,
    entity_name: ByteArray,
    membership_level: MembershipLevel,
  }
  // Burn member NFT - when member is removed
  BurnMember { member_hash: VerificationKeyHash }
}

/// NFT validation result
pub type NFTValidationResult {
  Valid
  InvalidEntityRef
  InvalidMintAmount
  InvalidRecipient
  InvalidTokenName
  EntityNotSpent
}
