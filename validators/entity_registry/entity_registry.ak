use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/transaction.{OutputReference, Transaction}
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
    let Transaction { extra_signatories, .. } = tx

    // Process based on the presence of existing datum
    when datum_opt is {
      Some(datum) -> {
        // Convert members list to Dict for easier lookups
        let members_dict = dict.from_pairs(datum.members)
        // Verify authorization based on redeemer action
        when redeemer is {
          RegistryAction.CreateEntity { name, description } ->
            // TODO: Validation logic for CreateEntity:
            // 1. Entity already exists, so creation should fail
            // 2. Return False to indicate failure
            // Entity already exists, creation should fail
            False
          RegistryAction.AddMember { member } -> {
            // TODO: Validation logic for AddMember:
            // 1. Ensure transaction is signed by an admin
            // 2. Check that member doesn't already exist
            // 3. Validate member data (non-empty name, valid status)
            // 4. Check if output datum is correctly updated
            // Check if transaction is signed by an admin
            let is_signed_by_admin =
              list.any(
                extra_signatories,
                fn(key) { list.has(datum.admins, key) },
              )
            // Check if member already exists
            let member_exists =
              dict.has_key(members_dict, member.verification_key_hash)
            // Basic validation - admin signed and member doesn't exist
            is_signed_by_admin && !member_exists
          }
          RegistryAction.UpdateMemberStatus { member_key, new_status } -> {
            // TODO: Validation logic for UpdateMemberStatus:
            // 1. Ensure transaction is signed by an admin
            // 2. Verify member exists
            // 3. Validate the new status
            // 4. Check if output datum is correctly updated
            // Check if transaction is signed by an admin
            let is_signed_by_admin =
              list.any(
                extra_signatories,
                fn(key) { list.has(datum.admins, key) },
              )
            // Check if member exists
            let member_exists = dict.has_key(members_dict, member_key)
            // Basic validation - admin signed and member exists
            is_signed_by_admin && member_exists
          }
          RegistryAction.AddAdmin { admin_key } -> {
            // TODO: Validation logic for AddAdmin:
            // 1. Ensure transaction is signed by an existing admin
            // 2. Check that the new admin doesn't already exist
            // 3. Check if output datum is correctly updated
            // Check if transaction is signed by an admin
            let is_signed_by_admin =
              list.any(
                extra_signatories,
                fn(key) { list.has(datum.admins, key) },
              )
            // Check if admin already exists
            let admin_exists = list.has(datum.admins, admin_key)
            // Basic validation - admin signed and new admin doesn't exist
            is_signed_by_admin && !admin_exists
          }
          RegistryAction.RemoveAdmin { admin_key } -> {
            // TODO: Validation logic for RemoveAdmin:
            // 1. Ensure transaction is signed by an existing admin
            // 2. Check that admin exists
            // 3. Ensure we're not removing the last admin
            // 4. Check if output datum is correctly updated
            // Check if transaction is signed by an admin
            let is_signed_by_admin =
              list.any(
                extra_signatories,
                fn(key) { list.has(datum.admins, key) },
              )
            // Check if admin exists
            let admin_exists = list.has(datum.admins, admin_key)
            // Check if there will be admins left after removal
            let will_have_admins_left = list.length(datum.admins) > 1
            // Basic validation - admin signed, admin exists, and not removing last admin
            is_signed_by_admin && admin_exists && will_have_admins_left
          }
        }
      }
      None ->
        // Initial setup case - only CreateEntity is valid when no datum exists
        when redeemer is {
          RegistryAction.CreateEntity { name, description } ->
            // TODO: Validation logic for CreateEntity:
            // 1. Verify the entity name and description are not empty
            // 2. Ensure transaction is signed
            // 3. Set the founder to the transaction signer
            // 4. Check if output datum is correctly initialized
            // Get the signer, assuming there is at least one
            if list.length(extra_signatories) == 0 {
              False
            } else {
              // Basic validation - verify entity name and description are not empty
              name != "" && description != ""
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
