// lib/entity_registry/types.ak
// Entity Registry Types - MVP with NFT Integration
// Types for single contract serving multiple SACCO entities

use aiken/crypto.{VerificationKeyHash}

/// SACCO entity metadata
pub type Entity {
  name: ByteArray,
  description: ByteArray,
  creation_time: Int,
  founder: VerificationKeyHash,
  member_count: Int,
}

/// Member record with NFT integration
pub type Member {
  name: ByteArray,
  verification_key_hash: VerificationKeyHash,
  join_time: Int,
  nft_token_name: ByteArray,
}

/// Registry datum - stored on-chain for each SACCO entity
pub type RegistryDatum {
  entity: Entity,
  members: List<Member>,
  admin: VerificationKeyHash,
}

/// Redeemer actions for entity operations
pub type RegistryAction {
  CreateEntity { name: ByteArray, description: ByteArray }
  AddMember { member: Member }
}
// POST-MVP EXTENSIONS:
// - Add MemberStatus enum (Active/Inactive/Suspended)
// - Multi-admin support with role-based permissions
// - Member levels and KYC verification status
// - Governance configuration and treasury settings
// - Compliance framework and audit trails
// - Enhanced redeemer actions for status updates
// - Cross-entity member portability
// - Integration with external systems
