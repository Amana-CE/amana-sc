use aiken/collection/dict.{Dict}
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}

/// Types for the Entity Registry contract
/// These types represent the core data structures used for SACCO entities and their members
/// SACCO entity metadata
pub type Entity {
  name: ByteArray,
  description: ByteArray,
  creation_time: Int,
  founder: VerificationKeyHash,
  member_count: Int,
}

/// Member record
pub type Member {
  name: ByteArray,
  verification_key_hash: VerificationKeyHash,
  join_time: Int,
  status: MemberStatus,
}

/// Member status enumeration
pub type MemberStatus {
  Active
  Inactive
  Suspended
}

/// Registry datum - stored on-chain
pub type RegistryDatum {
  entity: Entity,
  // Use a map from verification key hash to member data
  members: Dict<VerificationKeyHash, Member>,
  // Addresses authorized to update the registry
  admins: List<VerificationKeyHash>,
}

/// Redeemer actions
pub type RegistryAction {
  // Create a new SACCO entity
  CreateEntity { name: ByteArray, description: ByteArray }
  // Add a new member to the entity
  AddMember { member: Member }
  // Update member status
  UpdateMemberStatus {
    member_key: VerificationKeyHash,
    new_status: MemberStatus,
  }
  // Add a new admin
  AddAdmin { admin_key: VerificationKeyHash }
  // Remove an admin
  RemoveAdmin { admin_key: VerificationKeyHash }
}
