///
/// Entity Registry types
///

use common/types.{
  Address, EntityStatus, Id, MemberRole, MemberStatus, PubKeyHash, Timestamp
}

/// Entity Parameters configuration
pub type EntityParameters {
  membership_fee: Int,
  min_contribution: Int,
  max_members: Int,
  voting_threshold: Int,
  approval_threshold: Int,
  voting_period: Int,
}

/// Entity record
pub type Entity {
  entity_id: Id,
  name: ByteArray,
  description: ByteArray,
  creation_timestamp: Timestamp,
  admin_pubkeys: List<PubKeyHash>,
  parameters: EntityParameters,
  status: EntityStatus,
  metadata_hash: ByteArray,
}

/// Member record
pub type Member {
  entity_id: Id,
  member_id: Id,
  pubkey_hash: PubKeyHash,
  join_timestamp: Timestamp,
  status: MemberStatus,
  role: MemberRole,
  metadata_hash: ByteArray,
}

/// Entity datum - holds the state of the entity on-chain
pub type EntityDatum {
  entity: Entity,
  members: List<Member>,
}

/// Entity redeemer - defines actions that can be performed
pub type EntityAction {
  /// Create a new SACCO entity
  CreateEntity {
    name: ByteArray,
    description: ByteArray,
    admin_pubkeys: List<PubKeyHash>,
    parameters: EntityParameters,
    metadata_hash: ByteArray,
  }
  /// Update an entity's configuration parameters
  UpdateEntityParameters {
    entity_id: Id,
    new_parameters: EntityParameters,
  }
  /// Register a new member to an entity
  RegisterMember {
    entity_id: Id,
    member_pubkey: PubKeyHash,
    metadata_hash: ByteArray,
  }
  /// Update a member's status (active, suspended, removed)
  UpdateMemberStatus {
    entity_id: Id,
    member_id: Id,
    new_status: MemberStatus,
  }
  /// Update an entity's status (active, suspended, dissolved)
  UpdateEntityStatus {
    entity_id: Id,
    new_status: EntityStatus,
  }
}

/// Error codes for entity operations
pub type EntityError {
  /// Entity with the given ID was not found
  EntityNotFound
  /// Member with the given ID was not found
  MemberNotFound
  /// Entity already exists with the given name
  EntityAlreadyExists
  /// Member already exists in the entity
  MemberAlreadyExists
  /// Entity reached maximum member capacity
  MemberLimitReached
  /// Caller is not authorized to perform the action
  Unauthorized
  /// Entity is not in active status
  EntityNotActive
  /// Invalid parameters provided
  InvalidParameters
}