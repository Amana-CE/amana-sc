///
/// Treasury Validator
///
/// This validator handles the financial operations of SACCOs,
/// including deposits, withdrawals, and multi-signature approval processes.
///

use aiken/list
use aiken/transaction.{ScriptContext, Spend, Transaction}
use aiken/transaction/value

use common/constants
use common/types.{Amount, Id, PubKeyHash, TransactionStatus, TransactionType}
use common/utils
use treasury/types.{
  Transaction as TxRecord, TreasuryAction, TreasuryDatum, TreasuryInfo
}
use treasury/validators

/// Treasury validator
validator {
  fn spend(datum_opt: Option<TreasuryDatum>, redeemer: TreasuryAction, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } = ctx
    
    when purpose is {
      Spend(own_ref) -> {
        when redeemer is {
          TreasuryAction.InitializeTreasury { entity_id, required_signatures, admins } -> {
            // For treasury initialization, we don't need an existing datum
            
            // Validate treasury initialization request
            validators.validate_initialize_treasury(
              entity_id,
              required_signatures,
              admins,
              transaction,
            )
          }
          
          TreasuryAction.Deposit { entity_id, amount, member_pubkey, metadata_hash } -> {
            // Need existing datum for deposit
            expect Some(datum) = datum_opt
            
            // Get current time for transaction timestamp
            expect Some(current_time) = utils.get_current_time(transaction)
            
            // Generate unique transaction ID
            let tx_id = utils.hash_bytes(transaction.id)
            
            // Validate deposit request
            validators.validate_deposit(
              datum.treasury_info,
              amount,
              member_pubkey,
              metadata_hash,
              transaction,
              current_time,
              tx_id,
            )
          }
          
          TreasuryAction.ProposeWithdrawal { entity_id, amount, recipient, metadata_hash } -> {
            // Need existing datum for withdrawal proposal
            expect Some(datum) = datum_opt
            
            // Get proposer's public key (must be a signer)
            expect Some(proposer) = list.head(transaction.extra_signatories)
            
            // Get current time for transaction timestamp
            expect Some(current_time) = utils.get_current_time(transaction)
            
            // Generate unique transaction ID
            let tx_id = utils.hash_bytes(transaction.id)
            
            // Validate withdrawal proposal
            validators.validate_propose_withdrawal(
              datum.treasury_info,
              datum.transactions,
              amount,
              recipient,
              proposer,
              metadata_hash,
              transaction,
              current_time,
              tx_id,
            )
          }
          
          TreasuryAction.ApproveTransaction { entity_id, tx_id } -> {
            // Need existing datum for transaction approval
            expect Some(datum) = datum_opt
            
            // Get approver's public key (must be a signer)
            expect Some(approver) = list.head(transaction.extra_signatories)
            
            // Get current time for approval timestamp
            expect Some(current_time) = utils.get_current_time(transaction)
            
            // Validate transaction approval
            validators.validate_approve_transaction(
              datum.treasury_info,
              datum.transactions,
              tx_id,
              approver,
              transaction,
              current_time,
            )
          }
          
          TreasuryAction.RejectTransaction { entity_id, tx_id } -> {
            // Need existing datum for transaction rejection
            expect Some(datum) = datum_opt
            
            // Get rejecter's public key (must be a signer)
            expect Some(rejecter) = list.head(transaction.extra_signatories)
            
            // Get current time for rejection timestamp
            expect Some(current_time) = utils.get_current_time(transaction)
            
            // Validate transaction rejection
            validators.validate_reject_transaction(
              datum.treasury_info,
              datum.transactions,
              tx_id,
              rejecter,
              transaction,
              current_time,
            )
          }
          
          TreasuryAction.ExecuteTransaction { entity_id, tx_id } -> {
            // Need existing datum for transaction execution
            expect Some(datum) = datum_opt
            
            // Get current time for execution timestamp
            expect Some(current_time) = utils.get_current_time(transaction)
            
            // Validate transaction execution
            validators.validate_execute_transaction(
              datum.treasury_info,
              datum.transactions,
              tx_id,
              transaction,
              current_time,
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