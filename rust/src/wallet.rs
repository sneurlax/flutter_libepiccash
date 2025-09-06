use std::sync::Arc;
use serde_derive::{Deserialize, Serialize};
use mwc_keychain::ExtKeychain;
use mwc_util::Mutex;
use mwc_util::secp::SecretKey;
use mwc_wallet_api::{Owner, Foreign};
use mwc_wallet_impls::{DefaultLCProvider, HTTPNodeClient};
use mwc_wallet_libwallet::{Error, InitTxArgs, WalletInst, Slate};

/// Wallet type.
pub type Wallet = Arc<
    Mutex<
        Box<
            dyn WalletInst<
                'static,
                DefaultLCProvider<'static, HTTPNodeClient, ExtKeychain>,
                HTTPNodeClient,
                ExtKeychain,
            >,
        >,
    >,
>;

/// Wallet information.
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct WalletInfoFormatted {
    pub last_confirmed_height: u64,
    pub minimum_confirmations: u64,
    pub total: f64,
    pub amount_awaiting_finalization: f64,
    pub amount_awaiting_confirmation: f64,
    pub amount_immature: f64,
    pub amount_currently_spendable: f64,
    pub amount_locked: f64,
}

/// Create a new transaction slate.
///
/// The sender creates an initial slate with outputs and partial signatures.
///
/// Step 1 of the 3-part transaction process.
#[allow(clippy::too_many_arguments)]
pub fn tx_create(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    amount: u64,
    minimum_confirmations: u64,
    selection_strategy_is_use_all: bool,
    note: &str,
) -> Result<String, Error> {
    let owner_api = Owner::new(wallet.clone(), None, None);

    let message = match note {
        "" => None,
        _ => Some(note.to_owned()),
    };

    let args = InitTxArgs {
        src_acct_name: Some("default".into()),
        amount,
        minimum_confirmations,
        max_outputs: 500,
        num_change_outputs: 1,
        selection_strategy_is_use_all,
        message,
        // Set target_slate_version to 4 to enable compact slate format required for slatepack
        target_slate_version: Some(4),
        ..Default::default()
    };

    let slate = owner_api.init_send_tx(keychain_mask.as_ref(), &args, 1)?;
    
    serde_json::to_string(&slate)
        .map_err(|e| Error::GenericError(format!("Failed to serialize slate: {}", e)))
}

/// Process an incoming slate.
///
/// The receiver opens an incoming slate, adds its output,
/// produces its partial signature and gives the caller the updated slate.
///
/// Step 2 of the 3-part transaction process.
pub fn tx_receive(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    slate_json: &str,                // raw JSON from sender
    message: Option<&str>,           // optional note to sign
) -> Result<String, Error>           // updated slate JSON
{
    // Deserialize & upgrade to current.
    let slate = Slate::deserialize_upgrade_plain(slate_json)?;

    // Use the Foreign API to receive the slate
    let foreign_api = Foreign::new(wallet.clone(), keychain_mask, None);
    
    let updated_slate = foreign_api.receive_tx(
        &slate,
        None,                           // address
        &Some("default".to_string()),   // dest_acct_name
        message.map(|s| s.to_owned()),  // message
    )?;

    serde_json::to_string(&updated_slate)
        .map_err(|e| Error::GenericError(format!("Failed to serialize slate: {}", e)))
}

/// Finalize a slate.
///
/// The original sender consumes the returned slate, finalises the transaction,
/// and broadcasts it via the node.
///
/// Step 3 of the 3-part transaction process.
pub fn tx_finalize(
    wallet: &Wallet,
    keychain_mask: Option<SecretKey>,
    slate_json: &str,
) -> Result<(), Error>
{
    // Inflate the slate.
    let mut slate = Slate::deserialize_upgrade_plain(slate_json)?;

    // Finalize the transaction using Owner API
    let owner_api = Owner::new(wallet.clone(), None, None);
    owner_api.finalize_tx(keychain_mask.as_ref(), &mut slate)?;
    
    // Post the transaction to the network if finalization succeeded
    if let Some(tx) = slate.tx.as_ref() {
        owner_api.post_tx(keychain_mask.as_ref(), tx, false)?;
    }

    Ok(())
}