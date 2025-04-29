///
/// Entity Registry validation logic
///

use aiken/list
use aiken/transaction.{Transaction}

use common/constants
use common/types.{EntityStatus, MemberRole, MemberStatus, PubKeyHash}
use common/utils
use entity/types.{Entity, EntityAction, EntityDatum, EntityParameters, Member}

/// Validate entity parameters
pub fn validate_entity_parameters(parameters: EntityParameters) -> Bool {
  parameters.membership_fee >= constants.min_membership_fee &&
    parameters.min_contribution >= constants.min_contribution &&
    parameters.max_members > 0 &&
    parameters.max_members <= constants.max_allowed_members &&
    parameters.voting_threshold > 0 &&
    parameters.voting_threshold <= 100 &&
    parameters.approval_threshold > 0 &&
    parameters.approval_threshold <= 100 &&
    parameters.voting_period > 0
}

/// Validate entity creation request
pub fn validate_create_entity(
  entity_id: ByteArray,
  name: ByteArray,
  description: ByteArray,
  admin_pubkeys: List<PubKeyHash>,
  parameters: EntityParameters,
  metadata_hash: ByteArray,
  transaction: Transaction,
  current_time: Int,
) -> Bool {
  // Name must not be empty
  list.length(name) > 0 &&
    // Must have at least the minimum number of admins
    list.length(admin_pubkeys) >= constants.min_admins &&
    // Parameters must be valid
    validate_entity_parameters(parameters) &&
    // Transaction must be signed by at least one admin
    utils.is_signed_by_any(transaction, admin_pubkeys)
}

/// Validate entity parameters update request
pub fn validate_update_entity_parameters(
  entity: Entity,
  new_parameters: EntityParameters,
  transaction: Transaction,
) -> Bool {
  entity.status == EntityActive &&
    validate_entity_parameters(new_parameters) &&
    utils.is_signed_by_any(transaction, entity.admin_pubkeys)
}

/// Find a member in a list by pubkey hash
pub fn find_member_by_pubkey(
  members: List<Member>,
  pubkey_hash: PubKeyHash,
) -> Option<Member> {
  list.find(
    members,
    fn(member) { member.pubkey_hash == pubkey_hash },
  )
}

/// Find a member in a list by member ID
pub fn find_member_by_id(
  members: List<Member>,
  member_id: ByteArray,
) -> Option<Member> {
  list.find(
    members,
    fn(member) { member.member_id == member_id },
  )
}

/// Check if pubkey belongs to an admin
pub fn is_admin(
  members: List<Member>,
  pubkey_hash: PubKeyHash,
) -> Bool {
  when find_member_by_pubkey(members, pubkey_hash) is {
    Some(member) ->
      member.role == RoleAdmin && member.status == MemberActive
    None -> False
  }
}

/// Validate member registration request
pub fn validate_register_member(
  entity: Entity,
  members: List<Member>,
  member_id: ByteArray,
  member_pubkey: PubKeyHash,
  metadata_hash: ByteArray,
  transaction: Transaction,
  current_time: Int,
) -> Bool {
  // Entity must be active
  entity.status == EntityActive &&
    // Must not exceed max members
    list.length(members) < entity.parameters.max_members &&
    // Member must not already exist
    find_member_by_pubkey(members, member_pubkey) == None &&
    // Transaction must be signed by an admin
    utils.is_signed_by_any(
      transaction,
      list.filter(
        members,
        fn(m) { m.role == RoleAdmin && m.status == MemberActive },
      )
        |> list.map(fn(m) { m.pubkey_hash }),
    )
}

/// Validate member status update request
pub fn validate_update_member_status(
  entity: Entity,
  members: List<Member>,
  member_id: ByteArray,
  new_status: MemberStatus,
  transaction: Transaction,
) -> Bool {
  // Entity must be active
  entity.status == EntityActive &&
    // Transaction must be signed by an admin
    utils.is_signed_by_any(
      transaction,
      list.filter(
        members,
        fn(m) { m.role == RoleAdmin && m.status == MemberActive },
      )
        |> list.map(fn(m) { m.pubkey_hash }),
    ) &&
    // If removing an admin, must have at least one admin left
    when new_status is {
      MemberRemoved -> {
        let admin_count =
          list.count(
            members,
            fn(m) { m.role == RoleAdmin && m.status == MemberActive },
          )
        
        let target_member = find_member_by_id(members, member_id)
        when target_member is {
          Some(member) -> 
            if member.role == RoleAdmin && member.status == MemberActive {
              admin_count > 1
            } else {
              True
            }
          None -> False
        }
      }
      _ -> True
    }
}

/// Validate entity status update request
pub fn validate_update_entity_status(
  entity: Entity,
  members: List<Member>,
  new_status: EntityStatus,
  transaction: Transaction,
) -> Bool {
  // Get all active admins
  let active_admins =
    list.filter(
      members,
      fn(member) {
        member.role == RoleAdmin && member.status == MemberActive
      },
    )
    |> list.map(fn(member) { member.pubkey_hash })

  // Calculate threshold for admin approval
  let threshold =
    utils.calculate_threshold(
      list.length(active_admins),
      entity.parameters.approval_threshold,
    )

  // Verify that majority of admins have signed the transaction
  utils.is_signed_by_threshold(transaction, active_admins, threshold)
}