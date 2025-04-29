///
/// System-wide constants for Amana CE
///

/// Minimum number of admins required for an entity
pub const min_admins = 1

/// Minimum fee for membership (in lovelace - 1 ADA)
pub const min_membership_fee = 1_000_000

/// Minimum contribution amount (in lovelace - 1 ADA)
pub const min_contribution = 1_000_000

/// Default voting threshold percentage (out of 100)
pub const default_voting_threshold = 51

/// Default approval threshold for multi-sig (out of 100)  
pub const default_approval_threshold = 66

/// Default voting period in milliseconds (7 days)
pub const default_voting_period_ms = 604_800_000

/// Maximum allowed members for an entity
pub const max_allowed_members = 1000

/// Minimum transaction amount in lovelace (0.1 ADA)
pub const min_transaction_amount = 100_000

/// Maximum transaction description length
pub const max_description_length = 100

/// Time buffer for transaction validity (in milliseconds - 1 hour)
pub const transaction_time_buffer_ms = 3_600_000

/// Number of confirmations recommended before considering final
pub const recommended_confirmations = 3

/// Maximum proposal title length
pub const max_proposal_title_length = 50

/// Maximum proposal description length
pub const max_proposal_description_length = 500

/// Default entity deposit amount (2 ADA)
pub const default_entity_deposit = 2_000_000

/// Default treasury deposit amount (2 ADA)
pub const default_treasury_deposit = 2_000_000