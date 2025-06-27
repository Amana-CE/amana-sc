// validators/entity_registry/entity_registry.ak
// Entity Registry Validator - MVP with NFT Integration
// Single contract serving multiple SACCO entities

use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use aiken/primitive/bytearray
use cardano/transaction.{InlineDatum, Output, OutputReference, Transaction}
use entity_registry/types.{Entity, Member, RegistryAction, RegistryDatum}

// Helper Functions - defined before validator

/// Extract current time from transaction validity range - simplified for MVP
fn get_current_time(tx: Transaction) -> Int {
  // For MVP, we use a simple approach
  // In production, you would properly extract from tx.validity_range
  1625097600000
  // Placeholder timestamp for MVP
}

/// Validate entity creation inputs
fn validate_entity_inputs(name: ByteArray, description: ByteArray) -> Bool {
  let valid_name = name != #"" && bytearray.length(name) <= 64
  let valid_description =
    description != #"" && bytearray.length(description) <= 256
  valid_name && valid_description
}

/// Validate member data including NFT token name
fn validate_member_data(member: Member, current_time: Int) -> Bool {
  let valid_name = member.name != #"" && bytearray.length(member.name) <= 64
  let valid_vkh = member.verification_key_hash != #""
  let valid_time = member.join_time > 0 && member.join_time <= current_time
  let valid_nft_name = member.nft_token_name != #""
  valid_name && valid_vkh && valid_time && valid_nft_name
}

/// Validate NFT token name follows expected pattern
fn validate_nft_token_name(
  token_name: ByteArray,
  _member_vkh: VerificationKeyHash,
) -> Bool {
  // For MVP: Simple validation that token name is not empty
  // POST-MVP: Implement proper token name derivation from member VKH
  token_name != #""
}

/// Check if member already exists in entity
fn member_already_exists(
  members: List<Member>,
  vkh: VerificationKeyHash,
) -> Bool {
  list.any(members, fn(member) { member.verification_key_hash == vkh })
}

/// Verify entity creation output is correctly formatted
fn verify_create_entity_output(
  outputs: List<Output>,
  name: ByteArray,
  description: ByteArray,
  founder: VerificationKeyHash,
  current_time: Int,
) -> Bool {
  // Find outputs with inline datum (new entity UTxO)
  let script_outputs =
    list.filter(
      outputs,
      fn(output) {
        when output.datum is {
          InlineDatum(_) -> True
          _ -> False
        }
      },
    )
  when script_outputs is {
    [output] ->
      when output.datum is {
        InlineDatum(data) -> {
          expect new_datum: RegistryDatum = data
          // Verify entity is properly initialized
          let entity_valid =
            new_datum.entity.name == name && new_datum.entity.description == description && new_datum.entity.founder == founder && new_datum.entity.creation_time >= current_time && new_datum.entity.member_count == 0
          // Verify admin is set to founder
          let admin_valid = new_datum.admin == founder
          // Verify members list is empty initially
          let members_valid = list.is_empty(new_datum.members)
          entity_valid && admin_valid && members_valid
        }
        _ -> False
      }
    _ -> False
  }
}

/// Verify member addition output is correctly formatted
fn verify_add_member_output(
  outputs: List<Output>,
  old_datum: RegistryDatum,
  new_member: Member,
) -> Bool {
  // Find outputs with inline datum (updated entity UTxO)
  let script_outputs =
    list.filter(
      outputs,
      fn(output) {
        when output.datum is {
          InlineDatum(_) -> True
          _ -> False
        }
      },
    )
  when script_outputs is {
    [output] ->
      when output.datum is {
        InlineDatum(data) -> {
          expect new_datum: RegistryDatum = data
          // Verify entity fields remain unchanged except member_count
          let entity_unchanged =
            new_datum.entity.name == old_datum.entity.name && new_datum.entity.description == old_datum.entity.description && new_datum.entity.founder == old_datum.entity.founder && new_datum.entity.creation_time == old_datum.entity.creation_time && new_datum.entity.member_count == old_datum.entity.member_count + 1
          // Verify admin remains unchanged
          let admin_unchanged = new_datum.admin == old_datum.admin
          // Verify all existing members are preserved
          let existing_members_preserved =
            list.all(
              old_datum.members,
              fn(old_member) {
                list.any(
                  new_datum.members,
                  fn(new_member_check) { old_member == new_member_check },
                )
              },
            )
          // Verify new member is added correctly
          let new_member_added =
            list.any(
              new_datum.members,
              fn(member) {
                member.name == new_member.name && member.verification_key_hash == new_member.verification_key_hash && member.join_time == new_member.join_time && member.nft_token_name == new_member.nft_token_name
              },
            )
          // Verify member count is correct
          let member_count_correct =
            list.length(new_datum.members) == list.length(old_datum.members) + 1
          entity_unchanged && admin_unchanged && existing_members_preserved && new_member_added && member_count_correct
        }
        _ -> False
      }
    _ -> False
  }
}

/// Entity Registry validator - MVP Version with NFT Integration
/// 
/// Single contract deployment serving multiple SACCO entities.
/// Each SACCO is a separate UTxO at this contract address.
/// Includes basic NFT verification for member certificates.
validator entity_registry {
  spend(
    datum_opt: Option<RegistryDatum>,
    redeemer: RegistryAction,
    _own_ref: OutputReference,
    tx: Transaction,
  ) {
    let current_time = get_current_time(tx)

    when datum_opt is {
      Some(datum) ->
        // Existing entity UTxO - member management operations
        when redeemer is {
          RegistryAction.CreateEntity { .. } ->
            // Cannot create entity when UTxO already exists
            False
          RegistryAction.AddMember { member } -> {
            // Validate member addition with NFT integration
            let valid_member_data = validate_member_data(member, current_time)
            let is_signed_by_admin = list.has(tx.extra_signatories, datum.admin)
            let member_exists =
              member_already_exists(datum.members, member.verification_key_hash)
            let valid_nft_reference =
              validate_nft_token_name(
                member.nft_token_name,
                member.verification_key_hash,
              )
            if !valid_member_data || !is_signed_by_admin || member_exists || !valid_nft_reference {
              False
            } else {
              verify_add_member_output(tx.outputs, datum, member)
            }
          }
        }
      None ->
        // New entity creation - creates new UTxO at this contract
        when redeemer is {
          RegistryAction.CreateEntity { name, description } -> {
            let valid_inputs = validate_entity_inputs(name, description)
            let has_signer = list.length(tx.extra_signatories) > 0
            if !valid_inputs || !has_signer {
              False
            } else {
              expect Some(founder) = list.at(tx.extra_signatories, 0)
              verify_create_entity_output(
                tx.outputs,
                name,
                description,
                founder,
                current_time,
              )
            }
          }
          RegistryAction.AddMember { .. } ->
            // Cannot add member when no entity exists
            False
        }
    }
  }

  else(_) {
    False
  }
}
// POST-MVP DEVELOPMENT ROADMAP:
// - Atomic member registration + NFT minting in single transaction
// - Multi-admin support with role-based permissions  
// - Member status management (Active/Inactive/Suspended)
// - NFT-gated governance voting integration
// - Treasury and governance contract linking
// - Compliance features and audit trails
// - Cross-entity member portability
// - Emergency procedures and recovery mechanisms
