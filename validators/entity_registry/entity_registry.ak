use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/transaction.{InlineDatum, OutputReference, Transaction}
use entity_registry/types.{
  Entity, Member, MemberStatus, RegistryAction, RegistryDatum,
}

/// Entity Registry validator
/// 
/// This validator manages the creation and maintenance of SACCO entities and
/// their members. It serves as the identity layer for the Amana CE platform,
/// ensuring that only authorized participants can access treasury funds and
/// participate in governance.
validator entity_registry {
  spend(
    datum_opt: Option<RegistryDatum>,
    redeemer: RegistryAction,
    own_ref: OutputReference,
    tx: Transaction,
  ) {
    // Extract transaction signatories
    let Transaction { extra_signatories, outputs, .. } = tx

    // Process based on the presence of existing datum
    when datum_opt is {
      Some(datum) -> {
        // Convert members list to Dict for easier lookups
        let members_dict = dict.from_pairs(datum.members)
        // Verify authorization based on redeemer action
        when redeemer is {
          RegistryAction.CreateEntity { name, description } ->
            // Entity already exists, creation should fail
            False
          // Other actions remain as placeholders for now
          RegistryAction.AddMember { member } -> {
            let is_signed_by_admin =
              list.any(
                extra_signatories,
                fn(key) { list.has(datum.admins, key) },
              )
            let member_exists =
              dict.has_key(members_dict, member.verification_key_hash)
            is_signed_by_admin && !member_exists
          }
          RegistryAction.UpdateMemberStatus { member_key, new_status } -> {
            let is_signed_by_admin =
              list.any(
                extra_signatories,
                fn(key) { list.has(datum.admins, key) },
              )
            let member_exists = dict.has_key(members_dict, member_key)
            is_signed_by_admin && member_exists
          }
          RegistryAction.AddAdmin { admin_key } -> {
            let is_signed_by_admin =
              list.any(
                extra_signatories,
                fn(key) { list.has(datum.admins, key) },
              )
            let admin_exists = list.has(datum.admins, admin_key)
            is_signed_by_admin && !admin_exists
          }
          RegistryAction.RemoveAdmin { admin_key } -> {
            let is_signed_by_admin =
              list.any(
                extra_signatories,
                fn(key) { list.has(datum.admins, key) },
              )
            let admin_exists = list.has(datum.admins, admin_key)
            let will_have_admins_left = list.length(datum.admins) > 1
            is_signed_by_admin && admin_exists && will_have_admins_left
          }
        }
      }
      None ->
        // Initial setup case - only CreateEntity is valid when no datum exists
        when redeemer is {
          RegistryAction.CreateEntity { name, description } -> {
            // 1. Verify the entity name and description are not empty
            let valid_name = name != ""
            let valid_description = description != ""
            // 2. Ensure transaction is signed by at least one key
            let has_signer = list.length(extra_signatories) > 0
            if !has_signer || !valid_name || !valid_description {
              False
            } else {
              // 3. Get the founder (first signer)
              expect Some(founder) = list.at(extra_signatories, 0)
              // 4. Check if output datum is correctly initialized
              // Find outputs that contain an inline datum
              let outputs_with_inline_datum =
                list.filter(
                  outputs,
                  fn(output) {
                    when output.datum is {
                      InlineDatum(_) -> True
                      _ -> False
                    }
                  },
                )
              when outputs_with_inline_datum is {
                [output] ->
                  // Verify the output contains a properly initialized datum
                  when output.datum is {
                    InlineDatum(data) -> {
                      expect new_datum: RegistryDatum = data
                      // Verify the entity is properly initialized
                      let entity_valid =
                        new_datum.entity.name == name && new_datum.entity.description == description && new_datum.entity.founder == founder && new_datum.entity.member_count == 0
                      // Verify admins list contains the founder
                      let admins_valid = list.has(new_datum.admins, founder)
                      // Verify members list is empty initially
                      let members_valid = list.length(new_datum.members) == 0
                      entity_valid && admins_valid && members_valid
                    }
                    _ -> False
                  }
                _ -> False
              }
            }
          }
          // Any other action is invalid when no datum exists
          _ -> False
        }
    }
  }

  else(_) {
    // Any other use of this validator should fail
    False
  }
}
