///
/// Entity Registry Validator
///
/// This validator handles the creation and management of SACCO entities
/// and their memberships on the Cardano blockchain.
///

use aiken/hash.{blake2b_256}
use aiken/list
use aiken/transaction.{ScriptContext, Spend, Transaction}
use aiken/transaction/value

use common/constants
use common/types.{EntityStatus, EntityActive, Id, MemberRole, MemberStatus, PubKeyHash}
use common/utils
use entity/types.{Entity, EntityAction, EntityDatum, EntityParameters, Member}
use entity/validators

/// Entity Registry validator
validator {
  fn spend(datum_opt: Option<EntityDatum>, redeemer: EntityAction, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } = ctx
    
    when purpose is {
      Spend(own_ref) -> {
        when redeemer is {
          EntityAction.CreateEntity { name, description, admin_pubkeys, parameters, metadata_hash } -> {
            // For entity creation, we don't need an existing datum
            // Generate a unique entity ID
            let entity_id = utils.hash_bytes(name)
            
            // Get current time
            expect Some(current_time) = utils.get_current_time(transaction)
            
            // Validate entity creation request
            validators.validate_create_entity(
              entity_id,
              name,
              description,
              admin_pubkeys,
              parameters,
              metadata_hash,
              transaction,
              current_time,
            )
          }
          
          EntityAction.UpdateEntityParameters { entity_id, new_parameters } -> {
            // Need existing datum for entity update
            expect Some(datum) = datum_opt
            
            // Find the entity being updated
            expect Some(entity) =
              list.find(
                [datum.entity],
                fn(e) { e.entity_id == entity_id },
              )
            
            // Validate entity parameters update request
            validators.validate_update_entity_parameters(
              entity,
              new_parameters,
              transaction,
            )
          }
          
          EntityAction.RegisterMember { entity_id, member_pubkey, metadata_hash } -> {
            // Need existing datum for member registration
            expect Some(datum) = datum_opt
            
            // Find the entity
            expect Some(entity) =
              list.find(
                [datum.entity],
                fn(e) { e.entity_id == entity_id },
              )
            
            // Get current time for member creation timestamp
            expect Some(current_time) = utils.get_current_time(transaction)
            
            // Generate a unique member ID
            let member_id = utils.hash_bytes(member_pubkey)
            
            // Validate member registration request
            validators.validate_register_member(
              entity,
              datum.members,
              member_id,
              member_pubkey,
              metadata_hash,
              transaction,
              current_time,
            )
          }
          
          EntityAction.UpdateMemberStatus { entity_id, member_id, new_status } -> {
            // Need existing datum for member status update
            expect Some(datum) = datum_opt
            
            // Find the entity
            expect Some(entity) =
              list.find(
                [datum.entity],
                fn(e) { e.entity_id == entity_id },
              )
            
            // Validate member status update request
            validators.validate_update_member_status(
              entity,
              datum.members,
              member_id,
              new_status,
              transaction,
            )
          }
          
          EntityAction.UpdateEntityStatus { entity_id, new_status } -> {
            // Need existing datum for entity status update
            expect Some(datum) = datum_opt
            
            // Find the entity
            expect Some(entity) =
              list.find(
                [datum.entity],
                fn(e) { e.entity_id == entity_id },
              )
            
            // Validate entity status update request
            validators.validate_update_entity_status(
              entity,
              datum.members,
              new_status,
              transaction,
            )
          }
        }
      }
      
      _ -> {
        // This validator only handles spend purposes
        False
      }
    }
  }
}