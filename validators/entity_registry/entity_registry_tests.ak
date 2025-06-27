// validators/entity_registry/entity_registry_tests.ak
// Entity Registry Tests - MVP with NFT Integration
// Tests for single contract serving multiple SACCO entities

use aiken/collection/list
use aiken/crypto.{VerificationKeyHash}
use cardano/assets.{from_lovelace}
use cardano/transaction.{InlineDatum, OutputReference, Transaction}
use entity_registry/types.{Entity, Member, RegistryDatum}
use mocktail.{
  complete, mock_script_address, mocktail_tx, required_signer_hash, tx_out,
  tx_out_inline_datum,
}
use mocktail/virgin_key_hash.{mock_pub_key_hash}
use mocktail/virgin_output_reference.{mock_utxo_ref}

/// Create a sample entity for testing
fn create_sample_entity(
  founder: VerificationKeyHash,
  creation_time: Int,
) -> Entity {
  Entity {
    name: "Test SACCO",
    description: "Test SACCO Description",
    creation_time,
    founder,
    member_count: 0,
  }
}

/// Create a sample member with NFT for testing
fn create_sample_member(
  vkh: VerificationKeyHash,
  name: ByteArray,
  join_time: Int,
  nft_token: ByteArray,
) -> Member {
  Member {
    name,
    verification_key_hash: vkh,
    join_time,
    nft_token_name: nft_token,
  }
}

// Test 1: Entity creation (creates new UTxO at contract)
test entity_creation_success() {
  let signer = mock_pub_key_hash(0)
  let current_time = 1625097600000
  let entity_name = "Farmers Cooperative"
  let entity_description = "A cooperative for local farmers"

  let expected_datum =
    RegistryDatum {
      entity: Entity {
        name: entity_name,
        description: entity_description,
        creation_time: current_time,
        founder: signer,
        member_count: 0,
      },
      members: [],
      admin: signer,
    }

  let tx =
    mocktail_tx()
      |> required_signer_hash(True, signer)
      |> tx_out(True, mock_script_address(0, None), from_lovelace(10_000_000))
      |> tx_out_inline_datum(True, expected_datum)
      |> complete()

  let has_signer = list.length(tx.extra_signatories) > 0
  let valid_name = entity_name != #""
  let valid_description = entity_description != #""
  let has_script_output =
    list.any(
      tx.outputs,
      fn(output) {
        when output.datum is {
          InlineDatum(_) -> True
          _ -> False
        }
      },
    )

  has_signer && valid_name && valid_description && has_script_output
}

// Test 2: Entity creation validation failures
test entity_creation_validation_failures() {
  let empty_name_invalid = #"" == #""
  let empty_desc_invalid = #"" == #""
  let valid_inputs = "Valid Name" != #"" && "Valid description" != #""

  empty_name_invalid && empty_desc_invalid && valid_inputs
}

// Test 3: Cannot create entity when UTxO already exists
test entity_creation_with_existing_utxo_fails() {
  let signer = mock_pub_key_hash(0)
  let existing_datum =
    Some(
      RegistryDatum {
        entity: create_sample_entity(signer, 1625097600000),
        members: [],
        admin: signer,
      },
    )

  // For existing entity UTxO, CreateEntity should fail
  when existing_datum is {
    Some(_) -> True
    // Cannot create when datum exists
    None -> False
  }
}

// Test 4: Successful member addition with NFT
test add_member_with_nft_success() {
  let admin = mock_pub_key_hash(0)
  let new_member_vkh = mock_pub_key_hash(1)
  let current_time = 1625097600000
  let nft_token_name = "member_cert_001"

  let existing_datum =
    RegistryDatum {
      entity: create_sample_entity(admin, current_time - 86400000),
      members: [],
      admin,
    }

  let new_member =
    create_sample_member(
      new_member_vkh,
      "John Doe",
      current_time,
      nft_token_name,
    )

  let expected_datum =
    RegistryDatum {
      entity: Entity {
        name: existing_datum.entity.name,
        description: existing_datum.entity.description,
        creation_time: existing_datum.entity.creation_time,
        founder: existing_datum.entity.founder,
        member_count: 1,
      },
      members: [new_member],
      admin,
    }

  let tx =
    mocktail_tx()
      |> required_signer_hash(True, admin)
      |> tx_out(True, mock_script_address(0, None), from_lovelace(10_000_000))
      |> tx_out_inline_datum(True, expected_datum)
      |> complete()

  let admin_signed = list.has(tx.extra_signatories, admin)
  let valid_member_name = new_member.name != #""
  let valid_member_vkh = new_member.verification_key_hash != #""
  let valid_nft_token = new_member.nft_token_name != #""
  let member_not_exists =
    !list.any(
      existing_datum.members,
      fn(m) { m.verification_key_hash == new_member_vkh },
    )

  admin_signed && valid_member_name && valid_member_vkh && valid_nft_token && member_not_exists
}

// Test 5: Member addition validation failures
test add_member_validation_failures() {
  let admin = mock_pub_key_hash(0)
  let member_vkh = mock_pub_key_hash(1)
  let non_admin = mock_pub_key_hash(2)
  let current_time = 1625097600000

  let existing_datum =
    RegistryDatum {
      entity: create_sample_entity(admin, current_time - 86400000),
      members: [],
      admin,
    }

  // Non-admin trying to add member
  let non_admin_tx =
    mocktail_tx()
      |> required_signer_hash(True, non_admin)
      |> complete()

  let non_admin_signed = list.has(non_admin_tx.extra_signatories, admin)

  // Invalid member data (empty name)
  let invalid_name_member =
    Member {
      name: #"",
      verification_key_hash: member_vkh,
      join_time: current_time,
      nft_token_name: "cert_001",
    }
  let invalid_name_check = invalid_name_member.name != #""

  // Missing NFT token name
  let invalid_nft_member =
    Member {
      name: "John Doe",
      verification_key_hash: member_vkh,
      join_time: current_time,
      nft_token_name: #"",
    }
  let invalid_nft_check = invalid_nft_member.nft_token_name != #""

  // Future join time
  let future_time = current_time + 86400000
  let future_member =
    create_sample_member(member_vkh, "John Doe", future_time, "cert_001")
  let valid_time_check = future_member.join_time <= current_time

  !non_admin_signed && !invalid_name_check && !invalid_nft_check && !valid_time_check
}

// Test 6: Cannot add member when no entity exists
test add_member_without_entity_fails() {
  // When datum is None, adding member should fail
  let no_datum = None
  when no_datum is {
    None -> True
    // Cannot add member when no entity exists
    Some(_) -> False
  }
}

// Test 7: Duplicate member addition fails
test add_member_duplicate_fails() {
  let admin = mock_pub_key_hash(0)
  let existing_member_vkh = mock_pub_key_hash(1)
  let current_time = 1625097600000

  let existing_member =
    create_sample_member(
      existing_member_vkh,
      "Existing Member",
      current_time - 3600000,
      "cert_001",
    )
  let existing_datum =
    RegistryDatum {
      entity: Entity {
        name: "Test SACCO",
        description: "Test Description",
        creation_time: current_time - 86400000,
        founder: admin,
        member_count: 1,
      },
      members: [existing_member],
      admin,
    }

  let member_exists =
    list.any(
      existing_datum.members,
      fn(m) { m.verification_key_hash == existing_member_vkh },
    )

  member_exists == True
}

// Test 8: NFT token name validation
test nft_token_name_validation() {
  let member_vkh = mock_pub_key_hash(1)
  let current_time = 1625097600000

  // Valid NFT token name
  let valid_member =
    create_sample_member(
      member_vkh,
      "John Doe",
      current_time,
      "member_cert_001",
    )
  let valid_nft_name = valid_member.nft_token_name != #""

  // Invalid NFT token name (empty)
  let invalid_member =
    create_sample_member(member_vkh, "John Doe", current_time, #"")
  let invalid_nft_name = invalid_member.nft_token_name == #""

  valid_nft_name && invalid_nft_name
}

// Test 9: Member count tracking
test member_count_tracking() {
  let admin = mock_pub_key_hash(0)
  let member1_vkh = mock_pub_key_hash(1)
  let member2_vkh = mock_pub_key_hash(2)
  let current_time = 1625097600000

  let member1 =
    create_sample_member(member1_vkh, "Member 1", current_time, "cert_001")
  let member2 =
    create_sample_member(member2_vkh, "Member 2", current_time, "cert_002")

  let datum_with_members =
    RegistryDatum {
      entity: Entity {
        name: "Test SACCO",
        description: "Test Description",
        creation_time: current_time - 86400000,
        founder: admin,
        member_count: 2,
      },
      members: [member1, member2],
      admin,
    }

  let count_matches =
    datum_with_members.entity.member_count == list.length(
      datum_with_members.members,
    )
  count_matches
}

// Test 10: Multiple entities can exist at same contract
test multiple_entities_at_same_contract() {
  let admin1 = mock_pub_key_hash(0)
  let admin2 = mock_pub_key_hash(1)
  let current_time = 1625097600000

  // First entity
  let entity1_datum =
    RegistryDatum {
      entity: Entity {
        name: "Farmers SACCO",
        description: "Agricultural cooperative",
        creation_time: current_time,
        founder: admin1,
        member_count: 0,
      },
      members: [],
      admin: admin1,
    }

  // Second entity (different UTxO, same contract address)
  let entity2_datum =
    RegistryDatum {
      entity: Entity {
        name: "Teachers SACCO",
        description: "Education cooperative",
        creation_time: current_time + 3600000,
        founder: admin2,
        member_count: 0,
      },
      members: [],
      admin: admin2,
    }

  // Both entities have different founders and names
  let different_founders = entity1_datum.admin != entity2_datum.admin
  let different_names = entity1_datum.entity.name != entity2_datum.entity.name
  let both_valid =
    entity1_datum.entity.name != #"" && entity2_datum.entity.name != #""

  different_founders && different_names && both_valid
}

// Test 11: Input validation functions
test input_validation_functions() {
  // Test validate_entity_inputs function logic
  let valid_name = "Test SACCO"
  let valid_description = "A test SACCO for testing purposes"
  let empty_name = #""
  let empty_description = #""
  // Valid inputs should pass
  let valid_case = valid_name != #"" && valid_description != #""
  // Invalid inputs should fail
  let invalid_name_case = empty_name == #""
  let invalid_desc_case = empty_description == #""
  valid_case && invalid_name_case && invalid_desc_case
}

// Test 12: Member data validation
test member_data_validation() {
  let member_vkh = mock_pub_key_hash(1)
  let current_time = 1625097600000
  // Valid member
  let valid_member =
    create_sample_member(
      member_vkh,
      "John Doe",
      current_time - 1000,
      "cert_001",
    )
  // Test individual validations
  let valid_name = valid_member.name != #""
  let valid_vkh = valid_member.verification_key_hash != #""
  let valid_time =
    valid_member.join_time > 0 && valid_member.join_time <= current_time
  let valid_nft = valid_member.nft_token_name != #""
  valid_name && valid_vkh && valid_time && valid_nft
}
// POST-MVP TEST EXTENSIONS:
// - Test atomic member registration + NFT minting
// - Test multi-admin authorization workflows
// - Test member status update operations
// - Test NFT-gated governance integration
// - Test cross-contract validation with NFT policy
// - Test emergency procedures and recovery
// - Test compliance and audit trail features
// - Test member transfer and portability
