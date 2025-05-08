use aiken/collection/dict
use aiken/collection/list
use cardano/transaction.{InlineDatum, OutputReference, Transaction}
use entity_registry/types.{Entity, Member, RegistryAction, RegistryDatum}

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
    _own_ref: OutputReference,
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
          RegistryAction.CreateEntity { .. } ->
            // Entity already exists, creation should fail
            False
          RegistryAction.AddMember { member } -> {
            // 1. Ensure transaction is signed by an admin
            let is_signed_by_admin =
              list.any(
                extra_signatories,
                fn(key) { list.has(datum.admins, key) },
              )
            // 2. Check that member doesn't already exist
            let member_exists =
              dict.has_key(members_dict, member.verification_key_hash)
            // 3. Validate member data (non-empty name, valid status)
            let valid_member_data = member.name != "" && member.join_time > 0
            if !is_signed_by_admin || member_exists || !valid_member_data {
              False
            } else {
              // 4. Check if output datum is correctly updated
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
                  // Verify the output contains a properly updated datum
                  when output.datum is {
                    InlineDatum(data) -> {
                      expect new_datum: RegistryDatum = data
                      // Convert both member lists to pairs for comparison
                      let old_members_pairs = datum.members
                      let new_members_pairs = new_datum.members
                      // Verify the entity is updated with correct member count
                      let entity_updated =
                        new_datum.entity.name == datum.entity.name && new_datum.entity.description == datum.entity.description && new_datum.entity.founder == datum.entity.founder && new_datum.entity.member_count == datum.entity.member_count + 1
                      // Verify all existing members are preserved
                      let contains_all_existing_members =
                        list.all(
                          old_members_pairs,
                          fn(pair) { list.has(new_members_pairs, pair) },
                        )
                      // Verify the new member is added
                      let contains_new_member =
                        list.any(
                          new_members_pairs,
                          fn(pair) {
                            let Pair(key, value) = pair
                            key == member.verification_key_hash && value.name == member.name && value.join_time == member.join_time && value.status == member.status
                          },
                        )
                      // Verify members list size increased by exactly one
                      let correct_member_count =
                        list.length(new_members_pairs) == list.length(
                          old_members_pairs,
                        ) + 1
                      // Verify admins remain unchanged
                      let admins_unchanged = new_datum.admins == datum.admins
                      entity_updated && contains_all_existing_members && contains_new_member && correct_member_count && admins_unchanged
                    }
                    _ -> False
                  }
                _ -> False
              }
            }
          }
          RegistryAction.UpdateMemberStatus { member_key, new_status } -> {
            // 1. Ensure transaction is signed by an admin
            let is_signed_by_admin =
              list.any(
                extra_signatories,
                fn(key) { list.has(datum.admins, key) },
              )
            // 2. Verify member exists
            let member_exists = dict.has_key(members_dict, member_key)
            // Get the current member if it exists
            let current_member = dict.get(members_dict, member_key)
            if !is_signed_by_admin || !member_exists {
              False
            } else {
              // 3. Check if output datum is correctly updated
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
                  // Verify the output contains a properly updated datum
                  when output.datum is {
                    InlineDatum(data) -> {
                      expect new_datum: RegistryDatum = data
                      expect Some(member_data) = current_member
                      // Verify the entity remains unchanged
                      let entity_unchanged =
                        new_datum.entity.name == datum.entity.name && new_datum.entity.description == datum.entity.description && new_datum.entity.founder == datum.entity.founder && new_datum.entity.member_count == datum.entity.member_count
                      // Convert new members to dict for easier lookup
                      let new_members_dict = dict.from_pairs(new_datum.members)
                      // Check that the member has been updated with new status
                      let member_updated =
                        when dict.get(new_members_dict, member_key) is {
                          Some(updated_member) ->
                            updated_member.name == member_data.name && updated_member.join_time == member_data.join_time && updated_member.status == new_status
                          None -> False
                        }
                      // Verify all other members remain unchanged
                      let other_members_unchanged =
                        list.all(
                          datum.members,
                          fn(pair) {
                            let Pair(key, value) = pair
                            if key == member_key {
                              // Skip the updated member
                              True
                            } else {
                              // Check other members remain unchanged
                              when dict.get(new_members_dict, key) is {
                                Some(new_value) -> new_value == value
                                None -> False
                              }
                            }
                          },
                        )
                      // Verify members count remains the same
                      let member_count_unchanged =
                        list.length(new_datum.members) == list.length(
                          datum.members,
                        )
                      // Verify admins remain unchanged
                      let admins_unchanged = new_datum.admins == datum.admins
                      entity_unchanged && member_updated && other_members_unchanged && member_count_unchanged && admins_unchanged
                    }
                    _ -> False
                  }
                _ -> False
              }
            }
          }
          RegistryAction.AddAdmin { admin_key } -> {
            // 1. Ensure transaction is signed by an existing admin
            let is_signed_by_admin =
              list.any(
                extra_signatories,
                fn(key) { list.has(datum.admins, key) },
              )
            // 2. Check that the new admin doesn't already exist
            let admin_exists = list.has(datum.admins, admin_key)
            if !is_signed_by_admin || admin_exists {
              False
            } else {
              // 3. Verify output datum is correctly updated
              // Find outputs with inline datum
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
                  // Verify the output contains a properly updated datum
                  when output.datum is {
                    InlineDatum(data) -> {
                      expect new_datum: RegistryDatum = data
                      // Verify the entity remains unchanged
                      let entity_unchanged =
                        new_datum.entity.name == datum.entity.name && new_datum.entity.description == datum.entity.description && new_datum.entity.founder == datum.entity.founder && new_datum.entity.member_count == datum.entity.member_count
                      // Verify the admin list contains all existing admins plus the new one
                      let contains_all_existing_admins =
                        list.all(
                          datum.admins,
                          fn(admin) { list.has(new_datum.admins, admin) },
                        )
                      let contains_new_admin =
                        list.has(new_datum.admins, admin_key)
                      // Verify the admin list size increased by exactly one
                      let correct_admin_count =
                        list.length(new_datum.admins) == list.length(
                          datum.admins,
                        ) + 1
                      // Verify members remain unchanged
                      let members_unchanged =
                        dict.to_pairs(dict.from_pairs(new_datum.members)) == dict.to_pairs(
                          dict.from_pairs(datum.members),
                        )
                      entity_unchanged && contains_all_existing_admins && contains_new_admin && correct_admin_count && members_unchanged
                    }
                    _ -> False
                  }
                _ -> False
              }
            }
          }
          RegistryAction.RemoveAdmin { admin_key } -> {
            // 1. Ensure transaction is signed by an existing admin
            let is_signed_by_admin =
              list.any(
                extra_signatories,
                fn(key) { list.has(datum.admins, key) },
              )
            // 2. Check that admin exists
            let admin_exists = list.has(datum.admins, admin_key)
            // 3. Ensure we're not removing the last admin
            let will_have_admins_left = list.length(datum.admins) > 1
            if !is_signed_by_admin || !admin_exists || !will_have_admins_left {
              False
            } else {
              // 4. Check if output datum is correctly updated
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
                  // Verify the output contains a properly updated datum
                  when output.datum is {
                    InlineDatum(data) -> {
                      expect new_datum: RegistryDatum = data
                      // Verify the entity remains unchanged
                      let entity_unchanged =
                        new_datum.entity.name == datum.entity.name && new_datum.entity.description == datum.entity.description && new_datum.entity.founder == datum.entity.founder && new_datum.entity.member_count == datum.entity.member_count
                      // Verify all admins except the removed one are preserved
                      let contains_all_other_admins =
                        list.all(
                          datum.admins,
                          fn(admin) {
                            if admin == admin_key {
                              True
                            } else {
                              // Skip the admin being removed
                              list.has(new_datum.admins, admin)
                            }
                          },
                        )
                      // Verify the admin to remove is not in the new list
                      let admin_removed = !list.has(new_datum.admins, admin_key)
                      // Verify admin list size decreased by exactly one
                      let correct_admin_count =
                        list.length(new_datum.admins) == list.length(
                          datum.admins,
                        ) - 1
                      // Verify members remain unchanged
                      let members_unchanged = new_datum.members == datum.members
                      entity_unchanged && contains_all_other_admins && admin_removed && correct_admin_count && members_unchanged
                    }
                    _ -> False
                  }
                _ -> False
              }
            }
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
